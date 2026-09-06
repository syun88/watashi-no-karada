import ARKit
import Foundation
import CoreVideo
import simd

struct BodyDepthProcessor {
    struct Result {
        let pose: PoseCapture
    }

    /// Extracts a center-seeded coherent body component from ARKit Scene Depth.
    /// The app is portrait-only, while ARKit depth/camera buffers are sensor-landscape oriented,
    /// so silhouette processing first maps the buffers into portrait coordinates.
    func process(frame: ARFrame, pose: PoseCapture.Pose) -> Result? {
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth else { return nil }
        let depth = depthData.depthMap
        let confidence = depthData.confidenceMap

        CVPixelBufferLockBaseAddress(depth, .readOnly)
        if let confidence { CVPixelBufferLockBaseAddress(confidence, .readOnly) }
        defer {
            CVPixelBufferUnlockBaseAddress(depth, .readOnly)
            if let confidence { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
        }

        let rawWidth = CVPixelBufferGetWidth(depth)
        let rawHeight = CVPixelBufferGetHeight(depth)
        guard let base = CVPixelBufferGetBaseAddress(depth) else { return nil }
        let depthStride = CVPixelBufferGetBytesPerRow(depth) / MemoryLayout<Float32>.size
        let depthPtr = base.assumingMemoryBound(to: Float32.self)

        let confidencePtr: UnsafeMutablePointer<UInt8>? = confidence.flatMap { pb in
            guard let cbase = CVPixelBufferGetBaseAddress(pb) else { return nil }
            return cbase.assumingMemoryBound(to: UInt8.self)
        }
        let confidenceStride = confidence.map { CVPixelBufferGetBytesPerRow($0) } ?? 0

        // Rear-camera buffers are landscape-oriented. For the portrait-only scan flow, map raw -> portrait:
        // portraitX = rawHeight - 1 - rawY, portraitY = rawX.
        // The exact orientation still needs to be verified on the target device during first-device testing.
        let width = rawHeight
        let height = rawWidth

        @inline(__always)
        func rawCoordinates(portraitX x: Int, portraitY y: Int) -> (x: Int, y: Int) {
            (x: y, y: rawHeight - 1 - x)
        }

        @inline(__always)
        func depthValue(x: Int, y: Int) -> Float {
            let raw = rawCoordinates(portraitX: x, portraitY: y)
            return depthPtr[raw.y * depthStride + raw.x]
        }

        @inline(__always)
        func confidenceValue(x: Int, y: Int) -> UInt8 {
            guard let confidencePtr else { return 2 }
            let raw = rawCoordinates(portraitX: x, portraitY: y)
            return confidencePtr[raw.y * confidenceStride + raw.x]
        }

        // Scale camera intrinsics to the depth map, then rotate intrinsics to portrait.
        let imageWidth = Float(CVPixelBufferGetWidth(frame.capturedImage))
        let imageHeight = Float(CVPixelBufferGetHeight(frame.capturedImage))
        let rawFx = frame.camera.intrinsics.columns.0.x * Float(rawWidth) / imageWidth
        let rawFy = frame.camera.intrinsics.columns.1.y * Float(rawHeight) / imageHeight
        let rawCx = frame.camera.intrinsics.columns.2.x * Float(rawWidth) / imageWidth
        let rawCy = frame.camera.intrinsics.columns.2.y * Float(rawHeight) / imageHeight

        let fx = rawFy
        let fy = rawFx
        let cx = Float(rawHeight - 1) - rawCy
        let cy = rawCx

        // Search only where the scan UI asks the user to stand.
        let x0 = Int(Float(width) * 0.12)
        let x1 = Int(Float(width) * 0.88)
        let y0 = Int(Float(height) * 0.04)
        let y1 = Int(Float(height) * 0.96)

        let minD: Float = 0.7
        let maxD: Float = 3.5

        // Prefer a robust median from the central torso region. This is safer than simply choosing
        // the nearest depth mode when furniture or another foreground object appears elsewhere.
        let torsoX0 = Int(Float(width) * 0.37)
        let torsoX1 = Int(Float(width) * 0.63)
        let torsoY0 = Int(Float(height) * 0.28)
        let torsoY1 = Int(Float(height) * 0.72)
        var centerDepths: [Float] = []
        centerDepths.reserveCapacity(1800)

        for y in stride(from: torsoY0, to: torsoY1, by: 2) {
            for x in stride(from: torsoX0, to: torsoX1, by: 2) {
                let d = depthValue(x: x, y: y)
                guard d.isFinite, d >= minD, d <= maxD else { continue }
                guard confidenceValue(x: x, y: y) >= 1 else { continue }
                centerDepths.append(d)
            }
        }

        let bodyDistance: Float = {
            if centerDepths.count >= 24, let m = median(centerDepths) {
                return m
            }

            // Fallback: 5 cm histogram over the scan ROI, choosing the nearest significant mode.
            let binSize: Float = 0.05
            let binCount = Int((maxD - minD) / binSize) + 1
            var histogram = Array(repeating: 0, count: binCount)
            for y in stride(from: y0, to: y1, by: 2) {
                for x in stride(from: x0, to: x1, by: 2) {
                    let d = depthValue(x: x, y: y)
                    guard d.isFinite, d >= minD, d <= maxD else { continue }
                    guard confidenceValue(x: x, y: y) >= 1 else { continue }
                    let bin = min(max(Int((d - minD) / binSize), 0), binCount - 1)
                    histogram[bin] += 1
                }
            }
            let significant = max(16, ((x1 - x0) * (y1 - y0)) / 1400)
            if let bin = histogram.indices.first(where: { histogram[$0] >= significant }) {
                return minD + (Float(bin) + 0.5) * binSize
            }
            guard let bin = histogram.indices.max(by: { histogram[$0] < histogram[$1] }), histogram[bin] > 0 else {
                return .nan
            }
            return minD + (Float(bin) + 0.5) * binSize
        }()
        guard bodyDistance.isFinite else { return nil }

        // Depth tolerance around the torso median. Background should normally be farther away.
        let near = bodyDistance - 0.28
        let far = bodyDistance + 0.36
        let pixelCount = width * height
        var candidateMask = [UInt8](repeating: 0, count: pixelCount)
        var accepted = 0

        @inline(__always)
        func index(_ x: Int, _ y: Int) -> Int { y * width + x }

        for y in y0..<y1 {
            for x in x0..<x1 {
                let d = depthValue(x: x, y: y)
                guard d.isFinite, d >= near, d <= far else { continue }
                guard confidenceValue(x: x, y: y) >= 1 else { continue }
                candidateMask[index(x, y)] = 1
                accepted += 1
            }
        }
        guard accepted > 260 else { return nil }

        // Select the connected component nearest the expected torso center. This rejects disconnected
        // walls/furniture that happen to fall in the same depth band.
        let expectedX = width / 2
        let expectedY = Int(Float(height) * 0.50)
        var seed: (x: Int, y: Int)?
        var bestSeedScore = Float.greatestFiniteMagnitude
        for y in torsoY0..<torsoY1 {
            for x in torsoX0..<torsoX1 where candidateMask[index(x, y)] == 1 {
                let dx = Float(x - expectedX) / Float(max(width, 1))
                let dy = Float(y - expectedY) / Float(max(height, 1))
                let dz = abs(depthValue(x: x, y: y) - bodyDistance)
                let score = dx * dx + dy * dy + dz * 0.04
                if score < bestSeedScore {
                    bestSeedScore = score
                    seed = (x, y)
                }
            }
        }
        guard let seed else { return nil }

        var bodyMask = [UInt8](repeating: 0, count: pixelCount)
        var queue: [Int] = []
        queue.reserveCapacity(accepted)
        let seedIndex = index(seed.x, seed.y)
        bodyMask[seedIndex] = 1
        queue.append(seedIndex)
        var head = 0

        while head < queue.count {
            let current = queue[head]
            head += 1
            let x = current % width
            let y = current / width

            for dy in -1...1 {
                for dx in -1...1 where !(dx == 0 && dy == 0) {
                    let nx = x + dx
                    let ny = y + dy
                    guard nx >= x0, nx < x1, ny >= y0, ny < y1 else { continue }
                    let ni = index(nx, ny)
                    guard candidateMask[ni] == 1, bodyMask[ni] == 0 else { continue }
                    bodyMask[ni] = 1
                    queue.append(ni)
                }
            }
        }

        let componentCount = queue.count
        guard componentCount > 260 else { return nil }

        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var highConfidenceCount = 0
        for i in queue {
            let x = i % width
            let y = i / width
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
            if confidenceValue(x: x, y: y) >= 2 { highConfidenceCount += 1 }
        }

        guard maxX > minX, maxY > minY else { return nil }
        let bodyHeightPixels = maxY - minY
        guard bodyHeightPixels > Int(Float(height) * 0.45) else { return nil }

        // Ratio-based bands are intentionally provisional. They are for repeatable progress tracking,
        // not anatomical/medical measurement. Vision landmarks are the planned replacement.
        let levels: [Float] = [0.48, 0.53, 0.58] // waist-band, abdomen-band, hip-band from silhouette top
        let bandHalf = max(2, Int(Float(bodyHeightPixels) * 0.018))
        let torsoCenterX = seed.x

        func horizontalWidth(at fraction: Float) -> Float {
            let centerY = minY + Int(Float(bodyHeightPixels) * fraction)
            var perRowWidths: [Float] = []

            for y in max(minY, centerY - bandHalf)...min(maxY, centerY + bandHalf) {
                // Find contiguous body runs on this row and select the run closest to the torso center.
                var runs: [(start: Int, end: Int)] = []
                var runStart: Int?
                for x in minX...maxX {
                    if bodyMask[index(x, y)] == 1 {
                        if runStart == nil { runStart = x }
                    } else if let start = runStart {
                        runs.append((start, x - 1))
                        runStart = nil
                    }
                }
                if let start = runStart { runs.append((start, maxX)) }

                guard let run = runs
                    .filter({ $0.end - $0.start + 1 >= 6 })
                    .min(by: {
                        let m0 = ($0.start + $0.end) / 2
                        let m1 = ($1.start + $1.end) / 2
                        return abs(m0 - torsoCenterX) < abs(m1 - torsoCenterX)
                    }) else { continue }

                var depthSamples: [Float] = []
                depthSamples.reserveCapacity(run.end - run.start + 1)
                for x in run.start...run.end {
                    let d = depthValue(x: x, y: y)
                    if d.isFinite { depthSamples.append(d) }
                }
                let rowDepth = median(depthSamples) ?? bodyDistance
                let metric = Float(run.end - run.start) * rowDepth / max(fx, 1)
                if metric > 0.05 && metric < 1.2 { perRowWidths.append(metric) }
            }

            return median(perRowWidths) ?? 0
        }

        let waistWidth = horizontalWidth(at: levels[0])
        let abdomenWidth = horizontalWidth(at: levels[1])
        let hipWidth = horizontalWidth(at: levels[2])
        guard waistWidth > 0.08, abdomenWidth > 0.08, hipWidth > 0.08 else { return nil }

        // Unproject a decimated metric point cloud from the selected body component.
        var rawPoints: [(position: SIMD3<Float>, sigmaM: Float)] = []
        rawPoints.reserveCapacity(12000)
        let sampleStep = 2
        for y in stride(from: minY, through: maxY, by: sampleStep) {
            for x in stride(from: minX, through: maxX, by: sampleStep) {
                guard bodyMask[index(x, y)] == 1 else { continue }
                let z = depthValue(x: x, y: y)
                guard z.isFinite else { continue }
                let px = (Float(x) - cx) * z / max(fx, 1)
                let py = -(Float(y) - cy) * z / max(fy, 1)
                // Approximate the metric footprint of a sampled depth pixel. The renderer projects this
                // isotropic sigma back to screen space instead of using a fixed point size.
                let pixelFootprintM = z / max(fx, 1)
                let sigmaM = max(0.0025, pixelFootprintM * Float(sampleStep) * 0.85)
                rawPoints.append((SIMD3(px, py, z), sigmaM))
            }
        }
        guard rawPoints.count > 150 else { return nil }

        let centroid = rawPoints.reduce(SIMD3<Float>.zero) { $0 + $1.position } / Float(rawPoints.count)
        let angle = -pose.yawRadians
        let c = cos(angle)
        let s = sin(angle)
        let tint: SIMD4<Float> = {
            switch pose {
            case .front: return SIMD4(0.08, 0.62, 1.0, 0.82)
            case .right: return SIMD4(0.05, 0.88, 0.72, 0.82)
            case .back: return SIMD4(0.32, 0.70, 1.0, 0.82)
            case .left: return SIMD4(0.38, 0.95, 0.58, 0.82)
            }
        }()

        let points = rawPoints.map { sample -> CodablePoint in
            let q = sample.position - centroid
            let rotated = SIMD3<Float>(
                c * q.x + s * q.z,
                q.y,
                -s * q.x + c * q.z
            )
            return CodablePoint(
                x: rotated.x,
                y: rotated.y,
                z: rotated.z,
                r: tint.x,
                g: tint.y,
                b: tint.z,
                a: tint.w,
                sigmaM: sample.sigmaM
            )
        }

        let highConfidenceRatio = Float(highConfidenceCount) / Float(max(componentCount, 1))
        let componentPurity = Float(componentCount) / Float(max(accepted, 1))
        let bboxCoverage = min(1, Float(bodyHeightPixels) / (Float(height) * 0.72))
        let quality = min(1, max(0.20, 0.45 * highConfidenceRatio + 0.35 * componentPurity + 0.20 * bboxCoverage))

        return Result(pose: PoseCapture(
            id: UUID(),
            pose: pose,
            capturedAt: .now,
            widthAtWaistM: waistWidth,
            widthAtAbdomenM: abdomenWidth,
            widthAtHipM: hipWidth,
            distanceM: bodyDistance,
            confidence: quality,
            points: points
        ))
    }

    private func median(_ values: [Float]) -> Float? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
