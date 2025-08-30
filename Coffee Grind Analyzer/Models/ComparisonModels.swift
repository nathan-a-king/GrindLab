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
    
    private let maxComparisons = 2 // Limit to 2 for better comparison
    
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
        
        // Use granular data like individual charts for smooth curves
        if let savedChartData = analysis.results.chartDataPoints, !savedChartData.isEmpty {
            // Use exact saved chart data (best option)
            print("📊 ComparisonChartData: Using chartDataPoints for \(analysis.name) with \(savedChartData.count) points")
            
            let processedData = savedChartData.compactMap { point -> ChartDataPoint? in
                guard point.percentage > 0 else { return nil }
                return ChartDataPoint(
                    category: point.label,
                    shortCategory: "\(Int(point.microns))",
                    percentage: point.percentage,
                    order: Int(point.microns) // Sort by actual micron value
                )
            }.sorted { (a, b) in a.order < b.order }
            
            // Debug the actual data ranges
            let percentages = processedData.map { $0.percentage }
            let minPercentage = percentages.min() ?? 0
            let maxPercentage = percentages.max() ?? 0
            print("📊 Data range: microns \(processedData.first?.order ?? 0)-\(processedData.last?.order ?? 0), percentages \(minPercentage)-\(maxPercentage)")
            print("📊 First 3 points: \(processedData.prefix(3).map { "(\($0.order)μm: \($0.percentage)%)" }.joined(separator: ", "))")
            
            // Generate intermediate points for smoother curves
            self.distributionData = Self.generateSmoothCurvePoints(from: processedData)
        } else if let granularDist = analysis.results.granularDistribution, !granularDist.isEmpty {
            // Use granular distribution as fallback  
            print("📊 ComparisonChartData: Using granularDistribution for \(analysis.name) with \(granularDist.count) points")
            var dataPoints: [ChartDataPoint] = []
            for (label, percentage) in granularDist {
                guard percentage > 0 else { continue }
                
                // Parse micron value from label (e.g. "300-400μm" -> 350)
                let cleanedLabel = label.replacingOccurrences(of: "μm", with: "")
                let components = cleanedLabel.components(separatedBy: "-")
                
                let midpoint: Double
                if components.count == 2, let lowerBound = Double(components[0]) {
                    let upperBound: Double
                    if components[1] == "∞" {
                        upperBound = lowerBound + 200
                    } else if let upper = Double(components[1]) {
                        upperBound = upper
                    } else {
                        continue
                    }
                    midpoint = (lowerBound + upperBound) / 2
                } else if components.count == 1, let singleValue = Double(components[0]) {
                    // Handle single values like "150"
                    midpoint = singleValue
                } else {
                    continue
                }
                
                dataPoints.append(ChartDataPoint(
                    category: label,
                    shortCategory: "\(Int(midpoint))",
                    percentage: percentage,
                    order: Int(midpoint)
                ))
            }
            self.distributionData = dataPoints.sorted { $0.order < $1.order }
        } else {
            // Final fallback: use categorical data (least accurate)
            print("📊 ComparisonChartData: Using categorical sizeDistribution for \(analysis.name) with \(analysis.results.sizeDistribution.count) categories")
            let grindCategories = analysis.results.grindType.distributionCategories
            self.distributionData = analysis.results.sizeDistribution.compactMap { key, value in
                guard let categoryIndex = grindCategories.firstIndex(where: { $0.label == key }) else { return nil }
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
    
    // Generate intermediate points for smoother curve rendering
    private static func generateSmoothCurvePoints(from originalPoints: [ChartDataPoint]) -> [ChartDataPoint] {
        guard originalPoints.count >= 2 else { return originalPoints }
        
        var smoothPoints: [ChartDataPoint] = []
        
        for i in 0..<originalPoints.count {
            let currentPoint = originalPoints[i]
            smoothPoints.append(currentPoint)
            
            // Generate intermediate points between current and next point
            if i < originalPoints.count - 1 {
                let nextPoint = originalPoints[i + 1]
                let micronGap = nextPoint.order - currentPoint.order
                
                // Only interpolate if gap is larger than 50μm
                if micronGap > 50 {
                    let steps = min(Int(micronGap / 25), 6) // Max 6 intermediate points
                    
                    for step in 1..<steps {
                        let progress = Double(step) / Double(steps)
                        let interpMicrons = Double(currentPoint.order) + (Double(nextPoint.order - currentPoint.order) * progress)
                        let interpPercentage = currentPoint.percentage + ((nextPoint.percentage - currentPoint.percentage) * progress)
                        
                        smoothPoints.append(ChartDataPoint(
                            category: "\(Int(interpMicrons))μm",
                            shortCategory: "\(Int(interpMicrons))",
                            percentage: interpPercentage,
                            order: Int(interpMicrons)
                        ))
                    }
                }
            }
        }
        
        print("📊 Generated \(smoothPoints.count) smooth points from \(originalPoints.count) original points")
        return smoothPoints
    }
}

// MARK: - Predefined Colors

extension Color {
    static let comparisonColors: [Color] = [
        .white,
        .gray.opacity(0.7),  // Lighter gray for better visibility
        .white.opacity(0.8),
        .gray.opacity(0.6),
        .white.opacity(0.6),
        .gray.opacity(0.5),
        .white.opacity(0.4),
        .gray.opacity(0.3)
    ]
    
    static func comparisonColor(for index: Int) -> Color {
        return comparisonColors[index % comparisonColors.count]
    }
}
