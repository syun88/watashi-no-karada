import Foundation

struct MeasurementEngine {
    /// Uses Ramanujan's second approximation for an ellipse perimeter.
    /// The front/back width estimates the left-right diameter, and the side views estimate front-back depth.
    func measurement(from captures: [PoseCapture]) -> ScanMeasurement? {
        guard captures.count >= 4 else { return nil }

        func average(_ poses: [PoseCapture.Pose], _ keyPath: KeyPath<PoseCapture, Float>) -> Double? {
            let values = captures.filter { poses.contains($0.pose) }.map { Double($0[keyPath: keyPath]) }.filter { $0 > 0.05 }
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }

        guard
            let waistWidth = average([.front, .back], \.widthAtWaistM),
            let waistDepth = average([.right, .left], \.widthAtWaistM),
            let abdomenWidth = average([.front, .back], \.widthAtAbdomenM),
            let abdomenDepth = average([.right, .left], \.widthAtAbdomenM),
            let hipWidth = average([.front, .back], \.widthAtHipM),
            let hipDepth = average([.right, .left], \.widthAtHipM)
        else { return nil }

        let waist = ellipseCircumference(width: waistWidth, depth: waistDepth) * 100
        let abdomen = ellipseCircumference(width: abdomenWidth, depth: abdomenDepth) * 100
        let hip = ellipseCircumference(width: hipWidth, depth: hipDepth) * 100
        let q = captures.map { Double($0.confidence) }.reduce(0, +) / Double(captures.count)

        return ScanMeasurement(
            waistCM: waist,
            abdomenCM: abdomen,
            hipCM: hip,
            qualityScore: min(max(q, 0), 1)
        )
    }

    private func ellipseCircumference(width: Double, depth: Double) -> Double {
        let a = max(width, 0.01) / 2
        let b = max(depth, 0.01) / 2
        let h = pow(a - b, 2) / pow(a + b, 2)
        return .pi * (a + b) * (1 + (3 * h) / (10 + sqrt(4 - 3 * h)))
    }
}
