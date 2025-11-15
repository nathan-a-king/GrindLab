import Foundation
import OSLog

final class BrewJournalRepository {
    private let logger = Logger(subsystem: "com.nateking.GrindLab", category: "BrewJournalRepository")
    private let legacyKey = "brewJournalEntries"
    private var store: JSONCollectionStore<BrewJournalEntry>

    init(controller: PersistenceController = .shared) {
        do {
            store = try JSONCollectionStore(name: "BrewJournalEntries", baseDirectory: controller.baseDirectory, fileManager: controller.fileManager)
            store.configure(dateEncodingStrategy: .iso8601, dateDecodingStrategy: .iso8601)
        } catch {
            fatalError("Failed to create BrewJournal store: \(error)")
        }

        migrateLegacyEntriesIfNeeded()
    }

    func loadEntries() -> [BrewJournalEntry] {
        do {
            return try store.loadAll()
        } catch {
            logger.error("Failed to load brew journal entries: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func persist(entries: [BrewJournalEntry]) {
        do {
            try store.saveAll(entries)
        } catch {
            logger.error("Failed to persist brew journal entries: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func migrateLegacyEntriesIfNeeded() {
        guard !store.hasExistingData else { return }
        guard let data = UserDefaults.standard.data(forKey: legacyKey) else { return }

        do {
            let entries = try decodeLegacyEntries(from: data)
            try store.saveAll(entries)
            UserDefaults.standard.removeObject(forKey: legacyKey)
        } catch {
            logger.error("Failed to migrate legacy brew journal entries: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func decodeLegacyEntries(from data: Data) throws -> [BrewJournalEntry] {
        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .iso8601

        if let entries = try? isoDecoder.decode([BrewJournalEntry].self, from: data) {
            return entries
        }

        let legacyDecoder = JSONDecoder()
        legacyDecoder.dateDecodingStrategy = .deferredToDate

        do {
            let entries = try legacyDecoder.decode([BrewJournalEntry].self, from: data)
            logger.notice("Migrated brew journal entries using legacy date encoding")
            return entries
        } catch {
            throw error
        }
    }
}
