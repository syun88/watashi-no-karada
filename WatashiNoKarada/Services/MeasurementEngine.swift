import Foundation

struct MeasurementEngine {
    /// Estimates circumference from orthogonal LiDAR silhouettes.
    ///
    /// Front/back views estimate the left-right diameter, side views estimate the anterior-posterior
    /// diameter, and Ramanujan's second approximation converts the fitted ellipse to circumference.
    /// This is a repeatability-first progress metric, not a medical anthropometric measurement.
    func measurement(from captures: [PoseCapture]) -> ScanMeasurement? {
        guard captures.count >= 4 else { return nil }

        func weightedAverage(_ poses: [PoseCapture.Pose], _ keyPath: KeyPath<PoseCapture, Float>) -> Double? {
            let samples = captures.compactMap { capture -> (value: Double, weight: Double)? in
                guard poses.contains(capture.pose) else { return nil }
                let value = Double(capture[keyPath: keyPath])
                guard value > 0.05 else { return nil }
                // Keep low-quality frames from dominating while never giving a valid capture zero weight.
                let weight = max(0.15, Double(capture.confidence))
                return (value, weight)
            }
            guard !samples.isEmpty else { return nil }
            let totalWeight = samples.reduce(0.0) { $0 + $1.weight }
            guard totalWeight > 0 else { return nil }
            return samples.reduce(0.0) { $0 + $1.value * $1.weight } / totalWeight
        }

        guard
            let waistWidth = weightedAverage([.front, .back], \.widthAtWaistM),
            let waistDepth = weightedAverage([.right, .left], \.widthAtWaistM),
            let abdomenWidth = weightedAverage([.front, .back], \.widthAtAbdomenM),
            let abdomenDepth = weightedAverage([.right, .left], \.widthAtAbdomenM),
            let hipWidth = weightedAverage([.front, .back], \.widthAtHipM),
            let hipDepth = weightedAverage([.right, .left], \.widthAtHipM)
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
