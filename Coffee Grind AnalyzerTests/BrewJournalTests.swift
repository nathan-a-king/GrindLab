//
//  BrewJournalTests.swift
//  Coffee Grind AnalyzerTests
//
//  Tests for brew journal models and persistence
//

import Testing
import Foundation
@testable import GrindLab

@MainActor
struct BrewJournalTests {

    // MARK: - Model Encoding/Decoding Tests

    @Test func testBrewJournalEntry_EncodeDecode_PreservesAllData() async throws {
        let entry = createTestEntry()

        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BrewJournalEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.grindType == entry.grindType)
        #expect(decoded.brewParameters.brewMethod == entry.brewParameters.brewMethod)
        #expect(decoded.notes == entry.notes)
    }

    @Test func testCoffeeBeanInfo_EncodeDecode_PreservesData() async throws {
        let beanInfo = CoffeeBeanInfo(
            name: "Ethiopia Yirgacheffe",
            roaster: "Blue Bottle",
            roastDate: Date(),
            roastLevel: .mediumLight,
            origin: "Ethiopia",
            process: "Washed",
            notes: "Floral and citrus"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(beanInfo)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CoffeeBeanInfo.self, from: data)

        #expect(decoded.name == beanInfo.name)
        #expect(decoded.roaster == beanInfo.roaster)
        #expect(decoded.roastLevel == beanInfo.roastLevel)
        #expect(decoded.origin == beanInfo.origin)
    }

    @Test func testBrewParameters_EncodeDecode_PreservesData() async throws {
        let params = BrewParameters(
            brewMethod: .espresso,
            doseIn: 18.0,
            yieldOut: 36.0,
            brewTime: 28.0,
            waterTemp: 93.0,
            grindSetting: "3.5"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(params)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BrewParameters.self, from: data)

        #expect(decoded.brewMethod == params.brewMethod)
        #expect(decoded.doseIn == params.doseIn)
        #expect(decoded.yieldOut == params.yieldOut)
        #expect(decoded.brewTime == params.brewTime)
    }

    @Test func testBrewParameters_RatioCalculation_IsCorrect() async {
        let params = BrewParameters(
            brewMethod: .espresso,
            doseIn: 18.0,
            yieldOut: 36.0
        )

        #expect(params.ratio == 2.0)
        #expect(params.ratioDisplay == "1:2.0")
    }

    @Test func testBrewParameters_BrewTimeDisplay_FormatsCorrectly() async {
        var params = BrewParameters(
            brewMethod: .espresso,
            brewTime: 28.0
        )
        #expect(params.brewTimeDisplay == "28s")

        params = BrewParameters(
            brewMethod: .pourOver,
            brewTime: 185.0 // 3:05
        )
        #expect(params.brewTimeDisplay == "3:05")
    }

    @Test func testCoffeeBeanInfo_DaysFromRoast_CalculatesCorrectly() async {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        let beanInfo = CoffeeBeanInfo(
            name: "Test Bean",
            roastDate: sevenDaysAgo
        )

        #expect(beanInfo.daysFromRoast == 7)
    }

    @Test func testCoffeeBeanInfo_FreshnessStatus_CategorizesProperly() async {
        var beanInfo: CoffeeBeanInfo

        // Very fresh (2 days old)
        beanInfo = CoffeeBeanInfo(
            name: "Test",
            roastDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())
        )
        #expect(beanInfo.freshnessStatus == "Very Fresh")

        // Fresh (7 days old)
        beanInfo = CoffeeBeanInfo(
            name: "Test",
            roastDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())
        )
        #expect(beanInfo.freshnessStatus == "Fresh")

        // Aging (40 days old)
        beanInfo = CoffeeBeanInfo(
            name: "Test",
            roastDate: Calendar.current.date(byAdding: .day, value: -40, to: Date())
        )
        #expect(beanInfo.freshnessStatus == "Aging")
    }

    // MARK: - Manager CRUD Operation Tests

    @Test func testBrewJournalManager_SaveEntry_IncreasesCount() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let initialCount = manager.totalEntries
        let entry = createTestEntry()

        manager.saveEntry(entry)

        #expect(manager.totalEntries == initialCount + 1)
        #expect(manager.entries.first?.id == entry.id)
    }

    @Test func testBrewJournalManager_SaveMultiple_MaintainsOrder() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let entry1 = createTestEntry(beanName: "First")
        let entry2 = createTestEntry(beanName: "Second")
        let entry3 = createTestEntry(beanName: "Third")

        manager.saveEntry(entry1)
        manager.saveEntry(entry2)
        manager.saveEntry(entry3)

        #expect(manager.totalEntries == 3)

        // Most recent should be first
        #expect(manager.entries[0].coffeeBean?.name == "Third")
        #expect(manager.entries[1].coffeeBean?.name == "Second")
        #expect(manager.entries[2].coffeeBean?.name == "First")
    }

    @Test func testBrewJournalManager_UpdateEntry_ModifiesExisting() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let original = createTestEntry(rating: 3)
        manager.saveEntry(original)

        var updated = original
        updated = BrewJournalEntry(
            id: updated.id,
            timestamp: updated.timestamp,
            grindType: updated.grindType,
            coffeeBean: updated.coffeeBean,
            brewParameters: updated.brewParameters,
            tastingNotes: TastingNotes(
                brewMethod: .espresso,
                overallRating: 5,
                tastingTags: ["Excellent"],
                extractionNotes: nil,
                extractionTime: nil,
                waterTemp: nil,
                doseIn: nil,
                yieldOut: nil
            ),
            notes: "Updated notes"
        )

        manager.updateEntry(updated)

        #expect(manager.totalEntries == 1)
        #expect(manager.entries.first?.rating == 5)
        #expect(manager.entries.first?.notes == "Updated notes")
    }

    @Test func testBrewJournalManager_DeleteEntryById_RemovesCorrectEntry() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let entry1 = createTestEntry(beanName: "Keep")
        let entry2 = createTestEntry(beanName: "Delete")

        manager.saveEntry(entry1)
        manager.saveEntry(entry2)

        manager.deleteEntry(id: entry2.id)

        #expect(manager.totalEntries == 1)
        #expect(manager.entries.first?.coffeeBean?.name == "Keep")
    }

    @Test func testBrewJournalManager_DeleteEntryByIndex_RemovesCorrectEntry() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(beanName: "First"))
        manager.saveEntry(createTestEntry(beanName: "Second"))

        manager.deleteEntry(at: 0) // Delete "Second" (most recent)

        #expect(manager.totalEntries == 1)
        #expect(manager.entries.first?.coffeeBean?.name == "First")
    }

    @Test func testBrewJournalManager_GetEntryById_ReturnsCorrectEntry() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let entry = createTestEntry(beanName: "Find Me")
        manager.saveEntry(entry)

        let found = manager.getEntry(id: entry.id)

        #expect(found != nil)
        #expect(found?.coffeeBean?.name == "Find Me")
    }

    @Test func testBrewJournalManager_ClearAll_RemovesEverything() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry())
        manager.saveEntry(createTestEntry())
        manager.saveEntry(createTestEntry())

        #expect(manager.totalEntries == 3)

        manager.clearAllEntries()

        #expect(manager.totalEntries == 0)
        #expect(manager.entries.isEmpty)
    }

    // MARK: - Sorting Tests

    @Test func testBrewJournalManager_SortByDateNewest_OrdersCorrectly() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let old = createTestEntry(timestamp: Date().addingTimeInterval(-3600))
        let newer = createTestEntry(timestamp: Date().addingTimeInterval(-1800))
        let newest = createTestEntry(timestamp: Date())

        manager.saveEntry(old)
        manager.saveEntry(newer)
        manager.saveEntry(newest)

        let sorted = manager.getEntriesSorted(by: .dateNewest)

        #expect(sorted[0].id == newest.id)
        #expect(sorted[2].id == old.id)
    }

    @Test func testBrewJournalManager_SortByRatingHighest_OrdersCorrectly() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(rating: 3))
        manager.saveEntry(createTestEntry(rating: 5))
        manager.saveEntry(createTestEntry(rating: 4))

        let sorted = manager.getEntriesSorted(by: .ratingHighest)

        #expect(sorted[0].rating == 5)
        #expect(sorted[1].rating == 4)
        #expect(sorted[2].rating == 3)
    }

    @Test func testBrewJournalManager_SortByBeanName_OrdersAlphabetically() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(beanName: "Charlie"))
        manager.saveEntry(createTestEntry(beanName: "Alpha"))
        manager.saveEntry(createTestEntry(beanName: "Bravo"))

        let sorted = manager.getEntriesSorted(by: .beanName)

        #expect(sorted[0].coffeeBean?.name == "Alpha")
        #expect(sorted[1].coffeeBean?.name == "Bravo")
        #expect(sorted[2].coffeeBean?.name == "Charlie")
    }

    // MARK: - Filtering Tests

    @Test func testBrewJournalManager_FilterByGrindType_ReturnsMatching() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(grindType: .espresso))
        manager.saveEntry(createTestEntry(grindType: .filter))
        manager.saveEntry(createTestEntry(grindType: .espresso))

        let grindType: CoffeeGrindType = .espresso
        let filtered = manager.getEntriesFiltered(by: grindType)

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.grindType == .espresso })
    }

    @Test func testBrewJournalManager_FilterByBrewMethod_ReturnsMatching() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(brewMethod: .espresso))
        manager.saveEntry(createTestEntry(brewMethod: .pourOver))
        manager.saveEntry(createTestEntry(brewMethod: .espresso))

        let brewMethod: TastingNotes.BrewMethod = .espresso
        let filtered = manager.getEntriesFiltered(by: brewMethod)

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.brewParameters.brewMethod == .espresso })
    }

    @Test func testBrewJournalManager_FilterByMinimumRating_ReturnsQualityBrews() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(rating: 3))
        manager.saveEntry(createTestEntry(rating: 4))
        manager.saveEntry(createTestEntry(rating: 5))
        manager.saveEntry(createTestEntry(rating: 2))

        let filtered = manager.getEntriesFiltered(byMinimumRating: 4)

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { ($0.rating ?? 0) >= 4 })
    }

    @Test func testBrewJournalManager_FilterByDateRange_ReturnsWithinRange() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        manager.saveEntry(createTestEntry(timestamp: weekAgo))
        manager.saveEntry(createTestEntry(timestamp: threeDaysAgo))
        manager.saveEntry(createTestEntry(timestamp: yesterday))

        let filtered = manager.getEntriesFiltered(
            from: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            to: Date()
        )

        #expect(filtered.count == 2) // threeDaysAgo and yesterday
    }

    @Test func testBrewJournalManager_SearchEntries_FindsMatching() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(beanName: "Ethiopia Yirgacheffe"))
        manager.saveEntry(createTestEntry(beanName: "Colombia Supremo"))
        manager.saveEntry(createTestEntry(notes: "This had great Ethiopia notes"))

        let results = manager.searchEntries(query: "Ethiopia")

        #expect(results.count == 2)
    }

    @Test func testBrewJournalManager_SearchEntries_EmptyQuery_ReturnsAll() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry())
        manager.saveEntry(createTestEntry())

        let results = manager.searchEntries(query: "")

        #expect(results.count == 2)
    }

    // MARK: - Quick Access Tests

    @Test func testBrewJournalManager_GetRecentEntries_LimitsResults() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        for _ in 1...20 {
            manager.saveEntry(createTestEntry())
        }

        let recent = manager.getRecentEntries(limit: 5)

        #expect(recent.count == 5)
    }

    @Test func testBrewJournalManager_GetTodaysEntries_FiltersCorrectly() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        manager.saveEntry(createTestEntry(timestamp: today))
        manager.saveEntry(createTestEntry(timestamp: yesterday))
        manager.saveEntry(createTestEntry(timestamp: today))

        let todaysEntries = manager.getTodaysEntries()

        #expect(todaysEntries.count == 2)
    }

    @Test func testBrewJournalManager_GetThisWeeksEntries_FiltersCorrectly() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let today = Date()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        manager.saveEntry(createTestEntry(timestamp: today))
        manager.saveEntry(createTestEntry(timestamp: threeDaysAgo))
        manager.saveEntry(createTestEntry(timestamp: tenDaysAgo))

        let thisWeek = manager.getThisWeeksEntries()

        #expect(thisWeek.count == 2)
    }

    // MARK: - Statistics Tests

    @Test func testBrewJournalManager_AverageRating_CalculatesCorrectly() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(rating: 3))
        manager.saveEntry(createTestEntry(rating: 4))
        manager.saveEntry(createTestEntry(rating: 5))

        let average = manager.averageRating

        #expect(abs(average - 4.0) < 0.1) // (3+4+5)/3 = 4.0
    }

    @Test func testBrewJournalManager_AverageRating_EmptyReturnsZero() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        #expect(manager.averageRating == 0.0)
    }

    @Test func testBrewJournalManager_MostUsedBrewMethod_ReturnsCorrect() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(brewMethod: .espresso))
        manager.saveEntry(createTestEntry(brewMethod: .espresso))
        manager.saveEntry(createTestEntry(brewMethod: .pourOver))
        manager.saveEntry(createTestEntry(brewMethod: .espresso))

        #expect(manager.mostUsedBrewMethod == .espresso)
    }

    @Test func testBrewJournalManager_MostUsedGrindType_ReturnsCorrect() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(grindType: .filter))
        manager.saveEntry(createTestEntry(grindType: .espresso))
        manager.saveEntry(createTestEntry(grindType: .filter))
        manager.saveEntry(createTestEntry(grindType: .filter))

        #expect(manager.mostUsedGrindType == .filter)
    }

    @Test func testBrewJournalManager_HighestRatedEntry_ReturnsCorrect() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(beanName: "Good", rating: 3))
        manager.saveEntry(createTestEntry(beanName: "Best", rating: 5))
        manager.saveEntry(createTestEntry(beanName: "Better", rating: 4))

        let highest = manager.highestRatedEntry

        #expect(highest?.coffeeBean?.name == "Best")
        #expect(highest?.rating == 5)
    }

    @Test func testBrewJournalManager_EntryCount_CalculatesCorrectly() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(grindType: .espresso, brewMethod: .espresso))
        manager.saveEntry(createTestEntry(grindType: .espresso, brewMethod: .pourOver))
        manager.saveEntry(createTestEntry(grindType: .filter, brewMethod: .pourOver))

        let espressoGrind: CoffeeGrindType = .espresso
        let pourOverMethod: TastingNotes.BrewMethod = .pourOver
        #expect(manager.entryCount(for: espressoGrind) == 2)
        #expect(manager.entryCount(for: pourOverMethod) == 2)
    }

    // MARK: - Validation Tests

    @Test func testBrewJournalManager_ValidateEntry_AcceptsValidEntry() async {
        let manager = BrewJournalManager.shared
        let entry = createTestEntry()

        let result = manager.validateEntry(entry)

        #expect(result.isValid)
        #expect(result.errors.isEmpty)
    }

    @Test func testBrewJournalManager_ValidateEntry_RejectsInvalidRating() async {
        let manager = BrewJournalManager.shared

        var entry = createTestEntry(rating: 10) // Invalid rating

        let result = manager.validateEntry(entry)

        #expect(!result.isValid)
        #expect(!result.errors.isEmpty)
    }

    @Test func testBrewJournalManager_ValidateEntry_WarnsFutureTimestamp() async {
        let manager = BrewJournalManager.shared

        let future = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let entry = createTestEntry(timestamp: future)

        let result = manager.validateEntry(entry)

        #expect(result.hasWarnings)
    }

    // MARK: - Storage Limit Tests

    @Test func testBrewJournalManager_ExceedsLimit_TrimsOldest() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        // Save 205 entries (limit is 200)
        for i in 1...205 {
            manager.saveEntry(createTestEntry(beanName: "Entry \(i)"))
        }

        // Should only keep 200 most recent
        #expect(manager.totalEntries == 200)

        // Most recent should be "Entry 205"
        #expect(manager.entries.first?.coffeeBean?.name == "Entry 205")

        // Oldest kept should be "Entry 6"
        #expect(manager.entries.last?.coffeeBean?.name == "Entry 6")
    }

    // MARK: - Persistence Tests

    @Test func testBrewJournalManager_Persistence_RoundTrip() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let entry = createTestEntry(
            beanName: "Persistence Test",
            rating: 5,
            notes: "Testing persistence"
        )
        manager.saveEntry(entry)

        // Verify entry was added
        #expect(manager.totalEntries >= 1)

        // Verify data is accessible immediately (in-memory)
        let loaded = manager.entries.first { $0.id == entry.id }
        #expect(loaded != nil)
        #expect(loaded?.coffeeBean?.name == "Persistence Test")
        #expect(loaded?.rating == 5)
        #expect(loaded?.notes == "Testing persistence")

        // Note: Actual UserDefaults persistence tested by app lifecycle,
        // not easily testable in unit tests with singleton pattern
    }

    // MARK: - Edge Cases

    @Test func testBrewJournalManager_DeleteInvalidIndex_DoesNotCrash() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry())

        // Try to delete invalid index
        manager.deleteEntry(at: 999)

        // Should not crash, entry should still exist
        #expect(manager.totalEntries == 1)
    }

    @Test func testBrewJournalManager_UpdateNonexistent_DoesNotCrash() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let nonexistent = createTestEntry()

        // Should not crash
        manager.updateEntry(nonexistent)

        #expect(manager.totalEntries == 0)
    }

    @Test func testBrewJournalManager_DeleteNonexistent_DoesNotCrash() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let fakeId = UUID()

        // Should not crash
        manager.deleteEntry(id: fakeId)

        #expect(manager.totalEntries == 0)
    }

    @Test func testBrewJournalEntry_DisplayTitle_UsesBeenName() async {
        let entry = createTestEntry(beanName: "Ethiopia")

        #expect(entry.displayTitle == "Ethiopia")
    }

    @Test func testBrewJournalEntry_DisplayTitle_FallsBackToGrindType() async {
        let entry = BrewJournalEntry(
            grindType: .espresso,
            brewParameters: BrewParameters(brewMethod: .espresso)
        )

        #expect(entry.displayTitle.contains("Espresso"))
    }

    @Test func testBrewJournalEntry_MatchesSearchQuery_FindsInMultipleFields() async {
        var entry = createTestEntry(
            beanName: "Ethiopia",
            notes: "Fruity and bright"
        )

        #expect(entry.matchesSearchQuery("ethiopia"))
        #expect(entry.matchesSearchQuery("fruity"))
        #expect(entry.matchesSearchQuery("Espresso")) // grind type
    }

    // MARK: - Export/Import Tests

    @Test func testBrewJournalManager_ExportJSON_CreatesValidJSON() async {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        manager.saveEntry(createTestEntry(beanName: "Export Test"))

        let json = manager.exportAsJSON()

        #expect(json != nil)
        #expect(json?.contains("Export Test") == true)
    }

    @Test func testBrewJournalManager_ImportJSON_LoadsEntries() async throws {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        // Create and export an entry
        let originalEntry = createTestEntry(beanName: "Import Test")
        manager.saveEntry(originalEntry)

        guard let jsonString = manager.exportAsJSON() else {
            Issue.record("Failed to export JSON")
            return
        }

        // Clear and re-import
        manager.clearAllEntries()
        try manager.importFromJSON(jsonString)

        #expect(manager.totalEntries == 1)
        #expect(manager.entries.first?.coffeeBean?.name == "Import Test")
    }

    @Test func testBrewJournalManager_ImportJSON_SkipsDuplicates() async throws {
        let manager = BrewJournalManager.shared
        manager.clearAllEntries()

        let entry = createTestEntry(beanName: "Duplicate Test")
        manager.saveEntry(entry)

        guard let jsonString = manager.exportAsJSON() else {
            Issue.record("Failed to export JSON")
            return
        }

        // Try to import the same data (should skip duplicates)
        try manager.importFromJSON(jsonString)

        #expect(manager.totalEntries == 1) // Should not duplicate
    }

    // MARK: - Helper Methods

    private func createTestEntry(
        timestamp: Date = Date(),
        grindType: CoffeeGrindType = .espresso,
        beanName: String? = nil,
        brewMethod: TastingNotes.BrewMethod = .espresso,
        rating: Int? = nil,
        notes: String? = nil
    ) -> BrewJournalEntry {
        var beanInfo: CoffeeBeanInfo? = nil
        if let beanName = beanName {
            beanInfo = CoffeeBeanInfo(
                name: beanName,
                roaster: "Test Roaster",
                roastDate: Date(),
                roastLevel: .medium
            )
        }

        let brewParams = BrewParameters(
            brewMethod: brewMethod,
            doseIn: 18.0,
            yieldOut: 36.0,
            brewTime: 28.0,
            waterTemp: 93.0,
            grindSetting: "3.5"
        )

        var tastingNotes: TastingNotes? = nil
        if let rating = rating {
            tastingNotes = TastingNotes(
                brewMethod: brewMethod,
                overallRating: rating,
                tastingTags: ["Test"],
                extractionNotes: nil,
                extractionTime: nil,
                waterTemp: nil,
                doseIn: nil,
                yieldOut: nil
            )
        }

        return BrewJournalEntry(
            timestamp: timestamp,
            grindType: grindType,
            coffeeBean: beanInfo,
            brewParameters: brewParams,
            tastingNotes: tastingNotes,
            notes: notes
        )
    }
}
