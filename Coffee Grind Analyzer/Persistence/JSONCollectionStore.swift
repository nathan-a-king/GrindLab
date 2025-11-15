import Foundation
import OSLog

struct JSONCollectionStore<Item: Codable & Identifiable> where Item.ID == UUID {
    private let directory: URL
    private let indexURL: URL
    private let fileManager: FileManager
    private var encoder: JSONEncoder
    private var decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.nateking.GrindLab", category: "JSONCollectionStore")

    init(name: String, baseDirectory: URL, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        directory = baseDirectory.appendingPathComponent(name, isDirectory: true)
        indexURL = directory.appendingPathComponent("index.json")
        encoder = JSONEncoder()
        decoder = JSONDecoder()

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create store directory: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    var hasExistingData: Bool {
        fileManager.fileExists(atPath: indexURL.path)
    }

    mutating func configure(dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                            dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate) {
        encoder.dateEncodingStrategy = dateEncodingStrategy
        decoder.dateDecodingStrategy = dateDecodingStrategy
    }

    func loadAll() throws -> [Item] {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return []
        }

        let indexData = try Data(contentsOf: indexURL)
        let index = try decoder.decode(IndexFile.self, from: indexData)

        var loadedItems: [Item] = []
        var corruptedURLs: [URL] = []

        for id in index.ids {
            let fileURL = directory.appendingPathComponent("\(id.uuidString).json")
            guard let data = try? Data(contentsOf: fileURL) else {
                corruptedURLs.append(fileURL)
                continue
            }

            do {
                let item = try decoder.decode(Item.self, from: data)
                loadedItems.append(item)
            } catch {
                logger.error("Failed to decode item at \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                corruptedURLs.append(fileURL)
            }
        }

        if !corruptedURLs.isEmpty {
            let corruptDirectory = directory.appendingPathComponent("Corrupt", isDirectory: true)
            try? fileManager.createDirectory(at: corruptDirectory, withIntermediateDirectories: true)

            for url in corruptedURLs {
                let destination = corruptDirectory.appendingPathComponent(url.lastPathComponent + ".corrupt")
                do {
                    if fileManager.fileExists(atPath: url.path) {
                        try fileManager.moveItem(at: url, to: destination)
                    }
                } catch {
                    logger.error("Failed to move corrupt file \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        if loadedItems.count != index.ids.count {
            let rewrittenIndex = IndexFile(ids: loadedItems.map { $0.id })
            if let data = try? encoder.encode(rewrittenIndex) {
                try? data.write(to: indexURL, options: .atomic)
            }
        }

        return loadedItems
    }

    func saveAll(_ items: [Item]) throws {
        let existingIDs = existingIdentifiers()
        let newIDs = items.map { $0.id }

        for item in items {
            let fileURL = directory.appendingPathComponent("\(item.id.uuidString).json")
            let data = try encoder.encode(item)
            try data.write(to: fileURL, options: .atomic)
        }

        let removedIDs = existingIDs.subtracting(newIDs)
        for id in removedIDs {
            let fileURL = directory.appendingPathComponent("\(id.uuidString).json")
            try? fileManager.removeItem(at: fileURL)
        }

        let index = IndexFile(ids: newIDs)
        let data = try encoder.encode(index)
        try data.write(to: indexURL, options: .atomic)
    }

    private func existingIdentifiers() -> Set<UUID> {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? decoder.decode(IndexFile.self, from: data) else {
            return []
        }
        return Set(index.ids)
    }

    private struct IndexFile: Codable {
        let ids: [UUID]
    }
}
