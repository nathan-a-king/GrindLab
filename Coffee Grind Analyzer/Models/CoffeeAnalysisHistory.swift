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
            savedAnalyses = storableAnalyses.compactMap { storable in
                // Ensure we have valid size distribution data
                let distribution = storable.sizeDistribution.isEmpty ?
                    generateDefaultSizeDistribution(finesPercentage: storable.finesPercentage, bouldersPercentage: storable.bouldersPercentage) :
                    storable.sizeDistribution
                
                print("📊 Loading analysis '\(storable.name)': distribution has \(distribution.count) categories")
                
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
                    sizeDistribution: distribution // Use validated distribution
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
            // If loading fails, try to load legacy format or clear corrupted data
            userDefaults.removeObject(forKey: savedAnalysesKey)
        }
    }
    
    // Generate a reasonable size distribution when missing
    private func generateDefaultSizeDistribution(finesPercentage: Double, bouldersPercentage: Double) -> [String: Double] {
        let mediumPercentage = max(0, 100 - finesPercentage - bouldersPercentage)
        let finePercentage = mediumPercentage * 0.3 // 30% of remaining
        let adjustedMedium = mediumPercentage * 0.7 // 70% of remaining
        let coarsePercentage = 0.0 // Minimal coarse if not specified
        
        return [
            "Fines (<400μm)": finesPercentage,
            "Fine (400-600μm)": finePercentage,
            "Medium (600-1000μm)": adjustedMedium,
            "Coarse (1000-1400μm)": coarsePercentage,
            "Boulders (>1400μm)": bouldersPercentage
        ]
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
    
    // Custom decoder to handle legacy data without sizeDistribution
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        grindType = try container.decode(CoffeeGrindType.self, forKey: .grindType)
        uniformityScore = try container.decode(Double.self, forKey: .uniformityScore)
        averageSize = try container.decode(Double.self, forKey: .averageSize)
        medianSize = try container.decode(Double.self, forKey: .medianSize)
        standardDeviation = try container.decode(Double.self, forKey: .standardDeviation)
        finesPercentage = try container.decode(Double.self, forKey: .finesPercentage)
        bouldersPercentage = try container.decode(Double.self, forKey: .bouldersPercentage)
        particleCount = try container.decode(Int.self, forKey: .particleCount)
        confidence = try container.decode(Double.self, forKey: .confidence)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        savedDate = try container.decode(Date.self, forKey: .savedDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        // Try to decode sizeDistribution, fallback to empty if not present (legacy data)
        sizeDistribution = try container.decodeIfPresent([String: Double].self, forKey: .sizeDistribution) ?? [:]
    }
    
    // Standard initializer for encoding
    init(id: UUID, name: String, grindType: CoffeeGrindType, uniformityScore: Double, averageSize: Double,
         medianSize: Double, standardDeviation: Double, finesPercentage: Double, bouldersPercentage: Double,
         particleCount: Int, confidence: Double, timestamp: Date, savedDate: Date, notes: String?,
         sizeDistribution: [String: Double]) {
        self.id = id
        self.name = name
        self.grindType = grindType
        self.uniformityScore = uniformityScore
        self.averageSize = averageSize
        self.medianSize = medianSize
        self.standardDeviation = standardDeviation
        self.finesPercentage = finesPercentage
        self.bouldersPercentage = bouldersPercentage
        self.particleCount = particleCount
        self.confidence = confidence
        self.timestamp = timestamp
        self.savedDate = savedDate
        self.notes = notes
        self.sizeDistribution = sizeDistribution
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, grindType, uniformityScore, averageSize, medianSize, standardDeviation
        case finesPercentage, bouldersPercentage, particleCount, confidence, timestamp, savedDate, notes, sizeDistribution
    }
}
