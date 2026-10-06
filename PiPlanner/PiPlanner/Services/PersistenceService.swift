import Foundation

/// Local demo persistence (Spec §4.1).
protocol PersistenceServicing: Sendable {
    func loadState() async throws -> PersistedAppState
    func saveState(_ state: PersistedAppState) async throws
    /// Clears all persisted demo data (Settings → Reset demo).
    func resetDemo() async throws
}

/// Spec §4.2 — PersistenceService (JSON file under a storage directory).
actor PersistenceService: PersistenceServicing {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(storageDirectory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = storageDirectory.appendingPathComponent("app-state.json", isDirectory: false)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Default app-group style location for the iOS target.
    static func makeDefault() throws -> PersistenceService {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("PiPlanner", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return PersistenceService(storageDirectory: directory)
    }

    func loadState() async throws -> PersistedAppState {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(PersistedAppState.self, from: data)
        } catch {
            throw AppError.persistenceError("Failed to load app state: \(error.localizedDescription)")
        }
    }

    func saveState(_ state: PersistedAppState) async throws {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistenceError("Failed to save app state: \(error.localizedDescription)")
        }
    }

    func resetDemo() async throws {
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            throw AppError.persistenceError("Failed to reset demo data: \(error.localizedDescription)")
        }
    }
}
