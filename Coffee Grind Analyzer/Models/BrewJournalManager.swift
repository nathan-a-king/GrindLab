//
//  BrewJournalManager.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 11/8/25.
//

import Foundation
import Combine
import OSLog

private let brewJournalLogger = Logger(subsystem: "com.nateking.GrindLab", category: "BrewJournal")

// MARK: - Brew Journal Manager

class BrewJournalManager: ObservableObject {
    static let shared = BrewJournalManager()

    @Published private(set) var entries: [BrewJournalEntry] = []

    private let maxStoredEntries = 200 // Generous limit for brew logs
    private let persistenceQueue = DispatchQueue(label: "com.nateking.GrindLab.brewJournalPersistence", qos: .utility)
    private let repository: BrewJournalRepository

    private init(repository: BrewJournalRepository = BrewJournalRepository()) {
        self.repository = repository
        loadEntries()
    }

    // MARK: - Core CRUD Operations

    /// Save a new brew journal entry
    func saveEntry(_ entry: BrewJournalEntry) {
        if Thread.isMainThread {
            insertEntry(entry)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.insertEntry(entry)
            }
        }
    }

    private func insertEntry(_ entry: BrewJournalEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maxStoredEntries {
            let removed = entries.count - maxStoredEntries
            entries = Array(entries.prefix(maxStoredEntries))
            brewJournalLogger.warning("Removed \(removed, privacy: .public) oldest entries to maintain storage limit")
        }
        persistEntries()
        brewJournalLogger.info("Saved brew journal entry: \(entry.displayTitle, privacy: .public)")
    }

    /// Update an existing brew journal entry
    func updateEntry(_ updatedEntry: BrewJournalEntry) {
        let updateBlock = { [weak self] in
            guard let self else { return }
            guard let index = self.entries.firstIndex(where: { $0.id == updatedEntry.id }) else {
                brewJournalLogger.error("Attempted to update non-existent entry: \(updatedEntry.id, privacy: .public)")
                return
            }

            self.entries[index] = updatedEntry
            self.persistEntries()
            brewJournalLogger.info("Updated brew journal entry: \(updatedEntry.displayTitle, privacy: .public)")
        }

        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async(execute: updateBlock)
        }
    }

    /// Delete a brew journal entry by ID
    func deleteEntry(id: UUID) {
        let deleteBlock = { [weak self] in
            guard let self else { return }
            guard let index = self.entries.firstIndex(where: { $0.id == id }) else {
                brewJournalLogger.error("Attempted to delete non-existent entry: \(id, privacy: .public)")
                return
            }

            let removedEntry = self.entries.remove(at: index)
            self.persistEntries()
            brewJournalLogger.info("Deleted brew journal entry: \(removedEntry.displayTitle, privacy: .public)")
        }

        if Thread.isMainThread {
            deleteBlock()
        } else {
            DispatchQueue.main.async(execute: deleteBlock)
        }
    }

    /// Delete a brew journal entry by index
    func deleteEntry(at index: Int) {
        let deleteBlock = { [weak self] in
            guard let self else { return }
            guard index >= 0 && index < self.entries.count else {
                brewJournalLogger.error("Attempted to delete entry at invalid index: \(index, privacy: .public)")
                return
            }

            let removedEntry = self.entries.remove(at: index)
            self.persistEntries()
            brewJournalLogger.info("Deleted brew journal entry: \(removedEntry.displayTitle, privacy: .public)")
        }

        if Thread.isMainThread {
            deleteBlock()
        } else {
            DispatchQueue.main.async(execute: deleteBlock)
        }
    }

    /// Get a specific entry by ID
    func getEntry(id: UUID) -> BrewJournalEntry? {
        return entries.first(where: { $0.id == id })
    }

    /// Clear all brew journal entries
    func clearAllEntries() {
        let clearBlock = { [weak self] in
            guard let self else { return }
            self.entries.removeAll()
            self.persistEntries()
            brewJournalLogger.warning("Cleared all brew journal entries")
        }

        if Thread.isMainThread {
            clearBlock()
        } else {
            DispatchQueue.main.async(execute: clearBlock)
        }
    }

    // MARK: - Sorting Options

    enum SortOption {
        case dateNewest
        case dateOldest
        case ratingHighest
        case ratingLowest
        case beanName
        case brewMethod
    }

    /// Get entries sorted by specified option
    func getEntriesSorted(by option: SortOption) -> [BrewJournalEntry] {
        switch option {
        case .dateNewest:
            return entries.sorted { $0.timestamp > $1.timestamp }
        case .dateOldest:
            return entries.sorted { $0.timestamp < $1.timestamp }
        case .ratingHighest:
            return entries.sorted {
                let rating0 = $0.rating ?? 0
                let rating1 = $1.rating ?? 0
                return rating0 > rating1
            }
        case .ratingLowest:
            return entries.sorted {
                let rating0 = $0.rating ?? 0
                let rating1 = $1.rating ?? 0
                return rating0 < rating1
            }
        case .beanName:
            return entries.sorted {
                let name0 = $0.coffeeBean?.displayName ?? "zzz"
                let name1 = $1.coffeeBean?.displayName ?? "zzz"
                return name0 < name1
            }
        case .brewMethod:
            return entries.sorted {
                $0.brewParameters.brewMethod.rawValue < $1.brewParameters.brewMethod.rawValue
            }
        }
    }

    // MARK: - Filtering Options

    /// Get entries filtered by grind type
    func getEntriesFiltered(by grindType: CoffeeGrindType) -> [BrewJournalEntry] {
        return entries.filter { $0.grindType == grindType }
    }

    /// Get entries filtered by brew method
    func getEntriesFiltered(by brewMethod: TastingNotes.BrewMethod) -> [BrewJournalEntry] {
        return entries.filter { $0.brewParameters.brewMethod == brewMethod }
    }

    /// Get entries filtered by rating
    func getEntriesFiltered(byRating rating: Int) -> [BrewJournalEntry] {
        return entries.filter { $0.rating == rating }
    }

    /// Get entries filtered by minimum rating
    func getEntriesFiltered(byMinimumRating minRating: Int) -> [BrewJournalEntry] {
        return entries.filter { ($0.rating ?? 0) >= minRating }
    }

    /// Get entries within a date range
    func getEntriesFiltered(from startDate: Date, to endDate: Date) -> [BrewJournalEntry] {
        return entries.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Search entries by query string
    func searchEntries(query: String) -> [BrewJournalEntry] {
        guard !query.isEmpty else { return entries }
        return entries.filter { $0.matchesSearchQuery(query) }
    }

    // MARK: - Quick Access Methods

    /// Get recent entries (most recent first)
    func getRecentEntries(limit: Int = 10) -> [BrewJournalEntry] {
        return Array(entries.prefix(limit))
    }

    /// Get entries from today
    func getTodaysEntries() -> [BrewJournalEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return entries.filter { entry in
            entry.timestamp >= today && entry.timestamp < tomorrow
        }
    }

    /// Get entries from this week
    func getThisWeeksEntries() -> [BrewJournalEntry] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!

        return entries.filter { $0.timestamp >= weekAgo }
    }

    // MARK: - Statistics

    /// Total number of brew journal entries
    var totalEntries: Int {
        return entries.count
    }

    /// Average rating for entries with ratings
    var averageRating: Double {
        let ratedEntries = entries.compactMap { $0.rating }
        guard !ratedEntries.isEmpty else { return 0 }
        let total = ratedEntries.reduce(0, +)
        return Double(total) / Double(ratedEntries.count)
    }

    /// Count of entries per brew method
    var entriesByBrewMethod: [TastingNotes.BrewMethod: Int] {
        var counts: [TastingNotes.BrewMethod: Int] = [:]
        for entry in entries {
            counts[entry.brewParameters.brewMethod, default: 0] += 1
        }
        return counts
    }

    /// Count of entries per grind type
    var entriesByGrindType: [CoffeeGrindType: Int] {
        var counts: [CoffeeGrindType: Int] = [:]
        for entry in entries {
            counts[entry.grindType, default: 0] += 1
        }
        return counts
    }

    // MARK: - Data Export/Import

    /// Export all entries as JSON string
    func exportAsJSON() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(entries)
            return String(data: data, encoding: .utf8)
        } catch {
            brewJournalLogger.error("Failed to export entries as JSON: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Import entries from JSON string
    func importFromJSON(_ jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let importedEntries = try decoder.decode([BrewJournalEntry].self, from: data)

        DispatchQueue.main.async {
            // Merge with existing entries (avoid duplicates by ID)
            let existingIds = Set(self.entries.map { $0.id })
            let newEntries = importedEntries.filter { !existingIds.contains($0.id) }

            self.entries.append(contentsOf: newEntries)
            self.entries.sort { $0.timestamp > $1.timestamp } // Re-sort by date

            // Apply storage limit
            if self.entries.count > self.maxStoredEntries {
                self.entries = Array(self.entries.prefix(self.maxStoredEntries))
            }

            self.persistEntries()

            brewJournalLogger.info("Imported \(newEntries.count, privacy: .public) new brew journal entries")
        }
    }

    enum ImportError: Error, LocalizedError {
        case invalidData
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidData:
                return "Invalid JSON data"
            case .decodingFailed:
                return "Failed to decode brew journal entries"
            }
        }
    }

    // MARK: - Persistence

    private func loadEntries() {
        persistenceQueue.async { [weak self] in
            guard let self else { return }
            let loaded = self.repository.loadEntries()
            DispatchQueue.main.async { [weak self] in
                self?.entries = loaded
            }
        }
    }

    private func persistEntries() {
        let snapshot = entries
        persistenceQueue.async { [weak self] in
            guard let self else { return }
            self.repository.persist(entries: snapshot)
        }
    }
}
