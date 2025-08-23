//
//  HistoryView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyManager: CoffeeAnalysisHistoryManager
    @StateObject private var comparisonManager = ComparisonManager()
    
    @State private var searchText = ""
    @State private var selectedGrindFilter: CoffeeGrindType?
    @State private var sortOption: SortOption = .dateNewest
    @State private var showingDeleteAlert = false
    @State private var analysisToDelete: SavedCoffeeAnalysis?
    @State private var showingClearAllAlert = false
    @State private var selectedAnalysis: SavedCoffeeAnalysis?
    @State private var analysisToPresent: SavedCoffeeAnalysis?
    @State private var showingEditTastingNotes = false
    @State private var analysisToEditTastingNotes: SavedCoffeeAnalysis?
    @State private var showingComparison = false
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if comparisonManager.selectedAnalyses.isEmpty {
                        Button("Compare") {
                            // Start comparison mode by adding the first analysis automatically
                            // This puts us into selection mode
                            if let firstAnalysis = filteredAndSortedAnalyses.first {
                                comparisonManager.toggleSelection(firstAnalysis.id)
                            }
                        }
                        .disabled(filteredAndSortedAnalyses.count < 2)
                    } else {
                        Button("Cancel") {
                            comparisonManager.clearSelection()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if comparisonManager.canStartComparison {
                        Button("Compare (\(comparisonManager.selectedAnalyses.count))") {
                            if let comparison = comparisonManager.createComparison(from: historyManager) {
                                showingComparison = true
                            }
                        }
                        .fontWeight(.semibold)
                    } else {
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
            .overlay(
                Group {
                    if !comparisonManager.selectedAnalyses.isEmpty {
                        VStack {
                            Spacer()
                            comparisonInstructionsBar
                        }
                        .ignoresSafeArea(edges: .bottom)
                    }
                }
            )
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
        .sheet(isPresented: $showingEditTastingNotes) {
            if let analysis = analysisToEditTastingNotes {
                EditTastingNotesDialog(
                    savedAnalysis: analysis,
                    onSave: { updatedAnalysis, tastingNotes in
                        historyManager.updateAnalysisTastingNotes(
                            analysisId: updatedAnalysis.id,
                            tastingNotes: tastingNotes
                        )
                        analysisToEditTastingNotes = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingComparison) {
            if let comparison = comparisonManager.createComparison(from: historyManager) {
                ComparisonView(comparison: comparison)
                    .onDisappear {
                        comparisonManager.clearSelection()
                    }
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
                    ComparisonHistoryRowView(
                        analysis: analysis,
                        isSelected: comparisonManager.isSelected(analysis.id),
                        canSelect: comparisonManager.canSelect(analysis.id),
                        onTap: {
                            if !comparisonManager.selectedAnalyses.isEmpty {
                                // In comparison mode - toggle selection
                                comparisonManager.toggleSelection(analysis.id)
                            } else {
                                // Normal mode - show details
                                print("🎯 User tapped analysis: \(analysis.name)")
                                analysisToPresent = analysis
                                print("🎯 Set analysisToPresent to: \(analysis.name)")
                            }
                        },
                        onDelete: {
                            analysisToDelete = analysis
                            showingDeleteAlert = true
                        },
                        onEditTastingNotes: {
                            analysisToEditTastingNotes = analysis
                            showingEditTastingNotes = true
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .onDelete(perform: deleteAnalyses)
            }
            .listStyle(PlainListStyle())
        }
    }
    
    private var comparisonInstructionsBar: some View {
        VStack(spacing: 8) {
            if comparisonManager.selectedAnalyses.count < 2 {
                Text("Select at least 2 analyses to compare")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(comparisonManager.selectedAnalyses.count) selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if comparisonManager.canStartComparison {
                    Button("Compare") {
                        if let comparison = comparisonManager.createComparison(from: historyManager) {
                            showingComparison = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .padding()
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

// MARK: - Comparison History Row View

struct ComparisonHistoryRowView: View {
    let analysis: SavedCoffeeAnalysis
    let isSelected: Bool
    let canSelect: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onEditTastingNotes: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Main row content
                HStack(spacing: 16) {
                    // Selection indicator or grind type icon
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "checkmark")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: iconForGrindType(analysis.results.grindType))
                                    .font(.title2)
                                    .foregroundColor(canSelect ? iconColorForGrindType(analysis.results.grindType) : iconColorForGrindType(analysis.results.grindType).opacity(0.3))
                            }
                        }
                        
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
                            .foregroundColor(canSelect ? .primary : .secondary)
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
                    
                    // Date and actions (hidden during selection)
                    if !isSelected {
                        VStack(alignment: .trailing, spacing: 8) {
                            Text(analysis.savedDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                // Edit tasting notes button
                                Button(action: onEditTastingNotes) {
                                    Image(systemName: analysis.results.tastingNotes != nil ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundColor(analysis.results.tastingNotes != nil ? .yellow : .gray)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: onDelete) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                // Tasting notes preview (if available and not in selection mode)
                if let tastingNotes = analysis.results.tastingNotes, !isSelected {
                    Divider()
                    CompactTastingNotesView(tastingNotes: tastingNotes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(canSelect ? 1.0 : 0.6)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: isSelected ? 2 : 0)
        )
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
