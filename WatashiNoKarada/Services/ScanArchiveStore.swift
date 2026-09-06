import Foundation

final class ScanArchiveStore {
    static let shared = ScanArchiveStore()
    private init() {}

    private var scansDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("BodyScans", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func save(_ archive: ScanArchive) throws -> String {
        let name = "\(archive.id.uuidString).json"
        let url = scansDirectory.appendingPathComponent(name)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return name
    }

    func load(fileName: String) throws -> ScanArchive {
        let url = scansDirectory.appendingPathComponent(fileName)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ScanArchive.self, from: data)
    }

    func delete(fileName: String) {
        try? FileManager.default.removeItem(at: scansDirectory.appendingPathComponent(fileName))
    }
}
