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
    
    private var chartData: [(analysis: SavedCoffeeAnalysis, color: Color, data: [(microns: Double, percentage: Double, label: String)])] {
        return comparison.analyses.enumerated().map { index, analysis in
            let color = Color.comparisonColor(for: index)
            let data = prepareChartDataForAnalysis(analysis)
            print("📊 Chart data for \(analysis.name): \(data.count) points, color index: \(index)")
            return (analysis: analysis, color: color, data: data)
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
            // Dark brown background to match other views
            Color.brown.opacity(0.7)
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
        ComparisonCard(title: "Analysis Comparison") {
            VStack(spacing: 16) {
                HStack {
                    Text("Comparing \(comparison.analyses.count) Analyses")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Baseline: \(comparison.baseline.name)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                
                // Since we only compare 2 analyses now, give each one more space
                HStack(spacing: 16) {
                    ForEach(Array(comparison.analyses.enumerated()), id: \.element.id) { index, analysis in
                        analysisChip(analysis: analysis, color: Color.comparisonColor(for: index), isBaseline: index == comparison.baselineIndex)
                    }
                }
            }
        }
    }
    
    private func analysisChip(analysis: SavedCoffeeAnalysis, color: Color, isBaseline: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                
                if isBaseline {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
                
                Spacer()
            }
            
            Text(analysis.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            HStack {
                Text("\(Int(analysis.results.uniformityScore))%")
                    .font(.caption2)
                    .foregroundColor(analysis.results.uniformityColor)
                    .fontWeight(.bold)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var twoWayComparison: some View {
        let baseline = comparison.baseline
        let comparison = comparison.comparisons.first!
        
        return ComparisonCard(title: "Head-to-Head Comparison") {
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
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
            
            // Scores below in a horizontal layout
            HStack(spacing: 16) {
                // Baseline score
                VStack(spacing: 4) {
                    Text("Baseline")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
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
                        .foregroundColor(.white.opacity(0.7))
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
                .foregroundColor(.white)
            
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
                    .foregroundColor(.white)
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
        .background(Color.brown.opacity(0.7))
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
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
    
    private var tastingNotesComparison: some View {
        ComparisonCard(title: "Tasting Notes Comparison") {
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
                    .foregroundColor(.white)
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
                            .foregroundColor(.white.opacity(0.8))
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
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
            } else {
                Text("No tasting notes")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
            }
        }
        .frame(width: 140, alignment: .leading)
        .padding(12)
        .background(Color.brown.opacity(0.7))
        .cornerRadius(8)
    }
    
    // MARK: - Overlay Charts
    
    private var overlayCharts: some View {
        ZStack {
            // Dark brown background to match other views
            Color.brown.opacity(0.7)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    if #available(iOS 16.0, *) {
                        distributionOverlayChart
                        metricsComparisonChart
                    } else {
                        ComparisonCard(title: "Charts") {
                            Text("Charts require iOS 16+")
                                .foregroundColor(.white.opacity(0.7))
                                .padding()
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    @available(iOS 16.0, *)
    private var distributionOverlayChart: some View {
        ComparisonCard(title: "Particle Size Distribution Comparison") {
            
            Chart {
                ForEach(Array(chartData.enumerated()), id: \.offset) { index, analysisData in
                    ForEach(analysisData.data, id: \.label) { dataPoint in
                        LineMark(
                            x: .value("Size (μm)", dataPoint.microns),
                            y: .value("Percentage", dataPoint.percentage / 100.0),
                            series: .value("Analysis", "\(analysisData.analysis.name)-\(analysisData.analysis.id)")
                        )
                        .foregroundStyle(analysisData.color)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Size (μm)", dataPoint.microns),
                            yStart: .value("Start", 0.0),
                            yEnd: .value("Percentage", dataPoint.percentage / 100.0),
                            series: .value("Analysis", "\(analysisData.analysis.name)-\(analysisData.analysis.id)")
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [analysisData.color.opacity(0.25), analysisData.color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .frame(height: 250)
            .chartXScale(domain: determineComparisonXDomain())
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let microns = value.as(Double.self) {
                            Text("\(Int(microns))μm")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartLegend(position: .bottom)
            .chartYAxisLabel("Percentage (%)")
            .chartXAxisLabel("Particle Size (μm)")
            
            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                    HStack {
                        Rectangle()
                            .fill(data.color)
                            .frame(width: 12, height: 3)
                            .cornerRadius(2)
                        
                        Text(data.analysis.name)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    @available(iOS 16.0, *)
    private var metricsComparisonChart: some View {
        ComparisonCard(title: "Key Metrics Comparison") {
            
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
    
    // Use EXACT same logic as ResultsView.prepareChartData()
    private func prepareChartDataForAnalysis(_ analysis: SavedCoffeeAnalysis) -> [(microns: Double, percentage: Double, label: String)] {
        let results = analysis.results
        
        // First priority: Use EXACT saved chart data points if available
        if let savedChartData = results.chartDataPoints, !savedChartData.isEmpty {
            let allPoints = savedChartData.map { point in
                (microns: point.microns, percentage: point.percentage, label: point.label)
            }
            print("📊 Data for \(analysis.name): min=\(allPoints.map{$0.microns}.min() ?? 0)μm, max=\(allPoints.map{$0.microns}.max() ?? 0)μm")
            print("📊 First 5 points: \(allPoints.prefix(5).map { "\($0.microns)μm:\($0.percentage)%" }.joined(separator: ", "))")
            return allPoints
        }
        // Fallback to other methods...
        else if let granularDist = results.granularDistribution, !granularDist.isEmpty {
            return granularDist.compactMap { label, percentage -> (microns: Double, percentage: Double, label: String)? in
                guard percentage > 0 else { return nil }
                
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
                        return nil
                    }
                    midpoint = (lowerBound + upperBound) / 2
                } else if components.count == 1, let singleValue = Double(components[0]) {
                    midpoint = singleValue
                } else {
                    return nil
                }
                
                return (microns: midpoint, percentage: percentage, label: label)
            }.sorted { $0.microns < $1.microns }
        }
        // Final fallback to categorical
        else {
            let grindCategories = results.grindType.distributionCategories
            return results.sizeDistribution.compactMap { key, value -> (microns: Double, percentage: Double, label: String)? in
                guard let categoryIndex = grindCategories.firstIndex(where: { $0.label == key }) else { return nil }
                
                let category = grindCategories[categoryIndex]
                let midpoint = category.range.upperBound == Double.infinity ? 
                    category.range.lowerBound + 200 : 
                    (category.range.lowerBound + category.range.upperBound) / 2
                
                return (microns: midpoint, percentage: value, label: key)
            }.sorted { $0.microns < $1.microns }
        }
    }
    
    private func determineComparisonXDomain() -> ClosedRange<Double> {
        // Find the overall min and max across all analyses
        let allDataPoints = chartData.flatMap { $0.data }
        guard !allDataPoints.isEmpty else { return 0...2000 }
        
        let minMicrons = allDataPoints.map { $0.microns }.min() ?? 0
        let maxMicrons = allDataPoints.map { $0.microns }.max() ?? 2000
        
        // Add 15% padding on each side for better visualization
        let range = maxMicrons - minMicrons
        let padding = max(range * 0.15, 100) // At least 100μm padding
        let lowerBound = max(0, minMicrons - padding)
        let upperBound = maxMicrons + padding
        
        print("📊 Comparison chart domain: \(String(format: "%.0f", lowerBound))-\(String(format: "%.0f", upperBound))μm (data range: \(String(format: "%.0f", minMicrons))-\(String(format: "%.0f", maxMicrons)))")
        
        return lowerBound...upperBound
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
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color.brown.opacity(0.7))
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
                .foregroundColor(.white)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(String(format: unit.isEmpty ? "%.0f" : "%.1f", comparison) + unit)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
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

// MARK: - Comparison Card Component

struct ComparisonCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
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
            calibrationFactor: 150.0
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
            calibrationFactor: 150.0
        )
        
        let analysis1 = SavedCoffeeAnalysis(
            name: "Morning Filter",
            results: sampleResults1,
            savedDate: Date().addingTimeInterval(-86400),
            notes: nil,
            originalImagePath: nil,
            processedImagePath: nil
        )
        
        let analysis2 = SavedCoffeeAnalysis(
            name: "Afternoon Filter",
            results: sampleResults2,
            savedDate: Date(),
            notes: nil,
            originalImagePath: nil,
            processedImagePath: nil
        )
        
        let comparison = AnalysisComparison(analyses: [analysis1, analysis2])
        
        return ComparisonView(comparison: comparison)
    }
}
#endif
