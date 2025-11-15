//
//  CoffeeAnalysisHistory.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import Foundation
import UIKit
import Combine
import OSLog

private let historyManagerLogger = Logger(subsystem: "com.nateking.GrindLab", category: "HistoryManager")

// MARK: - Saved Analysis Model

struct SavedCoffeeAnalysis: Identifiable {
    let id: UUID
    let name: String
    let results: CoffeeAnalysisResults
    let savedDate: Date
    let notes: String?
    let originalImagePath: String?
    let processedImagePath: String?

    init(id: UUID = UUID(),
         name: String,
         results: CoffeeAnalysisResults,
         savedDate: Date = Date(),
         notes: String? = nil,
         originalImagePath: String? = nil,
         processedImagePath: String? = nil) {
        self.id = id
        self.name = name
        self.results = results
        self.savedDate = savedDate
        self.notes = notes
        self.originalImagePath = originalImagePath
        self.processedImagePath = processedImagePath
    }
}

// MARK: - History Manager

class CoffeeAnalysisHistoryManager: ObservableObject {
    @Published private(set) var savedAnalyses: [SavedCoffeeAnalysis] = []

    private let maxStoredResults = 50 // Limit to prevent storage bloat
    private let persistenceQueue = DispatchQueue(label: "com.nateking.GrindLab.historyPersistence", qos: .utility)
    private let repository: CoffeeAnalysisRepository
    private let initialLoadGroup = DispatchGroup()

    init(repository: CoffeeAnalysisRepository = CoffeeAnalysisRepository()) {
        self.repository = repository
        initialLoadGroup.enter()
        loadSavedAnalyses()
    }

    // MARK: - Image Access

    func loadImage(from path: String) -> UIImage? {
        repository.loadImage(named: path)
    }

    // MARK: - Save Analysis

    func saveAnalysis(_ results: CoffeeAnalysisResults, name: String? = nil, notes: String? = nil) {
        let analysisName = name ?? generateDefaultName(for: results)
        let identifier = UUID().uuidString
        let resultsCopy = results
        let notesCopy = notes

        persistenceQueue.async { [weak self] in
            guard let self else { return }

            self.initialLoadGroup.wait()

            let originalImagePath = resultsCopy.image.flatMap { self.repository.storeImage($0, identifier: identifier, suffix: "original") }
            let processedImagePath = resultsCopy.processedImage.flatMap { self.repository.storeImage($0, identifier: identifier, suffix: "processed") }

            let savedAnalysis = SavedCoffeeAnalysis(
                name: analysisName,
                results: resultsCopy,
                savedDate: Date(),
                notes: notesCopy,
                originalImagePath: originalImagePath,
                processedImagePath: processedImagePath
            )

            DispatchQueue.main.async { [weak self] in
                self?.insertAnalysis(savedAnalysis)
            }
        }
    }

    private func insertAnalysis(_ analysis: SavedCoffeeAnalysis) {
        savedAnalyses.insert(analysis, at: 0)
        var removed: [SavedCoffeeAnalysis] = []
        if savedAnalyses.count > maxStoredResults {
            removed = Array(savedAnalyses.suffix(from: maxStoredResults))
            savedAnalyses = Array(savedAnalyses.prefix(maxStoredResults))
        }
        persistAnalyses(removedAnalyses: removed)
    }

    // MARK: - Update Existing Analysis

    func updateAnalysisTastingNotes(analysisId: UUID, tastingNotes: TastingNotes?) {
        guard let index = savedAnalyses.firstIndex(where: { $0.id == analysisId }) else { return }

        let oldAnalysis = savedAnalyses[index]
        let oldResults = oldAnalysis.results
        let updatedResults = CoffeeAnalysisResults(
            uniformityScore: oldResults.uniformityScore,
            averageSize: oldResults.averageSize,
            medianSize: oldResults.medianSize,
            standardDeviation: oldResults.standardDeviation,
            finesPercentage: oldResults.finesPercentage,
            bouldersPercentage: oldResults.bouldersPercentage,
            particleCount: oldResults.particleCount,
            particles: oldResults.particles,
            confidence: oldResults.confidence,
            image: oldResults.image,
            processedImage: oldResults.processedImage,
            grindType: oldResults.grindType,
            timestamp: oldResults.timestamp,
            sizeDistribution: oldResults.sizeDistribution,
            calibrationFactor: oldResults.calibrationFactor,
            tastingNotes: tastingNotes,
            storedMinParticleSize: oldResults.minParticleSize,
            storedMaxParticleSize: oldResults.maxParticleSize,
            granularDistribution: oldResults.granularDistribution,
            chartDataPoints: oldResults.chartDataPoints
        )

        let updatedAnalysis = SavedCoffeeAnalysis(
            id: oldAnalysis.id,
            name: oldAnalysis.name,
            results: updatedResults,
            savedDate: oldAnalysis.savedDate,
            notes: oldAnalysis.notes,
            originalImagePath: oldAnalysis.originalImagePath,
            processedImagePath: oldAnalysis.processedImagePath
        )

        savedAnalyses[index] = updatedAnalysis
        persistAnalyses()

        historyManagerLogger.info("Updated tasting notes for analysis: \(updatedAnalysis.name, privacy: .public)")
    }

    // MARK: - Delete Analysis

    func deleteAnalysis(at index: Int) {
        guard savedAnalyses.indices.contains(index) else { return }
        let removed = savedAnalyses.remove(at: index)
        persistAnalyses(removedAnalyses: [removed])
    }

    func deleteAnalysis(withId id: UUID) {
        guard let index = savedAnalyses.firstIndex(where: { $0.id == id }) else { return }
        let removed = savedAnalyses.remove(at: index)
        persistAnalyses(removedAnalyses: [removed])
    }

    // MARK: - Clear All

    func clearAllAnalyses() {
        let removed = savedAnalyses
        savedAnalyses.removeAll()
        persistAnalyses(removedAnalyses: removed)
    }

    // MARK: - Search and Filter

    func analysesForGrindType(_ grindType: CoffeeGrindType) -> [SavedCoffeeAnalysis] {
        return savedAnalyses.filter { $0.results.grindType == grindType }
    }

    func recentAnalyses(limit: Int = 5) -> [SavedCoffeeAnalysis] {
        return Array(savedAnalyses.prefix(limit))
    }

    // MARK: - Statistics

    var totalAnalyses: Int {
        return savedAnalyses.count
    }

    var averageUniformityScore: Double {
        guard !savedAnalyses.isEmpty else { return 0 }
        let total = savedAnalyses.reduce(0) { $0 + $1.results.uniformityScore }
        return total / Double(savedAnalyses.count)
    }

    var bestResult: SavedCoffeeAnalysis? {
        return savedAnalyses.max { $0.results.uniformityScore < $1.results.uniformityScore }
    }

    // MARK: - Private Methods

    private func generateDefaultName(for results: CoffeeAnalysisResults) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let dateString = formatter.string(from: results.timestamp)

        let score = Int(results.uniformityScore)
        return "\(results.grindType.displayName) - \(score)% (\(dateString))"
    }

    private func persistAnalyses(removedAnalyses: [SavedCoffeeAnalysis] = []) {
        let analysesSnapshot = savedAnalyses
        let imagesToRemove = Set(removedAnalyses.flatMap { [$0.originalImagePath, $0.processedImagePath] }.compactMap { $0 })

        persistenceQueue.async { [weak self] in
            guard let self else { return }
            self.initialLoadGroup.wait()
            do {
                let result = try self.repository.persistAnalyses(analysesSnapshot)
                if !imagesToRemove.isEmpty {
                    self.repository.deleteImages(named: imagesToRemove)
                }
                self.repository.cleanupOrphanedImages(validFilenames: result.referencedImageFilenames)
                historyManagerLogger.info("Persisted \(analysesSnapshot.count, privacy: .public) analyses to storage")
            } catch {
                historyManagerLogger.error("Failed to persist analyses: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func loadSavedAnalyses() {
        persistenceQueue.async { [weak self] in
            guard let self else { return }
            let result = self.repository.loadAnalyses()
            DispatchQueue.main.async { [weak self] in
                self?.savedAnalyses = result.analyses
                self?.initialLoadGroup.leave()
            }
            self.repository.cleanupOrphanedImages(validFilenames: result.referencedImageFilenames)
        }
    }

    @MainActor
    func waitForPersistence() async {
        await withCheckedContinuation { continuation in
            initialLoadGroup.notify(queue: persistenceQueue) {
                continuation.resume()
            }
        }
    }
}
