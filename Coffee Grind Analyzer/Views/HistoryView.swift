//
//  HistoryView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyManager: CoffeeAnalysisHistoryManager
    @EnvironmentObject private var brewState: BrewAppState
    @Environment(\.tabSelection) private var tabSelection
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
    @State private var isInComparisonMode = false
    
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
            ZStack {
                // Much darker brown background to match RecommendationView
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Fixed search bar outside of scrollable content
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.7))
                            
                            TextField("Search analyses...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .submitLabel(.search)
                                .onSubmit {
                                    // Dismiss keyboard when search is submitted
                                    hideKeyboard()
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.brown.opacity(0.5))
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        )
                        .onTapGesture {
                            // Allow tapping in search field to focus
                        }
                        
                        if !searchText.isEmpty {
                            Button("Cancel") {
                                searchText = ""
                                hideKeyboard()
                            }
                            .foregroundColor(.brown)
                            .fontWeight(.medium)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    
                    // Filter tags
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
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    
                    if historyManager.savedAnalyses.isEmpty {
                        emptyHistoryView
                    } else {
                        historyContentWithFixedHeader
                            .onTapGesture {
                                // Dismiss keyboard when tapping outside search field
                                hideKeyboard()
                            }
                    }
                }
            }
            .navigationTitle("Analysis History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isInComparisonMode {
                        Button("Compare") {
                            // Start comparison mode without selecting anything
                            isInComparisonMode = true
                        }
                        .disabled(filteredAndSortedAnalyses.count < 2)
                    } else {
                        Button("Cancel") {
                            comparisonManager.clearSelection()
                            isInComparisonMode = false
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
                    if isInComparisonMode {
                        VStack {
                            Spacer()
                            comparisonInstructionsBar
                                .padding(.bottom, 20) // Position right above tab bar
                        }
                    }
                }
            )
        }
        // Remove the .searchable modifier since we have custom search bar now
        .sheet(item: $analysisToPresent) { analysis in
            ResultsView(results: analysis.results, isFromHistory: true)
                .environmentObject(historyManager)
                .environmentObject(brewState)
                .environment(\.tabSelection, tabSelection)
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
                        isInComparisonMode = false
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
                .foregroundColor(.white.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Saved Analyses")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Capture and save coffee grind analyses to see them here")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(40)
    }
    
    private var historyContentWithFixedHeader: some View {
        VStack(spacing: 0) {
            // Only the list scrolls
            List {
                ForEach(filteredAndSortedAnalyses) { analysis in
                    ComparisonHistoryRowView(
                        analysis: analysis,
                        isSelected: comparisonManager.isSelected(analysis.id),
                        canSelect: comparisonManager.canSelect(analysis.id),
                        onTap: {
                            if isInComparisonMode {
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
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brown.opacity(0.5))
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    )
                }
                .onDelete(perform: deleteAnalyses)
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .simultaneousGesture(
                // Add drag gesture to dismiss keyboard on scroll
                DragGesture()
                    .onChanged { _ in
                        hideKeyboard()
                    }
            )
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
            HStack(spacing: 12) {
                statCard(
                    title: "Total",
                    value: "\(filteredAndSortedAnalyses.count)",
                    subtitle: filteredAndSortedAnalyses.count == historyManager.totalAnalyses ? "analyses" : "filtered",
                    color: Color.brown
                )
                
                if let percentInRange = percentInTargetRange {
                    statCard(
                        title: "In Range",
                        value: "\(Int(percentInRange))%",
                        subtitle: "on target",
                        color: colorForScore(percentInRange)
                    )
                }
                
                statCard(
                    title: "This Week",
                    value: "\(analysesThisWeek)",
                    subtitle: "analyses",
                    color: Color.brown
                )
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
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.95), Color.white.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.brown.opacity(0.1), lineWidth: 0.5)
                .padding(.top, -1)
        )
    }
    
    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
    
    private var percentInTargetRange: Double? {
        guard !filteredAndSortedAnalyses.isEmpty else { return nil }
        
        let inRangeCount = filteredAndSortedAnalyses.filter { analysis in
            let grindType = analysis.results.grindType
            let avgSize = analysis.results.averageSize
            
            switch grindType {
            case .filter:
                return avgSize >= 600 && avgSize <= 900
            case .espresso:
                return avgSize >= 200 && avgSize <= 400
            case .frenchPress:
                return avgSize >= 750 && avgSize <= 1000
            case .coldBrew:
                return avgSize >= 1000 && avgSize <= 1200
            }
        }.count
        
        return (Double(inRangeCount) / Double(filteredAndSortedAnalyses.count)) * 100
    }
    
    private var analysesThisWeek: Int {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        
        return filteredAndSortedAnalyses.filter { analysis in
            analysis.savedDate >= oneWeekAgo
        }.count
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
    
    // Helper function to dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                // Main row content with more vertical space
                HStack(spacing: 16) {
                    // Selection indicator or grind type icon
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.brown)
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: iconForGrindType(analysis.results.grindType))
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 50)
                    
                    // Analysis details with better spacing
                    VStack(alignment: .leading, spacing: 10) {
                        // Title and grind type
                        VStack(alignment: .leading, spacing: 2) {
                            Text(analysis.name)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text(analysis.results.grindType.displayName)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // Metrics stacked vertically - each on its own line
                        VStack(alignment: .leading, spacing: 6) {
                            // Particles on first line
                            HStack(spacing: 6) {
                                Image(systemName: "circle.grid.3x3")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(analysis.results.particleCount) particles")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            // Median size on second line
                            HStack(spacing: 6) {
                                Image(systemName: "ruler")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(String(format: "%.0f", analysis.results.medianSize))μm median")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        // Notes if available
                        if let notes = analysis.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                                .italic()
                        }
                        
                        // Tasting notes preview (moved inside main content - no divider)
                        if let tastingNotes = analysis.results.tastingNotes, !isSelected {
                            // Add subtle visual separator without using Divider
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 0.5)
                                .padding(.vertical, 4)
                            
                            // Indent tasting notes to match metrics alignment
                            HStack {
                                // Add leading space to align with metrics
                                Spacer()
                                    .frame(width: 0)
                                
                                CompactTastingNotesView(tastingNotes: tastingNotes)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Date only (hidden during selection)
                    if !isSelected {
                        VStack(alignment: .trailing, spacing: 8) {
                            Text(analysis.savedDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.trailing, 8)
                    }
                }
            }
            .padding(.vertical, 12) // Increased padding for more breathing room
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
        return .brown
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
                .fontWeight(.medium)
                .foregroundColor(.brown)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.brown.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.brown.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(Color.brown.opacity(0.2), lineWidth: 0.5)
                )
        )
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
            sizeDistribution: ["Fines (<400μm)": 12.3, "Fine (400-600μm)": 25.1, "Medium (600-1000μm)": 45.2, "Coarse (1000-1400μm)": 12.7, "Boulders (>1400μm)": 4.7],
            calibrationFactor: 150.0
        )
        
        historyManager.saveAnalysis(sampleResults, name: "Morning Espresso", notes: "Breville Smart Grinder Pro")
        
        return HistoryView()
            .environmentObject(historyManager)
    }
}
#endif
