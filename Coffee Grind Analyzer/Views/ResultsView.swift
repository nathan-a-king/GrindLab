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
    @Environment(\.tabSelection) private var tabSelection
    @EnvironmentObject private var historyManager: CoffeeAnalysisHistoryManager
    @EnvironmentObject private var brewState: BrewAppState
    
    @State private var selectedTab = 0
    @State private var showingImageComparison = false
    @State private var showingSaveDialog = false
    @State private var saveName = ""
    @State private var saveNotes = ""
    @State private var saveSuccess = false
    @State private var showingEditTastingNotes = false
    @State private var showingFlavorProfile = false
    @State private var flavorProfile: FlavorProfile?
    @State private var showingUnsavedWarning = false
    
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
                        calibrationFactor: results.calibrationFactor,
                        tastingNotes: tastingNotes,
                        storedMinParticleSize: results.minParticleSize,
                        storedMaxParticleSize: results.maxParticleSize,
                        granularDistribution: results.granularDistribution,
                        chartDataPoints: results.chartDataPoints
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
        .sheet(isPresented: $showingFlavorProfile) {
            FlavorProfileView(
                flavorProfile: $flavorProfile,
                analysisResults: results
            )
        }
        .alert("Analysis Saved!", isPresented: $saveSuccess) {
            Button("OK") { }
        } message: {
            Text("Your coffee grind analysis has been saved successfully.")
        }
        .alert("Save Analysis?", isPresented: $showingUnsavedWarning) {
            Button("Save First") {
                showingSaveDialog = true
            }
            Button("Continue Without Saving") {
                startBrewingWorkflow()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This analysis hasn't been saved yet. Save it now to keep track of your grind data and brewing results.")
        }
        .onAppear {
            print("📝 ResultsView body appeared - isFromHistory: \(isFromHistory)")
            
            // Debug logging for chart data
            
            // Debug logging
            print("📝 ResultsView data check:")
            print("   - From History: \(isFromHistory)")
            let isInRange = results.grindType.targetSizeMicrons.contains(results.medianSize)
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
                
                // Coffee improvement section
                coffeeImprovementSection
                
            }
            .padding()
            .onAppear {
                print("📊 Overview tab content appeared")
            }
        }
        .background(Color.brown.opacity(0.7))
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
                    let isInRange = results.grindType.targetSizeMicrons.contains(results.medianSize)
                    Text(isInRange ? "In Range" : "Out of Range")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isInRange ? .green : .red)
                    
                    Text("Size Match")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            let isInRange = results.grindType.targetSizeMicrons.contains(results.medianSize)
            ProgressView(value: isInRange ? 1.0 : 0.0)
                .tint(isInRange ? .green : .red)
        }
        .padding()
        .background(Color.brown.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            metricCard(
                title: "Particle Size",
                value: String(format: "%.0f μm", results.medianSize),
                subtitle: "Median (Avg: \(String(format: "%.0f", results.averageSize)) μm)",
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
        .background(Color.brown.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
        .shadow(radius: 4)
    }
    
    private var coffeeImprovementSection: some View {
        Button(action: {
            // Check if analysis is actually saved in history
            let isSaved = historyManager.savedAnalyses.contains(where: { $0.results.timestamp == results.timestamp })

            if !isSaved {
                // Show warning if analysis hasn't been saved
                showingUnsavedWarning = true
            } else {
                // Already saved, proceed directly
                startBrewingWorkflow()
            }
        }) {
            HStack {
                Spacer()
                Image(systemName: "timer")
                    .font(.title2)
                Text("Start Brewing")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .foregroundColor(.white)
            .padding()
        }
        .background(Color.brown.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
        .shadow(radius: 4)

        /* ORIGINAL SMART SUGGESTIONS SECTION - KEPT FOR REFERENCE
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Smart Suggestions")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }

            Text("Get personalized brewing recommendations based on your grind analysis and taste feedback")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 12) {
                Button("Start Brewing") {
                    startBrewingWorkflow()
                }
                .buttonStyle(ImprovementButtonStyle(color: .brown, isSecondary: false))

                Button("How did it taste?") {
                    showingFlavorProfile = true
                }
                .buttonStyle(ImprovementButtonStyle(color: .blue, isSecondary: false))
            }

            // Show quick grind assessment
            VStack(alignment: .leading, spacing: 4) {
                let isInRange = results.grindType.targetSizeMicrons.contains(results.medianSize)
                let uniformityGood = results.uniformityScore >= 60

                HStack {
                    Image(systemName: isInRange ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isInRange ? .green : .orange)
                    Text("Size: \(isInRange ? "Good" : "Needs adjustment")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }

                HStack {
                    Image(systemName: uniformityGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(uniformityGood ? .green : .orange)
                    Text("Uniformity: \(uniformityGood ? "Good" : "Could improve")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.brown.opacity(0.3), Color.brown.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        */
    }
    
    // MARK: - Details Tab
    
    private var detailsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                detailSection("Particle Statistics") {
                    VStack(spacing: 8) {
                        DetailRow(label: "Median Size", value: String(format: "%.1f μm", results.medianSize))
                        DetailRow(label: "Average Size", value: String(format: "%.1f μm", results.averageSize))
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
                        
                        let isInRange = results.grindType.targetSizeMicrons.contains(results.medianSize)
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
        .background(Color.brown.opacity(0.7))
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
                    .background(Color.brown.opacity(0.5))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                }
                
                sizeDistributionList
            }
            .padding()
        }
        .background(Color.brown.opacity(0.7))
    }
    
    @available(iOS 16.0, *)
    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Particle Size Distribution")
                .font(.headline)
                .foregroundColor(.white)
            
            // Prepare more granular data for smoother chart
            let chartData = prepareChartData()
            
            // Debug logging (moved to a separate function call)
            let _ = debugLogChartData(chartData)
            
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
                .chartXScale(domain: determineChartXDomain())
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
                .id("chart-\(results.timestamp.timeIntervalSince1970)-\(results.particles.count)") // Unique ID per analysis
            }
        }
        .padding()
        .background(Color.brown.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
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
        print("🔷 DEBUG prepareChartData START")
        print("🔷 Has chartDataPoints: \(results.chartDataPoints != nil)")
        print("🔷 chartDataPoints count: \(results.chartDataPoints?.count ?? 0)")
        print("🔷 Has particles: \(!results.particles.isEmpty)")
        print("🔷 Particles count: \(results.particles.count)")
        
        // First priority: Use EXACT saved chart data points if available
        if let savedChartData = results.chartDataPoints, !savedChartData.isEmpty {
            print("✅ DEBUG: Using EXACT saved chart data with \(savedChartData.count) points")
            let nonZero = savedChartData.filter { $0.percentage > 0 }
            print("✅ DEBUG: Non-zero points: \(nonZero.count)")
            for point in nonZero.prefix(5) {
                print("✅ DEBUG: Using saved point - \(point.label): \(String(format: "%.1f", point.percentage))% at \(String(format: "%.0f", point.microns))μm")
            }
            
            let returnData = savedChartData.map { point in
                (microns: point.microns, percentage: point.percentage, label: point.label)
            }
            print("🔷 DEBUG prepareChartData END - returning saved data")
            return returnData
        }
        // Second priority: Compute from actual particles if available
        else if !results.particles.isEmpty {
            print("📊 DEBUG: Computing chart data from \(results.particles.count) particles")
            let minSize = results.particles.map { $0.size }.min() ?? 0
            let maxSize = results.particles.map { $0.size }.max() ?? 0
            print("📊 DEBUG: Particle range: \(String(format: "%.1f", minSize))-\(String(format: "%.1f", maxSize))μm")
            // Use actual particle data for more accurate distribution
            let sizeRanges = createGranularSizeRanges()
            let computedData = sizeRanges.compactMap { range in
                let particlesInRange = results.particles.filter { particle in
                    particle.size >= range.lowerBound && particle.size < range.upperBound
                }
                let percentage = (Double(particlesInRange.count) / Double(results.particles.count)) * 100
                let midpoint = range.upperBound == Double.infinity ? 
                    range.lowerBound + 200 : 
                    (range.lowerBound + range.upperBound) / 2
                
                let label = "\(Int(range.lowerBound))-\(range.upperBound == Double.infinity ? "∞" : "\(Int(range.upperBound))")μm"
                if particlesInRange.count > 0 {
                    print("📊 DEBUG: Computing range \(label): \(particlesInRange.count) particles (\(String(format: "%.1f", percentage))%)")
                }
                return (microns: midpoint, percentage: percentage, label: label)
            }
            
            let nonZero = computedData.filter { $0.percentage > 0 }
            print("📊 DEBUG: Computed \(computedData.count) total points, \(nonZero.count) non-zero")
            for point in nonZero.prefix(5) {
                print("📊 DEBUG: Computed point - \(point.label): \(String(format: "%.1f", point.percentage))%")
            }
            print("🔷 DEBUG prepareChartData END - returning computed data")
            
            return computedData
        } else {
            // Third priority: Use stored granular distribution if available
            if let granularDist = results.granularDistribution, !granularDist.isEmpty {
                print("🎯 Using stored granular distribution with \(granularDist.count) data points")
                
                return granularDist.compactMap { (label: String, percentage: Double) -> (microns: Double, percentage: Double, label: String)? in
                    guard percentage > 0 else { return nil }
                    
                    // Parse the micron range from the label (e.g. "300-400μm" -> 350)
                    let components = label.replacingOccurrences(of: "μm", with: "").components(separatedBy: "-")
                    guard components.count == 2 else { return nil }
                    guard let lowerBound = Double(components[0]) else { return nil }
                    
                    let upperBound: Double
                    if components[1] == "∞" {
                        upperBound = lowerBound + 200
                    } else {
                        guard let upper = Double(components[1]) else { return nil }
                        upperBound = upper
                    }
                    
                    let midpoint = (lowerBound + upperBound) / 2
                    return (microns: midpoint, percentage: percentage, label: label)
                }.sorted { $0.microns < $1.microns }
            }
            // Fallback: Use granular size ranges like the original, but estimate percentages from saved data
            else if let minSize = results.minParticleSize, let maxSize = results.maxParticleSize, minSize < maxSize {
                print("🔄 Using stored particle range: \(String(format: "%.1f", minSize))-\(String(format: "%.1f", maxSize))μm for granular chart reconstruction")
                
                // Use the same granular ranges as the original
                let sizeRanges = createGranularSizeRanges()
                
                // Filter ranges to only those that overlap with our actual particle range
                let relevantRanges = sizeRanges.filter { range in
                    let rangeStart = range.lowerBound
                    let rangeEnd = range.upperBound == Double.infinity ? maxSize + 100 : range.upperBound
                    // Range overlaps if it starts before maxSize and ends after minSize
                    return rangeStart < maxSize && rangeEnd > minSize
                }
                
                print("📊 Using \(relevantRanges.count) granular ranges within particle bounds")
                
                // Estimate percentage for each granular range by interpolating from categorical data
                return relevantRanges.compactMap { range -> (microns: Double, percentage: Double, label: String)? in
                    let midpoint = range.upperBound == Double.infinity ? range.lowerBound + 200 : (range.lowerBound + range.upperBound) / 2
                    
                    // Skip ranges completely outside the actual particle range
                    if midpoint < minSize || midpoint > maxSize {
                        return nil
                    }
                    
                    // Find which grind type category this granular range best fits into
                    var bestMatch: (category: (range: Range<Double>, label: String), percentage: Double)?
                    for category in results.grindType.distributionCategories {
                        guard let percentage = results.sizeDistribution[category.label], percentage > 0 else { continue }
                        
                        // Check if this granular range overlaps with the category
                        let categoryStart = category.range.lowerBound
                        let categoryEnd = category.range.upperBound == Double.infinity ? 2000.0 : category.range.upperBound
                        
                        if midpoint >= categoryStart && midpoint < categoryEnd {
                            bestMatch = (category: category, percentage: percentage)
                            break
                        }
                    }
                    
                    guard let match = bestMatch else { return nil }
                    
                    // Create a normal distribution-like curve within the actual range
                    // Particles closer to the center of the actual range get higher percentages
                    let distanceFromCenter = abs(midpoint - (minSize + maxSize) / 2)
                    let maxDistance = (maxSize - minSize) / 2
                    let normalizedDistance = maxDistance > 0 ? distanceFromCenter / maxDistance : 0
                    let distributionFactor = max(0.1, 1.0 - normalizedDistance) // 0.1 to 1.0
                    
                    let estimatedPercentage = match.percentage * distributionFactor * 0.5 // Scale down for smoother curve
                    
                    let label = "\(Int(range.lowerBound))-\(range.upperBound == Double.infinity ? "∞" : "\(Int(range.upperBound))")μm"
                    return (microns: midpoint, percentage: estimatedPercentage, label: label)
                }
            } else {
                // Final fallback: use the old approach with grind type categories
                let categories = results.grindType.distributionCategories
                return categories.compactMap { category in
                    guard let percentage = results.sizeDistribution[category.label], percentage > 0 else { return nil }
                    
                    let micronValue: Double
                    if category.range.upperBound == Double.infinity {
                        micronValue = category.range.lowerBound + 200
                    } else {
                        micronValue = (category.range.lowerBound + category.range.upperBound) / 2
                    }
                    
                    return (microns: micronValue, percentage: percentage, label: category.label)
                }.sorted { $0.microns < $1.microns }
            }
        }
    }
    
    private func debugLogChartData(_ chartData: [(microns: Double, percentage: Double, label: String)]) -> Bool {
        print("🎨 DEBUG: Rendering chart with \(chartData.count) data points")
        let nonZeroChart = chartData.filter { $0.percentage > 0 }
        print("🎨 DEBUG: Non-zero chart points: \(nonZeroChart.count)")
        for point in nonZeroChart.prefix(5) {
            print("🎨 DEBUG: Rendering point - \(point.label): \(String(format: "%.1f", point.percentage))% at \(String(format: "%.0f", point.microns))μm")
        }
        return true
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
    
    private func determineChartXDomain() -> ClosedRange<Double> {
        // Scale based on actual particles captured or stored min/max values
        if let minSize = results.minParticleSize, let maxSize = results.maxParticleSize {
            // Add 15% padding on each side for better visualization
            let range = maxSize - minSize
            let padding = max(range * 0.15, 50) // At least 50μm padding
            let lowerBound = max(0, minSize - padding)
            let upperBound = maxSize + padding
            
            let dataSource = results.particles.isEmpty ? "stored min/max" : "particles"
            print("📊 Chart domain calculated: \(String(format: "%.1f", lowerBound))-\(String(format: "%.1f", upperBound))μm (source: \(dataSource), min: \(String(format: "%.1f", minSize)), max: \(String(format: "%.1f", maxSize)))")
            print("📊 Particles count: \(results.particles.count), range: \(String(format: "%.1f", range))μm, padding: \(String(format: "%.1f", padding))μm")
            
            return lowerBound...upperBound
        } else {
            // Fallback: No particle data, use grind type's expected range
            let targetRange = results.grindType.targetSizeMicrons
            let targetMin = targetRange.lowerBound
            let targetMax = targetRange.upperBound
            
            // Show from half the target min to 1.5x the target max
            return (targetMin * 0.5)...(targetMax * 1.5)
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
        .background(Color.brown.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
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
        .background(Color.brown.opacity(0.7))
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

    // MARK: - Brewing Workflow

    private func startBrewingWorkflow() {
        // Get or create SavedCoffeeAnalysis
        let savedAnalysis: SavedCoffeeAnalysis

        if isFromHistory,
           let existingAnalysis = historyManager.savedAnalyses.first(where: { $0.results.timestamp == results.timestamp }) {
            // Use existing saved analysis
            savedAnalysis = existingAnalysis
        } else {
            // Create temporary SavedCoffeeAnalysis for the brewing workflow
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let dateString = formatter.string(from: results.timestamp)
            let name = "\(results.grindType.displayName) - \(dateString)"

            savedAnalysis = SavedCoffeeAnalysis(
                name: name,
                results: results,
                savedDate: Date(),
                notes: nil,
                originalImagePath: nil,
                processedImagePath: nil
            )
        }

        // Set grind context in brew state
        brewState.setGrindContext(savedAnalysis)

        // Switch to Brew tab (index 1)
        tabSelection?.wrappedValue = 1

        // Dismiss the results view
        dismiss()
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
        .background(Color.brown.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Image Comparison View

struct ImageComparisonView: View {
    let results: CoffeeAnalysisResults
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingOriginal = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // Brown background to match the rest of the app
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()
                
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
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if showingOriginal {
                                Text("Original captured image showing the coffee grind sample")
                                    .foregroundColor(.white)
                            } else {
                                Text("Processed image with detected particles highlighted in blue")
                                    .foregroundColor(.white)
                                
                                // Only show legend for non-blue highlighting (removed since all particles are blue now)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.brown.opacity(0.5))
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Image Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
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
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        default: return .gray
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
        • Size Match: \(results.grindType.targetSizeMicrons.contains(results.medianSize) ? "In Range" : "Out of Range")
        • Median Size: \(String(format: "%.1f", results.medianSize))μm
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
    
    
    var body: some View {
        NavigationView {
            ZStack {
                // Match History view background
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        analysisInfoCard
                        saveDetailsCard
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .scrollDismissesKeyboard(.interactively)
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
    
    private var analysisInfoCard: some View {
        SaveCard(title: "Analysis Info") {
            VStack(spacing: 16) {
                HStack {
                    Text("Grind Type")
                        .foregroundColor(.white)
                    Spacer()
                    Text(results.grindType.displayName)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack {
                    Text("Size Match")
                        .foregroundColor(.white)
                    Spacer()
                    let isInRange = results.grindType.targetSizeMicrons.contains(results.medianSize)
                    Text(isInRange ? "In Range" : "Out of Range")
                        .foregroundColor(isInRange ? .green : .red)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Date")
                        .foregroundColor(.white)
                    Spacer()
                    Text(results.timestamp, style: .date)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    private var saveDetailsCard: some View {
        SaveCard(title: "Save Details") {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Auto-generated if empty", text: $saveName)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Add notes about grinder, beans, etc.", text: $saveNotes, axis: .vertical)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .lineLimit(3...6)
                }
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
    }
    
    private func saveAnalysis() {
        let name = saveName.isEmpty ? nil : saveName
        let notes = saveNotes.isEmpty ? nil : saveNotes
        
        onSave(name, notes, nil)
    }
}

// MARK: - Button Styles

struct ImprovementButtonStyle: ButtonStyle {
    let color: Color
    let isSecondary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isSecondary ? color : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSecondary ? 
                    AnyView(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.5), lineWidth: 1)
                            .background(Color.clear)
                    ) :
                    AnyView(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
            calibrationFactor: 150.0
        )
        
        return ResultsView(results: sampleResults)
    }
}

// MARK: - Save Card Component

struct SaveCard<Content: View>: View {
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

#endif
