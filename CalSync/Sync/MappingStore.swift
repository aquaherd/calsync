import Foundation

/// Persists source→destination event mappings per sync job as JSON files.
nonisolated struct MappingStore: Sendable {
    let directory: URL

    func load(for jobID: UUID) throws -> [String: MappingEntry] {
        let url = fileURL(for: jobID)
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        var mapping = try JSONDecoder().decode([String: MappingEntry].self, from: Data(contentsOf: url))
        if mapping.values.contains(where: \.needsMigration) {
            // Older versions stored the full event text. Rewriting drops that copy immediately.
            try save(mapping, for: jobID)
            mapping = mapping.mapValues { entry in
                var entry = entry
                entry.legacyPayload = nil
                return entry
            }
        }
        return mapping
    }

    func save(_ mapping: [String: MappingEntry], for jobID: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(mapping)
        try data.write(to: fileURL(for: jobID), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func remove(for jobID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: jobID))
    }

    /// Every destination identifier claimed by another job. Used to keep adoption from stealing
    /// a copy that already belongs to a different sync.
    func claimedDestinationIDs(excluding jobID: UUID) -> Set<String> {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        var ids = Set<String>()
        for file in files where file.pathExtension == "json" {
            guard file.deletingPathExtension().lastPathComponent != jobID.uuidString else { continue }
            guard let data = try? Data(contentsOf: file),
                  let mapping = try? JSONDecoder().decode([String: MappingEntry].self, from: data) else {
                continue
            }
            ids.formUnion(mapping.values.map(\.destinationID))
        }
        return ids
    }

    private func fileURL(for jobID: UUID) -> URL {
        directory.appending(path: "\(jobID.uuidString).json")
    }
}
