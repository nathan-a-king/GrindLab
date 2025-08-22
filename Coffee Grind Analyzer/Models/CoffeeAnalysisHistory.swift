//
//  CoffeeAnalysisHistory.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import Foundation
import UIKit
import Combine

// MARK: - Saved Analysis Model

struct SavedCoffeeAnalysis: Identifiable {
    let id = UUID()
    let name: String
    let results: CoffeeAnalysisResults
    let savedDate: Date
    let notes: String?
}

// MARK: - History Manager

class CoffeeAnalysisHistoryManager: ObservableObject {
    @Published var savedAnalyses: [SavedCoffeeAnalysis] = []
    
    private let userDefaults = UserDefaults.standard
    private let savedAnalysesKey = "SavedCoffeeAnalyses"
    private let maxStoredResults = 50 // Limit to prevent storage bloat
    
    init() {
        loadSavedAnalyses()
    }
    
    // MARK: - Save Analysis
    
    func saveAnalysis(_ results: CoffeeAnalysisResults, name: String? = nil, notes: String? = nil) {
        let analysisName = name ?? generateDefaultName(for: results)
        
        let savedAnalysis = SavedCoffeeAnalysis(
            name: analysisName,
            results: results,
            savedDate: Date(),
            notes: notes
        )
        
        // Add to beginning of array (most recent first)
        savedAnalyses.insert(savedAnalysis, at: 0)
        
        // Limit storage to prevent bloat
        if savedAnalyses.count > maxStoredResults {
            savedAnalyses = Array(savedAnalyses.prefix(maxStoredResults))
        }
        
        persistAnalyses()
    }
    
    // MARK: - Delete Analysis
    
    func deleteAnalysis(at index: Int) {
        guard index < savedAnalyses.count else { return }
        savedAnalyses.remove(at: index)
        persistAnalyses()
    }
    
    func deleteAnalysis(withId id: UUID) {
        savedAnalyses.removeAll { $0.id == id }
        persistAnalyses()
    }
    
    // MARK: - Clear All
    
    func clearAllAnalyses() {
        savedAnalyses.removeAll()
        persistAnalyses()
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
    
    private func persistAnalyses() {
        do {
            // Convert to data that can be stored
            let analysesToStore = savedAnalyses.map { analysis in
                StorableAnalysis(
                    id: analysis.id,
                    name: analysis.name,
                    grindType: analysis.results.grindType,
                    uniformityScore: analysis.results.uniformityScore,
                    averageSize: analysis.results.averageSize,
                    medianSize: analysis.results.medianSize,
                    standardDeviation: analysis.results.standardDeviation,
                    finesPercentage: analysis.results.finesPercentage,
                    bouldersPercentage: analysis.results.bouldersPercentage,
                    particleCount: analysis.results.particleCount,
                    confidence: analysis.results.confidence,
                    timestamp: analysis.results.timestamp,
                    savedDate: analysis.savedDate,
                    notes: analysis.notes,
                    sizeDistribution: analysis.results.sizeDistribution // Save the distribution
                )
            }
            
            let data = try JSONEncoder().encode(analysesToStore)
            userDefaults.set(data, forKey: savedAnalysesKey)
            
            print("✅ Saved \(savedAnalyses.count) analyses to storage")
            
        } catch {
            print("❌ Error saving analyses: \(error)")
        }
    }
    
    private func loadSavedAnalyses() {
        guard let data = userDefaults.data(forKey: savedAnalysesKey) else {
            print("📭 No saved analyses found")
            return
        }
        
        do {
            let storableAnalyses = try JSONDecoder().decode([StorableAnalysis].self, from: data)
            
            // Convert back to full analysis objects
            savedAnalyses = storableAnalyses.map { storable in
                let results = CoffeeAnalysisResults(
                    uniformityScore: storable.uniformityScore,
                    averageSize: storable.averageSize,
                    medianSize: storable.medianSize,
                    standardDeviation: storable.standardDeviation,
                    finesPercentage: storable.finesPercentage,
                    bouldersPercentage: storable.bouldersPercentage,
                    particleCount: storable.particleCount,
                    particles: [], // Don't store individual particles for space
                    confidence: storable.confidence,
                    image: nil, // Don't store images for space
                    processedImage: nil,
                    grindType: storable.grindType,
                    timestamp: storable.timestamp,
                    sizeDistribution: storable.sizeDistribution // Use stored distribution
                )
                
                return SavedCoffeeAnalysis(
                    name: storable.name,
                    results: results,
                    savedDate: storable.savedDate,
                    notes: storable.notes
                )
            }
            
            print("✅ Loaded \(savedAnalyses.count) analyses from storage")
            
        } catch {
            print("❌ Error loading analyses: \(error)")
        }
    }
}

// MARK: - Storable Analysis (for UserDefaults)

private struct StorableAnalysis: Codable {
    let id: UUID
    let name: String
    let grindType: CoffeeGrindType
    let uniformityScore: Double
    let averageSize: Double
    let medianSize: Double
    let standardDeviation: Double
    let finesPercentage: Double
    let bouldersPercentage: Double
    let particleCount: Int
    let confidence: Double
    let timestamp: Date
    let savedDate: Date
    let notes: String?
    let sizeDistribution: [String: Double] // Add this for the graph
}
