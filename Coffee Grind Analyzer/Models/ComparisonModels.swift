//
//  ComparisonModels.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/22/25.
//

import SwiftUI
import Foundation
import Combine

// MARK: - Analysis Comparison Data Structure

struct AnalysisComparison {
    let analyses: [SavedCoffeeAnalysis]
    let baselineIndex: Int // Which analysis to use as baseline for differences
    
    init(analyses: [SavedCoffeeAnalysis], baselineIndex: Int = 0) {
        self.analyses = analyses
        self.baselineIndex = min(baselineIndex, analyses.count - 1)
    }
    
    var baseline: SavedCoffeeAnalysis {
        return analyses[baselineIndex]
    }
    
    var comparisons: [SavedCoffeeAnalysis] {
        return Array(analyses.enumerated().compactMap { index, analysis in
            index != baselineIndex ? analysis : nil
        })
    }
}

// MARK: - Comparison Metric (Handles difference calculations and formatting)

struct ComparisonMetric {
    let name: String
    let baselineValue: Double
    let comparisonValue: Double
    let unit: String
    let isHigherBetter: Bool
    
    var difference: Double {
        return comparisonValue - baselineValue
    }
    
    var percentChange: Double {
        guard baselineValue != 0 else { return 0 }
        return (difference / baselineValue) * 100
    }
    
    var isImprovement: Bool {
        return isHigherBetter ? difference > 0 : difference < 0
    }
    
    var changeIcon: String {
        if abs(difference) < 0.1 { return "minus" }
        return isImprovement ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }
    
    var changeColor: Color {
        if abs(difference) < 0.1 { return .gray }
        return isImprovement ? .green : .red
    }
    
    var formattedDifference: String {
        let prefix = difference > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", difference))\(unit)"
    }
    
    var formattedPercentChange: String {
        let prefix = percentChange > 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", percentChange))%"
    }
}

// MARK: - Comparison Manager (Manages selection state and comparison logic)

class ComparisonManager: ObservableObject {
    @Published var selectedAnalyses: Set<UUID> = []
    @Published var showingComparison = false
    
    private let maxComparisons = 4 // Limit for readability
    
    func toggleSelection(_ analysisId: UUID) {
        if selectedAnalyses.contains(analysisId) {
            selectedAnalyses.remove(analysisId)
        } else if selectedAnalyses.count < maxComparisons {
            selectedAnalyses.insert(analysisId)
        }
    }
    
    func isSelected(_ analysisId: UUID) -> Bool {
        return selectedAnalyses.contains(analysisId)
    }
    
    func canSelect(_ analysisId: UUID) -> Bool {
        return selectedAnalyses.contains(analysisId) || selectedAnalyses.count < maxComparisons
    }
    
    var canStartComparison: Bool {
        return selectedAnalyses.count >= 2
    }
    
    func clearSelection() {
        selectedAnalyses.removeAll()
    }
    
    func startComparison() {
        guard canStartComparison else { return }
        showingComparison = true
    }
    
    func createComparison(from historyManager: CoffeeAnalysisHistoryManager) -> AnalysisComparison? {
        let analyses = historyManager.savedAnalyses.filter { selectedAnalyses.contains($0.id) }
        guard analyses.count >= 2 else { return nil }
        
        // Sort by date (newest first) for consistent baseline
        let sortedAnalyses = analyses.sorted { $0.savedDate > $1.savedDate }
        return AnalysisComparison(analyses: sortedAnalyses, baselineIndex: 0)
    }
}

// MARK: - Chart Data Models

struct ComparisonChartData {
    let analysisName: String
    let analysisId: UUID
    let color: Color
    let distributionData: [ChartDataPoint]
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let category: String
        let shortCategory: String
        let percentage: Double
        let order: Int
    }
    
    init(analysis: SavedCoffeeAnalysis, color: Color) {
        self.analysisName = analysis.name
        self.analysisId = analysis.id
        self.color = color
        
        // Use the dynamic categories from the grind type
        let grindCategories = analysis.results.grindType.distributionCategories
        
        self.distributionData = analysis.results.sizeDistribution.compactMap { key, value in
            // Find the matching category to get the correct order
            guard let categoryIndex = grindCategories.firstIndex(where: { $0.label == key }) else { return nil }
            
            // Extract short name from the label (everything before the parentheses)
            let shortName = key.components(separatedBy: " (").first ?? key
            
            return ChartDataPoint(
                category: key,
                shortCategory: shortName,
                percentage: value,
                order: categoryIndex
            )
        }.sorted { $0.order < $1.order }
    }
}

// MARK: - Predefined Colors

extension Color {
    static let comparisonColors: [Color] = [
        .blue,
        .orange,
        .green,
        .purple,
        .pink,
        .teal,
        .indigo,
        .brown
    ]
    
    static func comparisonColor(for index: Int) -> Color {
        return comparisonColors[index % comparisonColors.count]
    }
}
