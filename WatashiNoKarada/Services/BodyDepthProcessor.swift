import ARKit
import Foundation
import CoreVideo
import simd

struct BodyDepthProcessor {
    struct Result {
        let pose: PoseCapture
    }

    /// Extracts the nearest coherent depth cluster around the screen center.
    /// ARKit's captured/depth pixel buffers are sensor-landscape oriented; this app is portrait-only,
    /// so all silhouette operations first map the buffers into portrait coordinates.
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

        // Rear-camera ARFrame buffers are landscape-oriented. The app UI is portrait.
        // A clockwise 90° display rotation maps raw -> portrait:
        //   portraitX = rawHeight - 1 - rawY
        //   portraitY = rawX
        // Therefore inverse mapping is rawX = portraitY, rawY = rawHeight - 1 - portraitX.
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

        // Restrict search to the central portrait area where the UI asks the user to stand.
        let x0 = Int(Float(width) * 0.12)
        let x1 = Int(Float(width) * 0.88)
        let y0 = Int(Float(height) * 0.04)
        let y1 = Int(Float(height) * 0.96)

        // 5 cm bins between 0.7 m and 3.5 m. Choose the nearest significant depth mode.
        let minD: Float = 0.7
        let maxD: Float = 3.5
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
        let candidateBins = histogram.indices.filter { histogram[$0] >= significant }
        let fallbackBin = histogram.indices.max(by: { histogram[$0] < histogram[$1] })!
        let bodyBin = candidateBins.first ?? fallbackBin

        let bodyDistance = minD + (Float(bodyBin) + 0.5) * binSize
        // Human thickness / clothing tolerance around the mode. Background should be farther away.
        let near = bodyDistance - 0.24
        let far = bodyDistance + 0.34

        // Depth silhouette bounding box in portrait coordinates.
        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var accepted = 0

        for y in y0..<y1 {
            for x in x0..<x1 {
                let d = depthValue(x: x, y: y)
                guard d.isFinite, d >= near, d <= far else { continue }
                guard confidenceValue(x: x, y: y) >= 1 else { continue }
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
                accepted += 1
            }
        }

        guard accepted > 260, maxX > minX, maxY > minY else { return nil }
        let bodyHeightPixels = maxY - minY
        guard bodyHeightPixels > Int(Float(height) * 0.45) else { return nil }

        // Standardized anatomical bands for MVP. Future version can replace these with Vision body landmarks.
        let levels: [Float] = [0.54, 0.62, 0.70] // waist, abdomen, hip from top of depth silhouette
        let bandHalf = max(2, Int(Float(bodyHeightPixels) * 0.018))

        func horizontalWidth(at fraction: Float) -> Float {
            let centerY = minY + Int(Float(bodyHeightPixels) * fraction)
            var perRowWidths: [Float] = []

            for y in max(minY, centerY - bandHalf)...min(maxY, centerY + bandHalf) {
                var rowXs: [Int] = []
                rowXs.reserveCapacity(maxX - minX + 1)
                for x in minX...maxX {
                    let d = depthValue(x: x, y: y)
                    guard d.isFinite, d >= near, d <= far else { continue }
                    guard confidenceValue(x: x, y: y) >= 1 else { continue }
                    rowXs.append(x)
                }
                guard rowXs.count > 5, let left = rowXs.first, let right = rowXs.last else { continue }

                // Convert display-horizontal pixel span to metric width using portrait-rotated intrinsics.
                let rowDepthSamples = rowXs.map { depthValue(x: $0, y: y) }.filter { $0.isFinite }
                let rowDepth = median(rowDepthSamples) ?? bodyDistance
                let metric = Float(right - left) * rowDepth / max(fx, 1)
                if metric > 0.05 && metric < 1.2 { perRowWidths.append(metric) }
            }

            return median(perRowWidths) ?? 0
        }

        let waistWidth = horizontalWidth(at: levels[0])
        let abdomenWidth = horizontalWidth(at: levels[1])
        let hipWidth = horizontalWidth(at: levels[2])
        guard waistWidth > 0.08, abdomenWidth > 0.08, hipWidth > 0.08 else { return nil }

        // Unproject a decimated portrait-oriented body point cloud.
        var rawPoints: [SIMD3<Float>] = []
        rawPoints.reserveCapacity(12000)
        let sampleStep = 2
        for y in stride(from: minY, through: maxY, by: sampleStep) {
            for x in stride(from: minX, through: maxX, by: sampleStep) {
                let z = depthValue(x: x, y: y)
                guard z.isFinite, z >= near, z <= far else { continue }
                guard confidenceValue(x: x, y: y) >= 1 else { continue }
                let px = (Float(x) - cx) * z / max(fx, 1)
                let py = -(Float(y) - cy) * z / max(fy, 1)
                rawPoints.append(SIMD3(px, py, z))
            }
        }
        guard rawPoints.count > 150 else { return nil }

        let centroid = rawPoints.reduce(SIMD3<Float>.zero, +) / Float(rawPoints.count)
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

        let points = rawPoints.map { point -> CodablePoint in
            let q = point - centroid
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
                a: tint.w
            )
        }

        let confidenceRatio = Float(rawPoints.count * sampleStep * sampleStep) / Float(max(accepted, 1))
        let bboxCoverage = min(1, Float(bodyHeightPixels) / (Float(height) * 0.72))
        let quality = min(1, max(0.25, 0.55 * min(confidenceRatio, 1) + 0.45 * bboxCoverage))

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
