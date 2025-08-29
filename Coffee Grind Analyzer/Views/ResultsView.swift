//
//  ResultsView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI
import Charts

struct ResultsView: View {
    let baseResults: CoffeeAnalysisResults
    let isFromHistory: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var historyManager: CoffeeAnalysisHistoryManager
    
    @State private var selectedTab = 0
    @State private var showingImageComparison = false
    @State private var showingSaveDialog = false
    @State private var saveName = ""
    @State private var saveNotes = ""
    @State private var saveSuccess = false
    @State private var chartRefreshTrigger = false
    @State private var showingEditTastingNotes = false
    
    init(results: CoffeeAnalysisResults, isFromHistory: Bool = false) {
        self.baseResults = results
        self.isFromHistory = isFromHistory
    }
    
    // Computed property to get current results with updated tasting notes
    private var results: CoffeeAnalysisResults {
        if isFromHistory,
           let savedAnalysis = historyManager.savedAnalyses.first(where: { $0.results.timestamp == baseResults.timestamp }) {
            return savedAnalysis.results
        }
        return baseResults
    }
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                overviewTab
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Overview")
                    }
                    .tag(0)
                
                detailsTab
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Details")
                    }
                    .tag(1)
                
                distributionTab
                    .tabItem {
                        Image(systemName: "chart.pie.fill")
                        Text("Distribution")
                    }
                    .tag(2)
                
                imagesTab
                    .tabItem {
                        Image(systemName: "photo.fill")
                        Text("Images")
                    }
                    .tag(3)
            }
            .navigationTitle("Analysis Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !isFromHistory {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingSaveDialog = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingEditTastingNotes = true }) {
                            Image(systemName: results.tastingNotes != nil ? "star.fill" : "star")
                                .foregroundColor(results.tastingNotes != nil ? .black : .gray)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingImageComparison) {
            ImageComparisonView(results: results)
        }
        .sheet(isPresented: $showingSaveDialog) {
            SaveAnalysisDialog(
                results: results,
                saveName: $saveName,
                saveNotes: $saveNotes,
                onSave: { name, notes, tastingNotes in
                    // Create new results with tasting notes
                    let updatedResults = CoffeeAnalysisResults(
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
                        sizeDistribution: results.sizeDistribution,
                        calibrationInfo: results.calibrationInfo,
                        tastingNotes: tastingNotes
                    )
                    
                    historyManager.saveAnalysis(updatedResults, name: name, notes: notes)
                    saveSuccess = true
                    showingSaveDialog = false
                }
            )
        }
        .sheet(isPresented: $showingEditTastingNotes) {
            if isFromHistory, let savedAnalysis = historyManager.savedAnalyses.first(where: { $0.results.timestamp == results.timestamp }) {
                EditTastingNotesDialog(
                    savedAnalysis: savedAnalysis,
                    onSave: { _, tastingNotes in
                        historyManager.updateAnalysisTastingNotes(
                            analysisId: savedAnalysis.id,
                            tastingNotes: tastingNotes
                        )
                    }
                )
            }
        }
        .alert("Analysis Saved!", isPresented: $saveSuccess) {
            Button("OK") { }
        } message: {
            Text("Your coffee grind analysis has been saved successfully.")
        }
        .onAppear {
            print("📝 ResultsView body appeared - isFromHistory: \(isFromHistory)")
            
            // Force refresh for first-load issues
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                chartRefreshTrigger.toggle()
                print("🔄 Chart refresh triggered")
            }
            
            // Debug logging
            print("📝 ResultsView data check:")
            print("   - From History: \(isFromHistory)")
            let isInRange = results.grindType.targetSizeMicrons.contains(results.averageSize)
            print("   - Size Match: \(isInRange ? "In Range" : "Out of Range")")
            print("   - Distribution keys: \(results.sizeDistribution.keys.sorted())")
            print("   - Distribution values: \(results.sizeDistribution.values.map { String(format: "%.1f", $0) })")
        }
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard
                    .onAppear { print("📊 Summary card appeared") }
                
                metricsGrid
                    .onAppear { print("📊 Metrics grid appeared") }
                
                
                // Add tasting notes display if available
                if let tastingNotes = results.tastingNotes {
                    TastingNotesDisplayView(tastingNotes: tastingNotes)
                        .onAppear { print("📊 Tasting notes section appeared") }
                        .id(tastingNotes) // Force refresh when tasting notes change
                }
                
            }
            .padding()
            .onAppear {
                print("📊 Overview tab content appeared")
            }
        }
        .background(Color.brown.opacity(0.25))
        .onAppear {
            print("📊 Overview tab ScrollView appeared")
        }
    }
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text(results.grindType.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Analyzed \(results.timestamp, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack {
                    let isInRange = results.grindType.targetSizeMicrons.contains(results.averageSize)
                    Text(isInRange ? "In Range" : "Out of Range")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isInRange ? .green : .red)
                    
                    Text("Size Match")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            let isInRange = results.grindType.targetSizeMicrons.contains(results.averageSize)
            ProgressView(value: isInRange ? 1.0 : 0.0)
                .tint(isInRange ? .green : .red)
        }
        .padding()
        .background(Color.brown.opacity(0.25))
        .cornerRadius(12)
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            metricCard(
                title: "Average Size",
                value: String(format: "%.1f μm", results.averageSize),
                subtitle: "Target: \(results.grindType.targetSizeRange)",
                color: .brown,
                icon: "ruler"
            )
            
            metricCard(
                title: "Particle Count",
                value: "\(results.particleCount)",
                subtitle: "Detected particles",
                color: .brown,
                icon: "number"
            )
            
            metricCard(
                title: "Fines",
                value: String(format: "%.1f%%", results.finesPercentage),
                subtitle: "<400 μm particles",
                color: .brown,
                icon: "sparkles"
            )
            
            metricCard(
                title: "Confidence",
                value: String(format: "%.0f%%", results.confidence),
                subtitle: "Analysis reliability",
                color: .brown,
                icon: "checkmark.seal"
            )
        }
    }
    
    private func metricCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.brown.opacity(0.25))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    
    
    // MARK: - Details Tab
    
    private var detailsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                detailSection("Particle Statistics") {
                    VStack(spacing: 8) {
                        DetailRow(label: "Average Size", value: String(format: "%.1f μm", results.averageSize))
                        DetailRow(label: "Median Size", value: String(format: "%.1f μm", results.medianSize))
                        DetailRow(label: "Standard Deviation", value: String(format: "%.1f μm", results.standardDeviation))
                        DetailRow(label: "Coefficient of Variation", value: String(format: "%.1f%%", (results.standardDeviation / results.averageSize) * 100))
                    }
                }
                
                detailSection("Size Distribution") {
                    VStack(spacing: 8) {
                        DetailRow(label: "Fines (<400μm)", value: String(format: "%.1f%%", results.finesPercentage))
                        DetailRow(label: "Boulders (>1400μm)", value: String(format: "%.1f%%", results.bouldersPercentage))
                        DetailRow(label: "Medium (400-1400μm)", value: String(format: "%.1f%%", 100 - results.finesPercentage - results.bouldersPercentage))
                    }
                }
                
                detailSection("Target Ranges") {
                    VStack(spacing: 8) {
                        DetailRow(label: "Target Size", value: results.grindType.targetSizeRange)
                        DetailRow(label: "Ideal Fines", value: "\(Int(results.grindType.idealFinesPercentage.lowerBound))-\(Int(results.grindType.idealFinesPercentage.upperBound))%")
                        
                        let isInRange = results.grindType.targetSizeMicrons.contains(results.averageSize)
                        DetailRow(
                            label: "Size Match",
                            value: isInRange ? "✓ In Range" : "✗ Out of Range",
                            valueColor: isInRange ? .green : .red
                        )
                    }
                }
                
                detailSection("Analysis Info") {
                    VStack(spacing: 8) {
                        DetailRow(label: "Particles Detected", value: "\(results.particleCount)")
                        DetailRow(label: "Confidence Level", value: String(format: "%.0f%%", results.confidence))
                        DetailRow(label: "Analysis Time", value: results.timestamp.formatted(date: .omitted, time: .shortened))
                        DetailRow(label: "Grind Type", value: results.grindType.displayName)
                    }
                }
            }
            .padding()
        }
        .background(Color.brown.opacity(0.25))
    }
    
    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            content()
        }
    }
    
    // MARK: - Distribution Tab
    
    private var distributionTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                if #available(iOS 16.0, *) {
                    distributionChart
                } else {
                    // Fallback for older iOS versions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Particle Size Distribution")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Chart view requires iOS 16+")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(Color.brown.opacity(0.25))
                    .cornerRadius(12)
                }
                
                sizeDistributionList
            }
            .padding()
        }
        .background(Color.brown.opacity(0.25))
    }
    
    @available(iOS 16.0, *)
    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Particle Size Distribution")
                .font(.headline)
                .foregroundColor(.white)
            
            // Prepare more granular data for smoother chart
            let chartData = prepareChartData()
            
            // Debug logging
            let _ = print("🎨 Rendering chart with \(chartData.count) data points")
            
            if chartData.isEmpty {
                Text("No distribution data available")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(height: 200)
            } else {
                Chart(chartData, id: \.label) { dataPoint in
                    LineMark(
                        x: .value("Size (μm)", dataPoint.microns),
                        y: .value("Percentage", dataPoint.percentage / 100.0)
                    )
                    .foregroundStyle(.white)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Size (μm)", dataPoint.microns),
                        y: .value("Percentage", dataPoint.percentage / 100.0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200)
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
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text("\(Int(doubleValue * 100))%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .onAppear {
                    // Force a small delay to ensure Charts framework is ready
                    print("📊 Chart appeared for analysis")
                }
                .id(chartRefreshTrigger) // Force re-render when trigger changes
            }
        }
        .padding()
        .background(Color.brown.opacity(0.25))
        .cornerRadius(12)
    }
    
    private func categoryShortName(_ category: String) -> String {
        // Extract just the first word or two from the category label
        // e.g., "Extra Fine (<150μm)" -> "Extra Fine"
        // e.g., "Target (600-900μm)" -> "Target"
        if let openParen = category.firstIndex(of: "(") {
            let shortName = String(category[..<openParen]).trimmingCharacters(in: .whitespaces)
            // Further shorten if needed
            if shortName.count > 12 {
                // Take just the first word for really long names
                return shortName.split(separator: " ").first.map(String.init) ?? shortName
            }
            return shortName
        }
        return category
    }
    
    private func prepareChartData() -> [(microns: Double, percentage: Double, label: String)] {
        if !results.particles.isEmpty {
            // Use actual particle data for more accurate distribution
            let sizeRanges = createGranularSizeRanges()
            return sizeRanges.compactMap { range in
                let particlesInRange = results.particles.filter { particle in
                    particle.size >= range.lowerBound && particle.size < range.upperBound
                }
                let percentage = (Double(particlesInRange.count) / Double(results.particles.count)) * 100
                let midpoint = range.upperBound == Double.infinity ? 
                    range.lowerBound + 200 : 
                    (range.lowerBound + range.upperBound) / 2
                
                return (microns: midpoint, percentage: percentage, label: "\(Int(range.lowerBound))-\(range.upperBound == Double.infinity ? "∞" : "\(Int(range.upperBound))")μm")
            }
        } else {
            // Fallback: interpolate between existing categories for smoother curve
            let categories = results.grindType.distributionCategories
            var interpolatedData: [(microns: Double, percentage: Double, label: String)] = []
            
            for (index, category) in categories.enumerated() {
                guard let percentage = results.sizeDistribution[category.label] else { continue }
                
                let micronValue: Double
                if category.range.upperBound == Double.infinity {
                    micronValue = category.range.lowerBound + 200
                } else {
                    micronValue = (category.range.lowerBound + category.range.upperBound) / 2
                }
                
                interpolatedData.append((microns: micronValue, percentage: percentage, label: category.label))
                
                // Add interpolated points between categories (except for the last one)
                if index < categories.count - 1 {
                    let nextCategory = categories[index + 1]
                    guard let nextPercentage = results.sizeDistribution[nextCategory.label] else { continue }
                    
                    let nextMicronValue: Double
                    if nextCategory.range.upperBound == Double.infinity {
                        nextMicronValue = nextCategory.range.lowerBound + 200
                    } else {
                        nextMicronValue = (nextCategory.range.lowerBound + nextCategory.range.upperBound) / 2
                    }
                    
                    // Add 2 interpolated points between each pair
                    for i in 1...2 {
                        let t = Double(i) / 3.0 // divide into thirds
                        let interpMicrons = micronValue + (nextMicronValue - micronValue) * t
                        let interpPercentage = percentage + (nextPercentage - percentage) * t
                        
                        interpolatedData.append((
                            microns: interpMicrons, 
                            percentage: interpPercentage, 
                            label: "interp_\(index)_\(i)"
                        ))
                    }
                }
            }
            
            return interpolatedData.sorted { $0.microns < $1.microns }
        }
    }
    
    private func createGranularSizeRanges() -> [Range<Double>] {
        // Create 15-20 size ranges for smoother distribution curve
        return [
            0..<100,     // Ultra fine
            100..<200,   // Extra fine
            200..<300,   // Fine
            300..<400,   // Fine-medium
            400..<500,   // Medium-fine
            500..<600,   // Medium-fine+
            600..<700,   // Medium
            700..<800,   // Medium+
            800..<900,   // Medium-coarse
            900..<1000,  // Medium-coarse+
            1000..<1100, // Coarse
            1100..<1200, // Coarse+
            1200..<1300, // Extra coarse
            1300..<1400, // Extra coarse+
            1400..<1500, // Very coarse
            1500..<1700, // Very coarse+
            1700..<2000, // Ultra coarse
            2000..<Double.infinity  // Boulders
        ]
    }
    
    private func colorForCategory(_ category: String) -> Color {
        // Check if this is the target category (contains "Target")
        if category.contains("Target") {
            return .green
        }
        
        // Get the index of this category in the distribution
        let categories = results.grindType.distributionCategories.map { $0.label }
        guard let index = categories.firstIndex(of: category) else { return .gray }
        
        // Color based on position relative to target
        switch index {
        case 0:
            return .red      // Finest category
        case 1:
            return .orange   // Fine category
        case 2:
            return category.contains("Target") ? .green : .yellow  // Middle/Target
        case 3:
            return .blue     // Coarse category
        case 4:
            return .purple   // Coarsest category
        default:
            return .gray
        }
    }
    
    private var sizeDistributionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Distribution Legend")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Add target range indicator
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("\(results.grindType.targetSizeRange)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            // Get categories from grind type
            let categories = results.grindType.distributionCategories
            
            ForEach(categories, id: \.label) { category in
                if let percentage = results.sizeDistribution[category.label] {
                    HStack {
                        // Category name without range (it's shown separately)
                        Text(categoryShortName(category.label))
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(minWidth: 80, alignment: .leading)
                        
                        // Range
                        Text(formatRange(category.range))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(minWidth: 100, alignment: .leading)
                        
                        Spacer()
                        
                        // Percentage with bar
                        HStack(spacing: 4) {
                            // Mini bar chart
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(width: geometry.size.width * (percentage / 100))
                            }
                            .frame(width: 40, height: 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                            
                            Text(String(format: "%.1f%%", percentage))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(minWidth: 45, alignment: .trailing)
                        }
                    }
                }
            }
            
            // Add note about target range concentration
            if let targetCategory = categories.first(where: { $0.label.contains("Target") }),
               let targetPercentage = results.sizeDistribution[targetCategory.label] {
                HStack {
                    Image(systemName: targetPercentage > 30 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(targetPercentage > 30 ? .green : .orange)
                        .font(.caption)
                    
                    Text(targetPercentage > 30 ? "Good concentration in target range" : "Low concentration in target range")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.brown.opacity(0.25))
        .cornerRadius(12)
    }
    
    private func formatRange(_ range: Range<Double>) -> String {
        if range.upperBound == Double.infinity {
            return ">\(Int(range.lowerBound))μm"
        } else if range.lowerBound == 0 {
            return "<\(Int(range.upperBound))μm"
        } else {
            return "\(Int(range.lowerBound))-\(Int(range.upperBound))μm"
        }
    }
    
    // MARK: - Images Tab
    
    private var imagesTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let originalImage = results.image {
                    imageSection(
                        title: "Original Image",
                        image: originalImage,
                        subtitle: "Captured photo"
                    )
                }
                
                if let processedImage = results.processedImage {
                    imageSection(
                        title: "Processed Image",
                        image: processedImage,
                        subtitle: "With particle detection overlay"
                    )
                }
                
                Button("Compare Images") {
                    showingImageComparison = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(Color.brown.opacity(0.25))
    }
    
    private func imageSection(title: String, image: UIImage, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(12)
                .shadow(radius: 4)
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.brown.opacity(0.25))
        .cornerRadius(8)
    }
}

// MARK: - Image Comparison View

struct ImageComparisonView: View {
    let results: CoffeeAnalysisResults
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingOriginal = true
    
    var body: some View {
        NavigationView {
            VStack {
                if let originalImage = results.image,
                   let processedImage = results.processedImage {
                    
                    Picker("Image Type", selection: $showingOriginal) {
                        Text("Original").tag(true)
                        Text("Processed").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: showingOriginal ? originalImage : processedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .background(Color.black)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if showingOriginal {
                            Text("Original captured image showing the coffee grind sample")
                        } else {
                            Text("Processed image with detected particles highlighted in color:")
                            
                            HStack(spacing: 16) {
                                legendItem(color: .red, label: "Fines (<400μm)")
                                legendItem(color: .yellow, label: "Fine (400-800μm)")
                                legendItem(color: .green, label: "Medium (800-1200μm)")
                                legendItem(color: .blue, label: "Coarse (>1200μm)")
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                }
            }
            .navigationTitle("Image Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let results: CoffeeAnalysisResults
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let shareText = generateShareText()
        var items: [Any] = [shareText]
        
        if let image = results.image {
            items.append(image)
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    
    private func generateShareText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        return """
        Coffee Grind Analysis Results
        
        Grind Type: \(results.grindType.displayName)
        Date: \(formatter.string(from: results.timestamp))
        
        📊 Key Metrics:
        • Size Match: \(results.grindType.targetSizeMicrons.contains(results.averageSize) ? "In Range" : "Out of Range")
        • Average Size: \(String(format: "%.1f", results.averageSize))μm
        • Particles Detected: \(results.particleCount)
        • Fines: \(String(format: "%.1f", results.finesPercentage))%
        • Confidence: \(Int(results.confidence))%
        
        🎯 Target Range: \(results.grindType.targetSizeRange)
        
        #CoffeeGrindAnalyzer #Coffee #Analysis
        """
    }
}

// MARK: - Save Analysis Dialog

struct SaveAnalysisDialog: View {
    let results: CoffeeAnalysisResults
    @Binding var saveName: String
    @Binding var saveNotes: String
    let onSave: (String?, String?, TastingNotes?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var brewMethod: TastingNotes.BrewMethod = .espresso
    @State private var overallRating: Int = 3
    @State private var selectedTags: Set<String> = []
    @State private var extractionNotes: String = ""
    @State private var extractionTime: String = ""
    @State private var waterTemp: String = ""
    @State private var doseIn: String = ""
    @State private var yieldOut: String = ""
    @State private var includeTastingNotes: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Analysis Info") {
                    HStack {
                        Text("Grind Type")
                        Spacer()
                        Text(results.grindType.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Size Match")
                        Spacer()
                        let isInRange = results.grindType.targetSizeMicrons.contains(results.averageSize)
                        Text(isInRange ? "In Range" : "Out of Range")
                            .foregroundColor(isInRange ? .green : .red)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(results.timestamp, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Save Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Auto-generated if empty", text: $saveName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Add notes about grinder, beans, etc.", text: $saveNotes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                }
                
                Section {
                    Toggle("Add Tasting Notes", isOn: $includeTastingNotes)
                        .font(.subheadline)
                } header: {
                    Text("Brewing Results")
                } footer: {
                    Text("Track how this grind performed when brewing")
                }
                
                if includeTastingNotes {
                    tastingNotesSection
                }
            }
            .navigationTitle("Save Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAnalysis()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            setupDefaults()
        }
    }
    
    private var tastingNotesSection: some View {
        Group {
            Section("Brew Method") {
                Picker("Method", selection: $brewMethod) {
                    ForEach(TastingNotes.BrewMethod.allCases, id: \.self) { method in
                        HStack {
                            Image(systemName: method.icon)
                            Text(method.rawValue)
                        }.tag(method)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Section("Overall Rating") {
                HStack {
                    Text("How was it?")
                    Spacer()
                    StarRatingView(rating: $overallRating)
                }
            }
            
            Section("Tasting Profile") {
                TastingTagsView(selectedTags: $selectedTags)
            }
            
            Section("Brewing Details") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Extraction Time")
                        Spacer()
                        TextField("30s", text: $extractionTime)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Water Temp")
                        Spacer()
                        TextField("93°C", text: $waterTemp)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Dose In")
                        Spacer()
                        TextField("18g", text: $doseIn)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Yield Out")
                        Spacer()
                        TextField("36g", text: $yieldOut)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                }
            }
            
            Section("Extraction Notes") {
                TextField("How did it taste? Any issues?", text: $extractionNotes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(2...4)
            }
        }
    }
    
    private func setupDefaults() {
        if saveName.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let dateString = formatter.string(from: results.timestamp)
            saveName = "\(results.grindType.displayName) - \(dateString)"
        }
        
        // Set default brew method based on grind type
        switch results.grindType {
        case .espresso:
            brewMethod = .espresso
        case .filter:
            brewMethod = .pourOver
        case .frenchPress:
            brewMethod = .frenchPress
        case .coldBrew:
            brewMethod = .coldBrew
        }
    }
    
    private func saveAnalysis() {
        let name = saveName.isEmpty ? nil : saveName
        let notes = saveNotes.isEmpty ? nil : saveNotes
        
        var tastingNotes: TastingNotes? = nil
        
        if includeTastingNotes {
            tastingNotes = TastingNotes(
                brewMethod: brewMethod,
                overallRating: overallRating,
                tastingTags: Array(selectedTags),
                extractionNotes: extractionNotes.isEmpty ? nil : extractionNotes,
                extractionTime: Double(extractionTime),
                waterTemp: Double(waterTemp),
                doseIn: Double(doseIn),
                yieldOut: Double(yieldOut)
            )
        }
        
        onSave(name, notes, tastingNotes)
    }
}

// MARK: - Preview

#if DEBUG
struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleResults = CoffeeAnalysisResults(
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
            sizeDistribution: ["Fines (<400μm)": 12.3, "Fine (400-600μm)": 25.1, "Medium (600-1000μm)": 45.2, "Coarse (1000-1400μm)": 12.7, "Boulders (>1400μm)": 4.7],
            calibrationInfo: .defaultPreview
        )
        
        return ResultsView(results: sampleResults)
    }
}
#endif
