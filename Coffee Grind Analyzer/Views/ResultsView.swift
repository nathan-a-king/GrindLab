//
//  ResultsView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI
import Charts

struct ResultsView: View {
    let results: CoffeeAnalysisResults
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
    
    init(results: CoffeeAnalysisResults, isFromHistory: Bool = false) {
        self.results = results
        self.isFromHistory = isFromHistory
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
                onSave: { name, notes in
                    historyManager.saveAnalysis(results, name: name, notes: notes)
                    saveSuccess = true
                    showingSaveDialog = false
                }
            )
        }
        .alert("Analysis Saved!", isPresented: $saveSuccess) {
            Button("OK") { }
        } message: {
            Text("Your coffee grind analysis has been saved successfully.")
        }
        .onAppear {
            print("🔍 ResultsView body appeared - isFromHistory: \(isFromHistory)")
            
            // Force refresh for first-load issues
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                chartRefreshTrigger.toggle()
                print("🔄 Chart refresh triggered")
            }
            
            // Debug logging
            print("🔍 ResultsView data check:")
            print("   - From History: \(isFromHistory)")
            print("   - Uniformity: \(Int(results.uniformityScore))%")
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
                
                gradeSection
                    .onAppear { print("📊 Grade section appeared") }
                
                recommendationsSection
                    .onAppear { print("📊 Recommendations section appeared") }
            }
            .padding()
            .onAppear {
                print("📊 Overview tab content appeared")
            }
        }
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
                    
                    Text("Analyzed \(results.timestamp, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(Int(results.uniformityScore))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(results.uniformityColor)
                    
                    Text("Uniformity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: results.uniformityScore / 100)
                .tint(results.uniformityColor)
        }
        .padding()
        .background(Color(.systemGray6))
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
                color: .blue,
                icon: "ruler"
            )
            
            metricCard(
                title: "Particle Count",
                value: "\(results.particleCount)",
                subtitle: "Detected particles",
                color: .green,
                icon: "number"
            )
            
            metricCard(
                title: "Fines",
                value: String(format: "%.1f%%", results.finesPercentage),
                subtitle: "<400 μm particles",
                color: .orange,
                icon: "sparkles"
            )
            
            metricCard(
                title: "Confidence",
                value: String(format: "%.0f%%", results.confidence),
                subtitle: "Analysis reliability",
                color: .purple,
                icon: "checkmark.seal"
            )
        }
    }
    
    private func metricCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var gradeSection: some View {
        VStack(spacing: 12) {
            Text("Overall Grade")
                .font(.headline)
            
            Text(results.uniformityGrade)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(results.uniformityColor)
            
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    Image(systemName: index < gradeStars ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var gradeStars: Int {
        switch results.uniformityScore {
        case 90...: return 5
        case 80..<90: return 4
        case 70..<80: return 3
        case 60..<70: return 2
        case 50..<60: return 1
        default: return 0
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
            
            ForEach(Array(results.recommendations.enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text(recommendation)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Details Tab
    
    private var detailsTab: some View {
        List {
            Section("Particle Statistics") {
                DetailRow(label: "Average Size", value: String(format: "%.1f μm", results.averageSize))
                DetailRow(label: "Median Size", value: String(format: "%.1f μm", results.medianSize))
                DetailRow(label: "Standard Deviation", value: String(format: "%.1f μm", results.standardDeviation))
                DetailRow(label: "Coefficient of Variation", value: String(format: "%.1f%%", (results.standardDeviation / results.averageSize) * 100))
            }
            
            Section("Size Distribution") {
                DetailRow(label: "Fines (<400μm)", value: String(format: "%.1f%%", results.finesPercentage))
                DetailRow(label: "Boulders (>1400μm)", value: String(format: "%.1f%%", results.bouldersPercentage))
                DetailRow(label: "Medium (400-1400μm)", value: String(format: "%.1f%%", 100 - results.finesPercentage - results.bouldersPercentage))
            }
            
            Section("Target Ranges") {
                DetailRow(label: "Target Size", value: results.grindType.targetSizeRange)
                DetailRow(label: "Ideal Fines", value: "\(Int(results.grindType.idealFinesPercentage.lowerBound))-\(Int(results.grindType.idealFinesPercentage.upperBound))%")
                
                let isInRange = results.grindType.targetSizeMicrons.contains(results.averageSize)
                DetailRow(
                    label: "Size Match",
                    value: isInRange ? "✓ In Range" : "✗ Out of Range",
                    valueColor: isInRange ? .green : .red
                )
            }
            
            Section("Analysis Info") {
                DetailRow(label: "Particles Detected", value: "\(results.particleCount)")
                DetailRow(label: "Confidence Level", value: String(format: "%.0f%%", results.confidence))
                DetailRow(label: "Analysis Time", value: results.timestamp.formatted(date: .omitted, time: .shortened))
                DetailRow(label: "Grind Type", value: results.grindType.displayName)
            }
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
                        
                        Text("Chart view requires iOS 16+")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                sizeDistributionList
            }
            .padding()
        }
    }
    
    @available(iOS 16.0, *)
    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Particle Size Distribution")
                .font(.headline)
            
            let sortedData = Array(results.sizeDistribution.sorted { first, second in
                let order = ["Fines (<400μm)", "Fine (400-600μm)", "Medium (600-1000μm)", "Coarse (1000-1400μm)", "Boulders (>1400μm)"]
                let firstIndex = order.firstIndex(of: first.key) ?? 999
                let secondIndex = order.firstIndex(of: second.key) ?? 999
                return firstIndex < secondIndex
            })
            
            // Debug logging
            let _ = print("🎨 Rendering chart for analysis with \(sortedData.count) data points: \(sortedData.map { "\($0.key): \($0.value)%" })")
            
            if sortedData.isEmpty {
                Text("No distribution data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                Chart(sortedData, id: \.key) { category, percentage in
                    LineMark(
                        x: .value("Category", categoryShortName(category)),
                        y: .value("Percentage", percentage / 100.0)
                    )
                    .foregroundStyle(colorForCategory(category))
                    .interpolationMethod(.catmullRom)
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    .symbolSize(60)
                    
                    AreaMark(
                        x: .value("Category", categoryShortName(category)),
                        y: .value("Percentage", percentage / 100.0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [colorForCategory(category).opacity(0.3), colorForCategory(category).opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let category = value.as(String.self) {
                                Text(category)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func categoryShortName(_ category: String) -> String {
        switch category {
        case "Fines (<400μm)": return "Fines"
        case "Fine (400-600μm)": return "Fine"
        case "Medium (600-1000μm)": return "Medium"
        case "Coarse (1000-1400μm)": return "Coarse"
        case "Boulders (>1400μm)": return "Boulders"
        default: return category
        }
    }
    
    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Fines (<400μm)": return .red
        case "Fine (400-600μm)": return .orange
        case "Medium (600-1000μm)": return .green
        case "Coarse (1000-1400μm)": return .blue
        case "Boulders (>1400μm)": return .purple
        default: return .gray
        }
    }
    
    private var sizeDistributionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Size Categories")
                .font(.headline)
            
            let orderedCategories = ["Fines (<400μm)", "Fine (400-600μm)", "Medium (600-1000μm)", "Coarse (1000-1400μm)", "Boulders (>1400μm)"]
            
            ForEach(orderedCategories, id: \.self) { category in
                if let percentage = results.sizeDistribution[category] {
                    HStack {
                        Circle()
                            .fill(colorForCategory(category))
                            .frame(width: 12, height: 12)
                        
                        Text(category)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%%", percentage))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
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
        • Uniformity Score: \(Int(results.uniformityScore))% (\(results.uniformityGrade))
        • Average Size: \(String(format: "%.1f", results.averageSize))μm
        • Particles Detected: \(results.particleCount)
        • Fines: \(String(format: "%.1f", results.finesPercentage))%
        • Confidence: \(Int(results.confidence))%
        
        🎯 Target Range: \(results.grindType.targetSizeRange)
        
        💡 Top Recommendation:
        \(results.recommendations.first ?? "Great grind quality!")
        
        #CoffeeGrindAnalyzer #Coffee #Analysis
        """
    }
}

// MARK: - Save Analysis Dialog

struct SaveAnalysisDialog: View {
    let results: CoffeeAnalysisResults
    @Binding var saveName: String
    @Binding var saveNotes: String
    let onSave: (String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
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
                        Text("Uniformity Score")
                        Spacer()
                        Text("\(Int(results.uniformityScore))%")
                            .foregroundColor(results.uniformityColor)
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
                        let name = saveName.isEmpty ? nil : saveName
                        let notes = saveNotes.isEmpty ? nil : saveNotes
                        onSave(name, notes)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Pre-populate with suggested name
            if saveName.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                let dateString = formatter.string(from: results.timestamp)
                saveName = "\(results.grindType.displayName) - \(dateString)"
            }
        }
    }
}
