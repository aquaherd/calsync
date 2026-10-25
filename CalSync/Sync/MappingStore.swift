import Foundation

/// Persists source→destination event mappings per sync job as JSON files.
nonisolated struct MappingStore: Sendable {
    let directory: URL

    func load(for jobID: UUID) throws -> [String: MappingEntry] {
        let url = fileURL(for: jobID)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        return try JSONDecoder().decode([String: MappingEntry].self, from: Data(contentsOf: url))
    }

    func save(_ mapping: [String: MappingEntry], for jobID: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(mapping).write(to: fileURL(for: jobID), options: .atomic)
    }

    func remove(for jobID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: jobID))
    }

    private func fileURL(for jobID: UUID) -> URL {
        directory.appending(path: "\(jobID.uuidString).json")
    }
}
