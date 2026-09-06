import Foundation
import SwiftData

@Model
final class BodyRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var waistCM: Double
    var abdomenCM: Double?
    var hipCM: Double?
    var weightKG: Double?
    var scanFileName: String?
    var qualityScore: Double?
    var note: String
    var source: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        waistCM: Double,
        abdomenCM: Double? = nil,
        hipCM: Double? = nil,
        weightKG: Double? = nil,
        scanFileName: String? = nil,
        qualityScore: Double? = nil,
        note: String = "",
        source: String = "scan"
    ) {
        self.id = id
        self.date = date
        self.waistCM = waistCM
        self.abdomenCM = abdomenCM
        self.hipCM = hipCM
        self.weightKG = weightKG
        self.scanFileName = scanFileName
        self.qualityScore = qualityScore
        self.note = note
        self.source = source
    }
}
