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

    @Published var entries: [BrewJournalEntry] = []

    private let userDefaults = UserDefaults.standard
    private let storageKey = "brewJournalEntries"
    private let maxStoredEntries = 200 // Generous limit for brew logs

    private init() {
        loadEntries()
    }

    // MARK: - Core CRUD Operations

    /// Save a new brew journal entry
    func saveEntry(_ entry: BrewJournalEntry) {
        // Add to beginning of array (most recent first)
        entries.insert(entry, at: 0)

        // Limit storage to prevent bloat
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
        guard let index = entries.firstIndex(where: { $0.id == updatedEntry.id }) else {
            brewJournalLogger.error("Attempted to update non-existent entry: \(updatedEntry.id, privacy: .public)")
            return
        }

        entries[index] = updatedEntry
        persistEntries()
        brewJournalLogger.info("Updated brew journal entry: \(updatedEntry.displayTitle, privacy: .public)")
    }

    /// Delete a brew journal entry by ID
    func deleteEntry(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            brewJournalLogger.error("Attempted to delete non-existent entry: \(id, privacy: .public)")
            return
        }

        let removedEntry = entries.remove(at: index)
        persistEntries()
        brewJournalLogger.info("Deleted brew journal entry: \(removedEntry.displayTitle, privacy: .public)")
    }

    /// Delete a brew journal entry by index
    func deleteEntry(at index: Int) {
        guard index >= 0 && index < entries.count else {
            brewJournalLogger.error("Attempted to delete entry at invalid index: \(index, privacy: .public)")
            return
        }

        let removedEntry = entries.remove(at: index)
        persistEntries()
        brewJournalLogger.info("Deleted brew journal entry: \(removedEntry.displayTitle, privacy: .public)")
    }

    /// Get a specific entry by ID
    func getEntry(id: UUID) -> BrewJournalEntry? {
        return entries.first(where: { $0.id == id })
    }

    /// Get entries linked to a specific analysis
    func getEntriesLinkedTo(analysisId: UUID) -> [BrewJournalEntry] {
        return entries.filter { $0.linkedAnalysisId == analysisId }
    }

    /// Clear all brew journal entries
    func clearAllEntries() {
        entries.removeAll()
        persistEntries()
        brewJournalLogger.warning("Cleared all brew journal entries")
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

    /// Get entries that have linked analyses
    func getEntriesWithLinkedAnalysis() -> [BrewJournalEntry] {
        return entries.filter { $0.hasLinkedAnalysis }
    }

    /// Get entries without linked analyses
    func getEntriesWithoutLinkedAnalysis() -> [BrewJournalEntry] {
        return entries.filter { !$0.hasLinkedAnalysis }
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

    /// Average rating across all entries
    var averageRating: Double {
        let entriesWithRatings = entries.compactMap { $0.rating }
        guard !entriesWithRatings.isEmpty else { return 0 }

        let total = entriesWithRatings.reduce(0, +)
        return Double(total) / Double(entriesWithRatings.count)
    }

    /// Most used brew method
    var mostUsedBrewMethod: TastingNotes.BrewMethod? {
        let methodCounts = Dictionary(grouping: entries) { $0.brewParameters.brewMethod }
            .mapValues { $0.count }

        return methodCounts.max(by: { $0.value < $1.value })?.key
    }

    /// Most used grind type
    var mostUsedGrindType: CoffeeGrindType? {
        let grindTypeCounts = Dictionary(grouping: entries) { $0.grindType }
            .mapValues { $0.count }

        return grindTypeCounts.max(by: { $0.value < $1.value })?.key
    }

    /// Highest rated entry
    var highestRatedEntry: BrewJournalEntry? {
        return entries.max { ($0.rating ?? 0) < ($1.rating ?? 0) }
    }

    /// Entry count by grind type
    func entryCount(for grindType: CoffeeGrindType) -> Int {
        return entries.filter { $0.grindType == grindType }.count
    }

    /// Entry count by brew method
    func entryCount(for brewMethod: TastingNotes.BrewMethod) -> Int {
        return entries.filter { $0.brewParameters.brewMethod == brewMethod }.count
    }

    // MARK: - Validation

    /// Validate an entry before saving
    func validateEntry(_ entry: BrewJournalEntry) -> ValidationResult {
        var warnings: [String] = []
        var errors: [String] = []

        // Check for unusual brew parameters
        if entry.brewParameters.hasUnusualParameters {
            warnings.append("Brew parameters contain unusual values that may indicate data entry errors")
        }

        // Check for very old timestamp
        let daysSinceEntry = Calendar.current.dateComponents([.day], from: entry.timestamp, to: Date()).day ?? 0
        if daysSinceEntry > 30 {
            warnings.append("Entry timestamp is more than 30 days old")
        }

        // Check for future timestamp
        if entry.timestamp > Date() {
            warnings.append("Entry timestamp is in the future")
        }

        // Check for invalid rating
        if let rating = entry.rating, (rating < 1 || rating > 5) {
            errors.append("Rating must be between 1 and 5")
        }

        // Check for duplicate ID
        if entries.contains(where: { $0.id == entry.id }) {
            errors.append("Entry with this ID already exists")
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    struct ValidationResult {
        let isValid: Bool
        let errors: [String]
        let warnings: [String]

        var hasWarnings: Bool {
            return !warnings.isEmpty
        }
    }

    // MARK: - Private Persistence Methods

    private func persistEntries() {
        do {
            let data = try JSONEncoder().encode(entries)
            userDefaults.set(data, forKey: storageKey)

            brewJournalLogger.debug("Persisted \(self.entries.count, privacy: .public) brew journal entries")
        } catch {
            brewJournalLogger.error("Failed to persist brew journal entries: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadEntries() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            brewJournalLogger.info("No saved brew journal entries found")
            return
        }

        do {
            let loadedEntries = try JSONDecoder().decode([BrewJournalEntry].self, from: data)
            entries = loadedEntries

            brewJournalLogger.info("Loaded \(self.entries.count, privacy: .public) brew journal entries from storage")
        } catch {
            brewJournalLogger.error("Failed to load brew journal entries: \(error.localizedDescription, privacy: .public)")
            // Clear corrupted data
            userDefaults.removeObject(forKey: storageKey)
        }
    }

    // MARK: - Data Export/Import (Future)

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

        // Merge with existing entries (avoid duplicates by ID)
        let existingIds = Set(entries.map { $0.id })
        let newEntries = importedEntries.filter { !existingIds.contains($0.id) }

        entries.append(contentsOf: newEntries)
        entries.sort { $0.timestamp > $1.timestamp } // Re-sort by date

        // Apply storage limit
        if entries.count > maxStoredEntries {
            entries = Array(entries.prefix(maxStoredEntries))
        }

        persistEntries()

        brewJournalLogger.info("Imported \(newEntries.count, privacy: .public) new brew journal entries")
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
}
