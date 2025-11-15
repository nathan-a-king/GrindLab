import Foundation
import OSLog

struct PersistenceMetadata: Codable {
    var storageVersion: Int
    var legacyAnalysesMigrated: Bool
    var lastMigrationDate: Date?
}

final class PersistenceController {
    static let shared = PersistenceController()

    let fileManager: FileManager
    let baseDirectory: URL

    private let metadataURL: URL
    private let logger = Logger(subsystem: "com.nateking.GrindLab", category: "PersistenceController")
    private let metadataQueue = DispatchQueue(label: "com.nateking.GrindLab.persistence.metadata", qos: .utility)
    private var metadata: PersistenceMetadata

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        baseDirectory = appSupport.appendingPathComponent("GrindLab", isDirectory: true)

        do {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create base persistence directory: \(error.localizedDescription, privacy: .public)")
        }

        metadataURL = baseDirectory.appendingPathComponent("metadata.json")

        if let data = try? Data(contentsOf: metadataURL),
           let decoded = try? JSONDecoder().decode(PersistenceMetadata.self, from: data) {
            metadata = decoded
        } else {
            metadata = PersistenceMetadata(storageVersion: 1, legacyAnalysesMigrated: false, lastMigrationDate: nil)
            persistMetadata(metadata)
        }
    }

    func directory(named name: String) -> URL {
        let directory = baseDirectory.appendingPathComponent(name, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create directory \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return directory
    }

    func updateMetadata(_ update: (inout PersistenceMetadata) -> Void) {
        metadataQueue.sync {
            var copy = metadata
            update(&copy)
            metadata = copy
            persistMetadata(copy)
        }
    }

    func currentMetadata() -> PersistenceMetadata {
        metadataQueue.sync { metadata }
    }

    private func persistMetadata(_ metadata: PersistenceMetadata) {
        do {
            let data = try JSONEncoder().encode(metadata)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            logger.error("Failed to persist metadata: \(error.localizedDescription, privacy: .public)")
        }
    }
}
