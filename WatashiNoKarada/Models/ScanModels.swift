import Foundation
import simd

struct CodablePoint: Codable, Hashable {
    var x: Float
    var y: Float
    var z: Float
    var r: Float
    var g: Float
    var b: Float
    var a: Float
    /// Metric isotropic Gaussian sigma used by the on-device splat preview.
    /// Optional so archives created by older app versions remain decodable.
    var sigmaM: Float? = nil

    init(x: Float, y: Float, z: Float, r: Float, g: Float, b: Float, a: Float, sigmaM: Float? = nil) {
        self.x = x
        self.y = y
        self.z = z
        self.r = r
        self.g = g
        self.b = b
        self.a = a
        self.sigmaM = sigmaM
    }

    var position: SIMD3<Float> { SIMD3(x, y, z) }
    var color: SIMD4<Float> { SIMD4(r, g, b, a) }
    var effectiveSigmaM: Float { sigmaM ?? 0.006 }
}

struct PoseCapture: Codable, Identifiable {
    enum Pose: Int, Codable, CaseIterable {
        case front = 0
        case right = 1
        case back = 2
        case left = 3

        var id: Int { rawValue }
        var title: String {
            switch self {
            case .front: return "正面"
            case .right: return "右側"
            case .back: return "背面"
            case .left: return "左側"
            }
        }
        var yawRadians: Float { Float(rawValue) * (Float.pi / 2) }
    }

    let id: UUID
    let pose: Pose
    let capturedAt: Date
    let widthAtWaistM: Float
    let widthAtAbdomenM: Float
    let widthAtHipM: Float
    let distanceM: Float
    let confidence: Float
    let points: [CodablePoint]
}

struct ScanArchive: Codable {
    let version: Int
    let id: UUID
    let createdAt: Date
    let waistCM: Double
    let abdomenCM: Double
    let hipCM: Double
    let qualityScore: Double
    let captures: [PoseCapture]
    let mergedPoints: [CodablePoint]
}

struct ScanMeasurement {
    let waistCM: Double
    let abdomenCM: Double
    let hipCM: Double
    let qualityScore: Double
}
