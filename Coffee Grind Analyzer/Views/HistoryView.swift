//
//  HistoryView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyManager: CoffeeAnalysisHistoryManager
    @State private var searchText = ""
    @State private var selectedGrindFilter: CoffeeGrindType?
    @State private var sortOption: SortOption = .dateNewest
    @State private var showingDeleteAlert = false
    @State private var analysisToDelete: SavedCoffeeAnalysis?
    @State private var showingClearAllAlert = false
    @State private var selectedAnalysis: SavedCoffeeAnalysis?
    @State private var analysisToPresent: SavedCoffeeAnalysis?
    
    enum SortOption: String, CaseIterable {
        case dateNewest = "Date (Newest)"
        case dateOldest = "Date (Oldest)"
        case uniformityBest = "Best Uniformity"
        case uniformityWorst = "Worst Uniformity"
        case grindType = "Grind Type"
        case name = "Name"
    }
    
    var filteredAndSortedAnalyses: [SavedCoffeeAnalysis] {
        var analyses = historyManager.savedAnalyses
        
        // Apply grind type filter
        if let grindFilter = selectedGrindFilter {
            analyses = analyses.filter { $0.results.grindType == grindFilter }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            analyses = analyses.filter { analysis in
                analysis.name.localizedCaseInsensitiveContains(searchText) ||
                analysis.results.grindType.displayName.localizedCaseInsensitiveContains(searchText) ||
                (analysis.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateNewest:
            return analyses.sorted { $0.savedDate > $1.savedDate }
        case .dateOldest:
            return analyses.sorted { $0.savedDate < $1.savedDate }
        case .uniformityBest:
            return analyses.sorted { $0.results.uniformityScore > $1.results.uniformityScore }
        case .uniformityWorst:
            return analyses.sorted { $0.results.uniformityScore < $1.results.uniformityScore }
        case .grindType:
            return analyses.sorted { $0.results.grindType.displayName < $1.results.grindType.displayName }
        case .name:
            return analyses.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if historyManager.savedAnalyses.isEmpty {
                    emptyHistoryView
                } else {
                    historyContent
                }
            }
            .navigationTitle("Analysis History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Section("Sort by") {
                            Picker("Sort", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        }
                        
                        Section("Filter by Grind Type") {
                            Button(selectedGrindFilter == nil ? "✓ All Types" : "All Types") {
                                selectedGrindFilter = nil
                            }
                            
                            ForEach(CoffeeGrindType.allCases, id: \.self) { grindType in
                                Button(selectedGrindFilter == grindType ? "✓ \(grindType.displayName)" : grindType.displayName) {
                                    selectedGrindFilter = selectedGrindFilter == grindType ? nil : grindType
                                }
                            }
                        }
                        
                        Section {
                            Button("Clear All History", role: .destructive) {
                                showingClearAllAlert = true
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search analyses...")
        .sheet(item: $analysisToPresent) { analysis in
            ResultsView(results: analysis.results, isFromHistory: true)
                .environmentObject(historyManager)
                .onAppear {
                    print("✅ History sheet appeared successfully for: \(analysis.name)")
                }
                .onDisappear {
                    print("👋 History sheet dismissed")
                }
        }
        .alert("Delete Analysis", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let analysis = analysisToDelete {
                    historyManager.deleteAnalysis(withId: analysis.id)
                }
                analysisToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                analysisToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this analysis? This action cannot be undone.")
        }
        .alert("Clear All History", isPresented: $showingClearAllAlert) {
            Button("Clear All", role: .destructive) {
                historyManager.clearAllAnalyses()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete all \(historyManager.totalAnalyses) saved analyses? This action cannot be undone.")
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Saved Analyses")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Capture and save coffee grind analyses to see them here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(40)
    }
    
    private var historyContent: some View {
        VStack(spacing: 0) {
            // Statistics Header
            statisticsHeader
            
            // Analysis List
            List {
                ForEach(filteredAndSortedAnalyses) { analysis in
                    HistoryRowView(
                        analysis: analysis,
                        onTap: {
                            print("🎯 User tapped analysis: \(analysis.name)")
                            analysisToPresent = analysis
                            print("🎯 Set analysisToPresent to: \(analysis.name)")
                        },
                        onDelete: {
                            analysisToDelete = analysis
                            showingDeleteAlert = true
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .onDelete(perform: deleteAnalyses)
            }
            .listStyle(PlainListStyle())
        }
    }
    
    private var statisticsHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                statCard(
                    title: "Total",
                    value: "\(filteredAndSortedAnalyses.count)",
                    subtitle: filteredAndSortedAnalyses.count == historyManager.totalAnalyses ? "analyses" : "filtered",
                    color: .blue
                )
                
                if let avgScore = averageUniformityScore {
                    statCard(
                        title: "Avg Score",
                        value: "\(Int(avgScore))%",
                        subtitle: "uniformity",
                        color: colorForScore(avgScore)
                    )
                }
                
                if let bestScore = bestUniformityScore {
                    statCard(
                        title: "Best Score",
                        value: "\(Int(bestScore))%",
                        subtitle: "uniformity",
                        color: colorForScore(bestScore)
                    )
                }
            }
            
            if selectedGrindFilter != nil || !searchText.isEmpty {
                HStack {
                    if let filter = selectedGrindFilter {
                        FilterTag(text: filter.displayName) {
                            selectedGrindFilter = nil
                        }
                    }
                    
                    if !searchText.isEmpty {
                        FilterTag(text: "\"\(searchText)\"") {
                            searchText = ""
                        }
                    }
                    
                    Spacer()
                    
                    Text("Showing \(filteredAndSortedAnalyses.count) of \(historyManager.totalAnalyses)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private var averageUniformityScore: Double? {
        guard !filteredAndSortedAnalyses.isEmpty else { return nil }
        let total = filteredAndSortedAnalyses.reduce(0) { $0 + $1.results.uniformityScore }
        return total / Double(filteredAndSortedAnalyses.count)
    }
    
    private var bestUniformityScore: Double? {
        return filteredAndSortedAnalyses.max { $0.results.uniformityScore < $1.results.uniformityScore }?.results.uniformityScore
    }
    
    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 85...: return .green
        case 70..<85: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }
    
    private func deleteAnalyses(at offsets: IndexSet) {
        let analysesToDelete = offsets.map { filteredAndSortedAnalyses[$0] }
        for analysis in analysesToDelete {
            historyManager.deleteAnalysis(withId: analysis.id)
        }
    }
}

// MARK: - History Row View

struct HistoryRowView: View {
    let analysis: SavedCoffeeAnalysis
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Grind type icon with score
                VStack(spacing: 4) {
                    Image(systemName: iconForGrindType(analysis.results.grindType))
                        .font(.title2)
                        .foregroundColor(iconColorForGrindType(analysis.results.grindType))
                    
                    Text("\(Int(analysis.results.uniformityScore))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(analysis.results.uniformityColor)
                }
                .frame(width: 50)
                
                // Analysis details
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(analysis.results.grindType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Label("\(analysis.results.particleCount) particles", systemImage: "circle.grid.3x3")
                        
                        Label(String(format: "%.0fμm avg", analysis.results.averageSize), systemImage: "ruler")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    if let notes = analysis.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .italic()
                    }
                }
                
                Spacer()
                
                // Date and delete button
                VStack(alignment: .trailing, spacing: 8) {
                    Text(analysis.savedDate, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconForGrindType(_ grindType: CoffeeGrindType) -> String {
        switch grindType {
        case .filter: return "drop.circle.fill"
        case .espresso: return "cup.and.saucer.fill"
        case .frenchPress: return "cylinder.fill"
        case .coldBrew: return "snowflake.circle.fill"
        }
    }
    
    private func iconColorForGrindType(_ grindType: CoffeeGrindType) -> Color {
        switch grindType {
        case .filter: return .blue
        case .espresso: return .orange
        case .frenchPress: return .green
        case .coldBrew: return .cyan
        }
    }
}

// MARK: - Filter Tag

struct FilterTag: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .foregroundColor(.blue)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Preview

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let historyManager = CoffeeAnalysisHistoryManager()
        
        // Add sample data
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
            sizeDistribution: ["Fines (<400μm)": 12.3, "Fine (400-600μm)": 25.1, "Medium (600-1000μm)": 45.2, "Coarse (1000-1400μm)": 12.7, "Boulders (>1400μm)": 4.7]
        )
        
        historyManager.saveAnalysis(sampleResults, name: "Morning Espresso", notes: "Breville Smart Grinder Pro")
        
        return HistoryView()
            .environmentObject(historyManager)
    }
}
#endif
