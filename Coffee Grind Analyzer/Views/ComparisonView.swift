//
//  ComparisonView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/22/25.
//

import SwiftUI
import Charts

struct ComparisonView: View {
    let comparison: AnalysisComparison
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var selectedMetric: String = "uniformityScore"
    
    private var chartData: [ComparisonChartData] {
        return comparison.analyses.enumerated().map { index, analysis in
            ComparisonChartData(analysis: analysis, color: Color.comparisonColor(for: index))
        }
    }
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Side-by-side comparison
                sideBySide
                    .tabItem {
                        Image(systemName: "square.split.2x1")
                        Text("Side-by-Side")
                    }
                    .tag(0)
                
                // Overlay charts
                overlayCharts
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Charts")
                    }
                    .tag(1)
                
                // Detailed metrics
                detailedMetrics
                    .tabItem {
                        Image(systemName: "list.bullet.rectangle")
                        Text("Metrics")
                    }
                    .tag(2)
            }
            .navigationTitle("Compare Analyses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section("Baseline") {
                            ForEach(Array(comparison.analyses.enumerated()), id: \.element.id) { index, analysis in
                                Button(action: {
                                    // Would need to recreate comparison with new baseline
                                }) {
                                    HStack {
                                        if index == comparison.baselineIndex {
                                            Image(systemName: "checkmark")
                                        }
                                        Text(analysis.name)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
    }
    
    // MARK: - Side-by-Side View
    
    private var sideBySide: some View {
        ZStack {
            // Modern gradient background matching history view
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.97, green: 0.96, blue: 0.95), // Light cream
                    Color(red: 0.94, green: 0.92, blue: 0.90)  // Warm gray
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    comparisonSummaryCard
                    
                    if comparison.analyses.count == 2 {
                        twoWayComparison
                    } else {
                        multiWayComparison
                    }
                    
                    tastingNotesComparison
                }
                .padding()
            }
        }
    }
    
    private var comparisonSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Comparing \(comparison.analyses.count) Analyses")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("Baseline: \(comparison.baseline.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Since we only compare 2 analyses now, give each one more space
            HStack(spacing: 16) {
                ForEach(Array(comparison.analyses.enumerated()), id: \.element.id) { index, analysis in
                    analysisChip(analysis: analysis, color: Color.comparisonColor(for: index), isBaseline: index == comparison.baselineIndex)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
        )
    }
    
    private func analysisChip(analysis: SavedCoffeeAnalysis, color: Color, isBaseline: Bool) -> some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                if isBaseline {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            
            Text(analysis.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text("\(Int(analysis.results.uniformityScore))%")
                .font(.caption2)
                .foregroundColor(analysis.results.uniformityColor)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var twoWayComparison: some View {
        let baseline = comparison.baseline
        let comparison = comparison.comparisons.first!
        
        return VStack(spacing: 16) {
            Text("Head-to-Head Comparison")
                .font(.headline)
            
            VStack(spacing: 12) {
                comparisonRow(
                    label: "Uniformity Score",
                    baseline: baseline.results.uniformityScore,
                    comparison: comparison.results.uniformityScore,
                    unit: "%",
                    isHigherBetter: true
                )
                
                comparisonRow(
                    label: "Average Size",
                    baseline: baseline.results.averageSize,
                    comparison: comparison.results.averageSize,
                    unit: "μm",
                    isHigherBetter: false // Depends on target, but neutral for now
                )
                
                comparisonRow(
                    label: "Fines Percentage",
                    baseline: baseline.results.finesPercentage,
                    comparison: comparison.results.finesPercentage,
                    unit: "%",
                    isHigherBetter: false
                )
                
                comparisonRow(
                    label: "Standard Deviation",
                    baseline: baseline.results.standardDeviation,
                    comparison: comparison.results.standardDeviation,
                    unit: "μm",
                    isHigherBetter: false
                )
                
                comparisonRow(
                    label: "Confidence",
                    baseline: baseline.results.confidence,
                    comparison: comparison.results.confidence,
                    unit: "%",
                    isHigherBetter: true
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    
    private func comparisonRow(label: String, baseline: Double, comparison: Double, unit: String, isHigherBetter: Bool) -> some View {
        let metric = ComparisonMetric(
            name: label,
            baselineValue: baseline,
            comparisonValue: comparison,
            unit: unit,
            isHigherBetter: isHigherBetter
        )
        
        return VStack(spacing: 12) {
            // Title at the top
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
            
            // Scores below in a horizontal layout
            HStack(spacing: 16) {
                // Baseline score
                VStack(spacing: 4) {
                    Text("Baseline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", baseline) + unit)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                
                // Arrow and change indicator
                VStack(spacing: 4) {
                    Image(systemName: metric.changeIcon)
                        .font(.title3)
                        .foregroundColor(metric.changeColor)
                    
                    Text(metric.formattedDifference)
                        .font(.caption)
                        .foregroundColor(metric.changeColor)
                        .fontWeight(.semibold)
                }
                .frame(width: 60)
                
                // Comparison score
                VStack(spacing: 4) {
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", comparison) + unit)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var multiWayComparison: some View {
        VStack(spacing: 16) {
            Text("Multi-Way Comparison")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(Array(comparison.analyses.enumerated()), id: \.element.id) { index, analysis in
                    analysisMetricCard(
                        analysis: analysis,
                        color: Color.comparisonColor(for: index),
                        isBaseline: index == comparison.baselineIndex
                    )
                }
            }
        }
    }
    
    private func analysisMetricCard(analysis: SavedCoffeeAnalysis, color: Color, isBaseline: Bool) -> some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(analysis.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if isBaseline {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                metricItem(label: "Uniformity", value: "\(Int(analysis.results.uniformityScore))%", color: analysis.results.uniformityColor)
                metricItem(label: "Avg Size", value: String(format: "%.0f", analysis.results.averageSize) + "μm", color: .blue)
                metricItem(label: "Fines", value: String(format: "%.1f", analysis.results.finesPercentage) + "%", color: .orange)
                metricItem(label: "Confidence", value: String(format: "%.0f", analysis.results.confidence) + "%", color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color, lineWidth: isBaseline ? 3 : 1)
        )
    }
    
    private func metricItem(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    private var tastingNotesComparison: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tasting Notes Comparison")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(comparison.analyses.enumerated()), id: \.element.id) { index, analysis in
                        tastingNotesCard(
                            analysis: analysis,
                            color: Color.comparisonColor(for: index)
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func tastingNotesCard(analysis: SavedCoffeeAnalysis, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(analysis.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            if let tastingNotes = analysis.results.tastingNotes {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: tastingNotes.brewMethod.icon)
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text(tastingNotes.brewMethod.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 2) {
                        ForEach(1...tastingNotes.overallRating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        ForEach(tastingNotes.overallRating + 1...5, id: \.self) { _ in
                            Image(systemName: "star")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if !tastingNotes.tastingTags.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(tastingNotes.tastingTags.prefix(3)), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(color.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            if tastingNotes.tastingTags.count > 3 {
                                Text("+\(tastingNotes.tastingTags.count - 3) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("No tasting notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .frame(width: 140, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Overlay Charts
    
    private var overlayCharts: some View {
        ZStack {
            // Modern gradient background matching history view
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.97, green: 0.96, blue: 0.95), // Light cream
                    Color(red: 0.94, green: 0.92, blue: 0.90)  // Warm gray
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    if #available(iOS 16.0, *) {
                        distributionOverlayChart
                        metricsComparisonChart
                    } else {
                        Text("Charts require iOS 16+")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
    }
    
    @available(iOS 16.0, *)
    private var distributionOverlayChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Particle Size Distribution Comparison")
                .font(.headline)
            
            Chart {
                ForEach(chartData, id: \.analysisId) { analysisData in
                    ForEach(analysisData.distributionData) { dataPoint in
                        LineMark(
                            x: .value("Category", dataPoint.shortCategory),
                            y: .value("Percentage", dataPoint.percentage),
                            series: .value("Analysis", analysisData.analysisName)
                        )
                        .foregroundStyle(analysisData.color)
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        .symbolSize(60)
                        
                        AreaMark(
                            x: .value("Category", dataPoint.shortCategory),
                            y: .value("Percentage", dataPoint.percentage),
                            series: .value("Analysis", analysisData.analysisName)
                        )
                        .foregroundStyle(analysisData.color.opacity(0.2))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .frame(height: 250)
            .chartLegend(position: .bottom)
            .chartYAxisLabel("Percentage (%)")
            .chartXAxisLabel("Particle Size Category")
            
            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(chartData.enumerated()), id: \.element.analysisId) { index, data in
                    HStack {
                        Rectangle()
                            .fill(data.color)
                            .frame(width: 12, height: 3)
                            .cornerRadius(2)
                        
                        Text(data.analysisName)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
        )
    }
    
    @available(iOS 16.0, *)
    private var metricsComparisonChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics Comparison")
                .font(.headline)
            
            Picker("Metric", selection: $selectedMetric) {
                Text("Uniformity Score").tag("uniformityScore")
                Text("Average Size").tag("averageSize")
                Text("Fines Percentage").tag("finesPercentage")
                Text("Standard Deviation").tag("standardDeviation")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Chart(Array(comparison.analyses.enumerated()), id: \.element.id) { index, analysis in
                BarMark(
                    x: .value("Analysis", analysis.name),
                    y: .value("Value", getMetricValue(analysis.results, metric: selectedMetric))
                )
                .foregroundStyle(Color.comparisonColor(for: index))
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartYAxisLabel(getMetricUnit(selectedMetric))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 2)
        )
    }
    
    private func getMetricValue(_ results: CoffeeAnalysisResults, metric: String) -> Double {
        switch metric {
        case "uniformityScore":
            return results.uniformityScore
        case "averageSize":
            return results.averageSize
        case "finesPercentage":
            return results.finesPercentage
        case "standardDeviation":
            return results.standardDeviation
        default:
            return 0
        }
    }
    
    private func getMetricUnit(_ metric: String) -> String {
        switch metric {
        case "uniformityScore":
            return "Score (%)"
        case "averageSize":
            return "Size (μm)"
        case "finesPercentage":
            return "Fines (%)"
        case "standardDeviation":
            return "Std Dev (μm)"
        default:
            return ""
        }
    }
    
    // MARK: - Detailed Metrics
    
    private var detailedMetrics: some View {
        List {
            ForEach(comparison.comparisons, id: \.id) { comparisonAnalysis in
                Section(header: Text("vs. \(comparisonAnalysis.name)")) {
                    metricComparisonRows(baseline: comparison.baseline, comparison: comparisonAnalysis)
                }
            }
        }
    }
    
    private func metricComparisonRows(baseline: SavedCoffeeAnalysis, comparison: SavedCoffeeAnalysis) -> some View {
        Group {
            MetricComparisonRow(
                label: "Uniformity Score",
                baseline: baseline.results.uniformityScore,
                comparison: comparison.results.uniformityScore,
                unit: "%",
                isHigherBetter: true
            )
            
            MetricComparisonRow(
                label: "Average Size",
                baseline: baseline.results.averageSize,
                comparison: comparison.results.averageSize,
                unit: "μm",
                isHigherBetter: false
            )
            
            MetricComparisonRow(
                label: "Median Size",
                baseline: baseline.results.medianSize,
                comparison: comparison.results.medianSize,
                unit: "μm",
                isHigherBetter: false
            )
            
            MetricComparisonRow(
                label: "Standard Deviation",
                baseline: baseline.results.standardDeviation,
                comparison: comparison.results.standardDeviation,
                unit: "μm",
                isHigherBetter: false
            )
            
            MetricComparisonRow(
                label: "Fines Percentage",
                baseline: baseline.results.finesPercentage,
                comparison: comparison.results.finesPercentage,
                unit: "%",
                isHigherBetter: false
            )
            
            MetricComparisonRow(
                label: "Boulders Percentage",
                baseline: baseline.results.bouldersPercentage,
                comparison: comparison.results.bouldersPercentage,
                unit: "%",
                isHigherBetter: false
            )
            
            MetricComparisonRow(
                label: "Particle Count",
                baseline: Double(baseline.results.particleCount),
                comparison: Double(comparison.results.particleCount),
                unit: "",
                isHigherBetter: true
            )
            
            MetricComparisonRow(
                label: "Confidence",
                baseline: baseline.results.confidence,
                comparison: comparison.results.confidence,
                unit: "%",
                isHigherBetter: true
            )
        }
    }
}

// MARK: - Metric Comparison Row

struct MetricComparisonRow: View {
    let label: String
    let baseline: Double
    let comparison: Double
    let unit: String
    let isHigherBetter: Bool
    
    private var metric: ComparisonMetric {
        return ComparisonMetric(
            name: label,
            baselineValue: baseline,
            comparisonValue: comparison,
            unit: unit,
            isHigherBetter: isHigherBetter
        )
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(String(format: unit.isEmpty ? "%.0f" : "%.1f", comparison) + unit)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: metric.changeIcon)
                        .font(.caption)
                        .foregroundColor(metric.changeColor)
                }
                
                Text(metric.formattedDifference)
                    .font(.caption)
                    .foregroundColor(metric.changeColor)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleResults1 = CoffeeAnalysisResults(
            uniformityScore: 82.5,
            averageSize: 850.0,
            medianSize: 820.0,
            standardDeviation: 145.0,
            finesPercentage: 12.3,
            bouldersPercentage: 8.7,
            particleCount: 287,
            particles: [],
            confidence: 89.2,
            image: nil,
            processedImage: nil,
            grindType: .filter,
            timestamp: Date(),
            sizeDistribution: ["Fines (<400μm)": 12.3, "Medium (600-1000μm)": 75.0, "Boulders (>1400μm)": 8.7],
            calibrationInfo: .defaultPreview
        )
        
        let sampleResults2 = CoffeeAnalysisResults(
            uniformityScore: 87.1,
            averageSize: 820.0,
            medianSize: 800.0,
            standardDeviation: 120.0,
            finesPercentage: 10.1,
            bouldersPercentage: 6.2,
            particleCount: 324,
            particles: [],
            confidence: 92.4,
            image: nil,
            processedImage: nil,
            grindType: .filter,
            timestamp: Date(),
            sizeDistribution: ["Fines (<400μm)": 10.1, "Medium (600-1000μm)": 78.5, "Boulders (>1400μm)": 6.2],
            calibrationInfo: .defaultPreview
        )
        
        let analysis1 = SavedCoffeeAnalysis(
            name: "Morning Filter",
            results: sampleResults1,
            savedDate: Date().addingTimeInterval(-86400),
            notes: nil
        )
        
        let analysis2 = SavedCoffeeAnalysis(
            name: "Afternoon Filter",
            results: sampleResults2,
            savedDate: Date(),
            notes: nil
        )
        
        let comparison = AnalysisComparison(analyses: [analysis1, analysis2])
        
        return ComparisonView(comparison: comparison)
    }
}
#endif
