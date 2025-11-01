//
//  HistoryManagerTests.swift
//  Coffee Grind AnalyzerTests
//
//  Tests for data persistence and history management
//

import Testing
import UIKit
@testable import GrindLab

@MainActor
struct HistoryManagerTests {

    // MARK: - Save and Load Tests

    @Test func testHistoryManager_SaveAnalysis_IncreasesCount() async {
        let manager = CoffeeAnalysisHistoryManager()
        let initialCount = manager.totalAnalyses

        let results = createTestResults()
        manager.saveAnalysis(results, name: "Test Analysis")

        #expect(manager.totalAnalyses == initialCount + 1)
        #expect(manager.savedAnalyses.first?.name == "Test Analysis")
    }

    @Test func testHistoryManager_SaveMultiple_MaintainsOrder() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses() // Start fresh

        manager.saveAnalysis(createTestResults(), name: "First")
        manager.saveAnalysis(createTestResults(), name: "Second")
        manager.saveAnalysis(createTestResults(), name: "Third")

        #expect(manager.totalAnalyses == 3)

        // Most recent should be first
        #expect(manager.savedAnalyses[0].name == "Third")
        #expect(manager.savedAnalyses[1].name == "Second")
        #expect(manager.savedAnalyses[2].name == "First")
    }

    @Test func testHistoryManager_SaveWithImage_PreservesImage() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        let testImage = createTestImage()
        var results = createTestResults()
        results = CoffeeAnalysisResults(
            uniformityScore: results.uniformityScore,
            averageSize: results.averageSize,
            medianSize: results.medianSize,
            standardDeviation: results.standardDeviation,
            finesPercentage: results.finesPercentage,
            bouldersPercentage: results.bouldersPercentage,
            particleCount: results.particleCount,
            particles: results.particles,
            confidence: results.confidence,
            image: testImage,
            processedImage: testImage,
            grindType: results.grindType,
            timestamp: results.timestamp,
            calibrationFactor: results.calibrationFactor
        )

        manager.saveAnalysis(results, name: "With Image")

        // Verify image paths are set
        let savedAnalysis = manager.savedAnalyses.first
        #expect(savedAnalysis?.originalImagePath != nil)
        #expect(savedAnalysis?.processedImagePath != nil)

        // Verify images can be loaded
        if let originalPath = savedAnalysis?.originalImagePath {
            let loadedImage = manager.loadImage(from: originalPath)
            #expect(loadedImage != nil)
        }
    }

    @Test func testHistoryManager_DefaultName_IncludesGrindTypeAndScore() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        let results = createTestResults(uniformityScore: 85.0, grindType: .espresso)
        manager.saveAnalysis(results) // No custom name

        let savedAnalysis = manager.savedAnalyses.first
        #expect(savedAnalysis?.name.contains("Espresso") == true)
        #expect(savedAnalysis?.name.contains("85") == true)
    }

    // MARK: - Update Tests

    @Test func testHistoryManager_UpdateTastingNotes_PreservesOtherData() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        let originalResults = createTestResults()
        manager.saveAnalysis(originalResults, name: "Original")

        guard let analysisId = manager.savedAnalyses.first?.id else {
            Issue.record("Failed to get analysis ID")
            return
        }

        let tastingNotes = TastingNotes(
            brewMethod: .espresso,
            overallRating: 4,
            tastingTags: ["Balanced", "Sweet"],
            extractionNotes: "Good extraction",
            extractionTime: 28.0,
            waterTemp: 93.0,
            doseIn: 18.0,
            yieldOut: 36.0
        )

        manager.updateAnalysisTastingNotes(analysisId: analysisId, tastingNotes: tastingNotes)

        // Verify tasting notes were added
        let updatedAnalysis = manager.savedAnalyses.first
        #expect(updatedAnalysis?.results.tastingNotes != nil)
        #expect(updatedAnalysis?.results.tastingNotes?.brewMethod == .espresso)
        #expect(updatedAnalysis?.results.tastingNotes?.overallRating == 4)

        // Verify other data preserved
        #expect(updatedAnalysis?.name == "Original")
        #expect(updatedAnalysis?.results.uniformityScore == originalResults.uniformityScore)
    }

    // MARK: - Delete Tests

    @Test func testHistoryManager_DeleteAnalysis_RemovesFromList() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        manager.saveAnalysis(createTestResults(), name: "To Delete")
        manager.saveAnalysis(createTestResults(), name: "To Keep")

        #expect(manager.totalAnalyses == 2)

        manager.deleteAnalysis(at: 0) // Delete "To Keep" (most recent)

        #expect(manager.totalAnalyses == 1)
        #expect(manager.savedAnalyses.first?.name == "To Delete")
    }

    @Test func testHistoryManager_DeleteById_RemovesCorrectAnalysis() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        manager.saveAnalysis(createTestResults(), name: "First")
        manager.saveAnalysis(createTestResults(), name: "Second")

        guard let idToDelete = manager.savedAnalyses.first(where: { $0.name == "First" })?.id else {
            Issue.record("Failed to find analysis")
            return
        }

        manager.deleteAnalysis(withId: idToDelete)

        #expect(manager.totalAnalyses == 1)
        #expect(manager.savedAnalyses.first?.name == "Second")
    }

    @Test func testHistoryManager_ClearAll_RemovesEverything() async {
        let manager = CoffeeAnalysisHistoryManager()

        manager.saveAnalysis(createTestResults(), name: "Test 1")
        manager.saveAnalysis(createTestResults(), name: "Test 2")
        manager.saveAnalysis(createTestResults(), name: "Test 3")

        #expect(manager.totalAnalyses >= 3)

        manager.clearAllAnalyses()

        #expect(manager.totalAnalyses == 0)
        #expect(manager.savedAnalyses.isEmpty)
    }

    // MARK: - Storage Limit Tests

    @Test func testHistoryManager_ExceedsLimit_TrimsOldest() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        // Save 55 analyses (limit is 50)
        for i in 1...55 {
            manager.saveAnalysis(createTestResults(), name: "Analysis \(i)")
        }

        // Should only keep 50 most recent
        #expect(manager.totalAnalyses == 50)

        // Most recent should be "Analysis 55"
        #expect(manager.savedAnalyses.first?.name == "Analysis 55")

        // Oldest kept should be "Analysis 6"
        #expect(manager.savedAnalyses.last?.name == "Analysis 6")
    }

    // MARK: - Filter and Search Tests

    @Test func testHistoryManager_FilterByGrindType_ReturnsMatching() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        manager.saveAnalysis(createTestResults(grindType: .espresso), name: "Espresso 1")
        manager.saveAnalysis(createTestResults(grindType: .filter), name: "Filter 1")
        manager.saveAnalysis(createTestResults(grindType: .espresso), name: "Espresso 2")

        let espressoResults = manager.analysesForGrindType(.espresso)

        #expect(espressoResults.count == 2)
        #expect(espressoResults.allSatisfy { $0.results.grindType == .espresso })
    }

    @Test func testHistoryManager_RecentAnalyses_ReturnsLimited() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        for i in 1...10 {
            manager.saveAnalysis(createTestResults(), name: "Analysis \(i)")
        }

        let recent = manager.recentAnalyses(limit: 3)

        #expect(recent.count == 3)
        #expect(recent[0].name == "Analysis 10") // Most recent
        #expect(recent[1].name == "Analysis 9")
        #expect(recent[2].name == "Analysis 8")
    }

    // MARK: - Statistics Tests

    @Test func testHistoryManager_AverageUniformityScore_CalculatesCorrectly() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        manager.saveAnalysis(createTestResults(uniformityScore: 80.0))
        manager.saveAnalysis(createTestResults(uniformityScore: 70.0))
        manager.saveAnalysis(createTestResults(uniformityScore: 90.0))

        let average = manager.averageUniformityScore

        #expect(abs(average - 80.0) < 0.1) // (80+70+90)/3 = 80
    }

    @Test func testHistoryManager_AverageUniformityScore_EmptyReturnsZero() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        #expect(manager.averageUniformityScore == 0.0)
    }

    @Test func testHistoryManager_BestResult_ReturnsHighestScore() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        manager.saveAnalysis(createTestResults(uniformityScore: 70.0), name: "Good")
        manager.saveAnalysis(createTestResults(uniformityScore: 95.0), name: "Best")
        manager.saveAnalysis(createTestResults(uniformityScore: 80.0), name: "Better")

        let best = manager.bestResult

        #expect(best?.name == "Best")
        #expect(best?.results.uniformityScore == 95.0)
    }

    @Test func testHistoryManager_BestResult_EmptyReturnsNil() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        #expect(manager.bestResult == nil)
    }

    // MARK: - Persistence Tests

    @Test func testHistoryManager_PersistenceRoundTrip_PreservesData() async {
        // Save analysis
        let manager1 = CoffeeAnalysisHistoryManager()
        manager1.clearAllAnalyses()

        let originalResults = createTestResults(
            uniformityScore: 85.5,
            averageSize: 550.0,
            grindType: .espresso
        )
        manager1.saveAnalysis(originalResults, name: "Persistence Test")

        // Wait a moment for persistence
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Create new manager (should load from UserDefaults)
        let manager2 = CoffeeAnalysisHistoryManager()

        // Verify data loaded
        let loaded = manager2.savedAnalyses.first { $0.name == "Persistence Test" }
        #expect(loaded != nil)
        #expect(loaded?.results.uniformityScore == 85.5)
        #expect(loaded?.results.averageSize == 550.0)
        #expect(loaded?.results.grindType == .espresso)
    }

    @Test func testHistoryManager_SaveWithTastingNotes_Persists() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        let tastingNotes = TastingNotes(
            brewMethod: .pourOver,
            overallRating: 5,
            tastingTags: ["Bright", "Fruity"],
            extractionNotes: "Perfect",
            extractionTime: nil,
            waterTemp: 95.0,
            doseIn: 20.0,
            yieldOut: 300.0
        )

        var results = createTestResults()
        results = CoffeeAnalysisResults(
            uniformityScore: results.uniformityScore,
            averageSize: results.averageSize,
            medianSize: results.medianSize,
            standardDeviation: results.standardDeviation,
            finesPercentage: results.finesPercentage,
            bouldersPercentage: results.bouldersPercentage,
            particleCount: results.particleCount,
            particles: results.particles,
            confidence: results.confidence,
            image: results.image,
            processedImage: results.processedImage,
            grindType: results.grindType,
            timestamp: results.timestamp,
            calibrationFactor: results.calibrationFactor,
            tastingNotes: tastingNotes
        )

        manager.saveAnalysis(results, name: "With Tasting Notes")

        // Wait for persistence
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Load in new manager
        let manager2 = CoffeeAnalysisHistoryManager()
        let loaded = manager2.savedAnalyses.first { $0.name == "With Tasting Notes" }

        #expect(loaded?.results.tastingNotes != nil)
        #expect(loaded?.results.tastingNotes?.brewMethod == .pourOver)
        #expect(loaded?.results.tastingNotes?.overallRating == 5)
        #expect(loaded?.results.tastingNotes?.tastingTags.contains("Bright") == true)
    }

    // MARK: - Edge Cases

    @Test func testHistoryManager_SaveWithNotes_PreservesNotes() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        let results = createTestResults()
        manager.saveAnalysis(results, name: "Test", notes: "These are my notes")

        let saved = manager.savedAnalyses.first
        #expect(saved?.notes == "These are my notes")
    }

    @Test func testHistoryManager_DeleteInvalidIndex_DoesNotCrash() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        manager.saveAnalysis(createTestResults())

        // Try to delete invalid index
        manager.deleteAnalysis(at: 999)

        // Should not crash, and analysis should still exist
        #expect(manager.totalAnalyses == 1)
    }

    @Test func testHistoryManager_UpdateNonexistentId_DoesNotCrash() async {
        let manager = CoffeeAnalysisHistoryManager()
        manager.clearAllAnalyses()

        let fakeId = UUID()
        let tastingNotes = TastingNotes(
            brewMethod: .espresso,
            overallRating: 4,
            tastingTags: [],
            extractionNotes: nil,
            extractionTime: nil,
            waterTemp: nil,
            doseIn: nil,
            yieldOut: nil
        )

        // Should not crash
        manager.updateAnalysisTastingNotes(analysisId: fakeId, tastingNotes: tastingNotes)
    }

    // MARK: - Helper Methods

    private func createTestResults(
        uniformityScore: Double = 75.0,
        averageSize: Double = 500.0,
        grindType: CoffeeGrindType = .filter
    ) -> CoffeeAnalysisResults {
        return CoffeeAnalysisResults(
            uniformityScore: uniformityScore,
            averageSize: averageSize,
            medianSize: averageSize,
            standardDeviation: 80.0,
            finesPercentage: 15.0,
            bouldersPercentage: 5.0,
            particleCount: 100,
            particles: [],
            confidence: 75.0,
            image: nil,
            processedImage: nil,
            grindType: grindType,
            timestamp: Date(),
            calibrationFactor: 150.0
        )
    }

    private func createTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        return renderer.image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }
}
