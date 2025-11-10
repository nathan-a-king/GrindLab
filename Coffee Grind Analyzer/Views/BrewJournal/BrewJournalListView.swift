//
//  BrewJournalListView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 11/8/25.
//

import SwiftUI
import OSLog

private let journalLogger = Logger(subsystem: "com.nateking.GrindLab", category: "BrewJournalList")

struct BrewJournalListView: View {
    @ObservedObject private var manager = BrewJournalManager.shared
    @StateObject private var historyManager = CoffeeAnalysisHistoryManager()

    @State private var searchText = ""
    @State private var selectedGrindFilter: CoffeeGrindType?
    @State private var selectedBrewMethodFilter: TastingNotes.BrewMethod?
    @State private var sortOption: SortOption = .dateNewest
    @State private var showingEntryForm = false
    @State private var entryToEdit: BrewJournalEntry?
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: BrewJournalEntry?
    @State private var selectedEntry: BrewJournalEntry?

    enum SortOption: String, CaseIterable {
        case dateNewest = "Date (Newest)"
        case dateOldest = "Date (Oldest)"
        case ratingBest = "Highest Rated"
        case ratingWorst = "Lowest Rated"
        case beanName = "Bean Name"
        case brewMethod = "Brew Method"
    }

    var filteredAndSortedEntries: [BrewJournalEntry] {
        var entries = manager.entries

        // Apply grind type filter
        if let grindFilter = selectedGrindFilter {
            entries = entries.filter { $0.grindType == grindFilter }
        }

        // Apply brew method filter
        if let methodFilter = selectedBrewMethodFilter {
            entries = entries.filter { $0.brewParameters.brewMethod == methodFilter }
        }

        // Apply search filter
        if !searchText.isEmpty {
            entries = entries.filter { $0.matchesSearchQuery(searchText) }
        }

        // Apply sorting
        switch sortOption {
        case .dateNewest:
            return entries.sorted { $0.timestamp > $1.timestamp }
        case .dateOldest:
            return entries.sorted { $0.timestamp < $1.timestamp }
        case .ratingBest:
            return entries.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .ratingWorst:
            return entries.sorted { ($0.rating ?? 0) < ($1.rating ?? 0) }
        case .beanName:
            return entries.sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        case .brewMethod:
            return entries.sorted { $0.brewParameters.brewMethod.rawValue < $1.brewParameters.brewMethod.rawValue }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    // Filter tags
                    if selectedGrindFilter != nil || selectedBrewMethodFilter != nil || !searchText.isEmpty {
                        filterTagsView
                    }

                    // Content
                    if manager.entries.isEmpty {
                        emptyStateView
                    } else if filteredAndSortedEntries.isEmpty {
                        noResultsView
                    } else {
                        journalList
                    }
                }
            }
            .navigationTitle("Brew Journal")
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
                                    selectedGrindFilter = grindType
                                }
                            }
                        }

                        Section("Filter by Brew Method") {
                            Button(selectedBrewMethodFilter == nil ? "✓ All Methods" : "All Methods") {
                                selectedBrewMethodFilter = nil
                            }

                            ForEach(TastingNotes.BrewMethod.allCases, id: \.self) { method in
                                Button(selectedBrewMethodFilter == method ? "✓ \(method.rawValue)" : method.rawValue) {
                                    selectedBrewMethodFilter = method
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        entryToEdit = nil
                        showingEntryForm = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingEntryForm) {
                BrewJournalEntryForm(entry: entryToEdit) { entry in
                    if entryToEdit != nil {
                        manager.updateEntry(entry)
                    } else {
                        manager.saveEntry(entry)
                    }
                    entryToEdit = nil
                }
                .presentationBackground(.ultraThinMaterial)
            }
            .alert("Delete Brew Log?", isPresented: $showingDeleteAlert, presenting: entryToDelete) { entry in
                Button("Cancel", role: .cancel) {
                    entryToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    manager.deleteEntry(id: entry.id)
                    entryToDelete = nil
                }
            } message: { entry in
                Text("Are you sure you want to delete \"\(entry.displayTitle)\"? This action cannot be undone.")
            }
            .sheet(item: $selectedEntry) { entry in
                BrewJournalDetailView(baseEntry: entry, historyManager: historyManager)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.7))

                TextField("Search brews...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .submitLabel(.search)
                    .onSubmit {
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

            if !searchText.isEmpty {
                Button("Cancel") {
                    searchText = ""
                    hideKeyboard()
                }
                .foregroundColor(.white)
                .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Filter Tags

    private var filterTagsView: some View {
        HStack {
            if let filter = selectedGrindFilter {
                BrewFilterTag(text: filter.displayName) {
                    selectedGrindFilter = nil
                }
            }

            if let methodFilter = selectedBrewMethodFilter {
                BrewFilterTag(text: methodFilter.rawValue) {
                    selectedBrewMethodFilter = nil
                }
            }

            if !searchText.isEmpty {
                BrewFilterTag(text: "\"\(searchText)\"") {
                    searchText = ""
                }
            }

            Spacer()

            Text("Showing \(filteredAndSortedEntries.count) of \(manager.totalEntries)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Journal List

    private var journalList: some View {
        List {
            ForEach(filteredAndSortedEntries) { entry in
                Button {
                    selectedEntry = entry
                } label: {
                    BrewJournalRowView(entry: entry)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        entryToDelete = entry
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .simultaneousGesture(
            DragGesture().onChanged { _ in
                hideKeyboard()
            }
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.5))

            Text("No Brew Logs Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Start logging your coffee brewing sessions")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingEntryForm = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Brew")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
                .fontWeight(.semibold)
            }
            .padding(.top, 10)

            Spacer()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))

            Text("No Matching Brews")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Try adjusting your search or filters")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))

            Button("Clear Filters") {
                searchText = ""
                selectedGrindFilter = nil
                selectedBrewMethodFilter = nil
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.3))
            )
            .foregroundColor(.white)

            Spacer()
        }
    }

    // MARK: - Helper Methods

    private func duplicateEntry(_ entry: BrewJournalEntry) {
        let duplicate = BrewJournalEntry(
            id: UUID(), // New ID
            timestamp: Date(), // Current time
            grindType: entry.grindType,
            coffeeBean: entry.coffeeBean,
            brewParameters: entry.brewParameters,
            tastingNotes: entry.tastingNotes,
            notes: entry.notes
        )
        manager.saveEntry(duplicate)
        journalLogger.info("Duplicated entry: \(entry.displayTitle, privacy: .public)")
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Filter Tag

private struct BrewFilterTag: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .foregroundColor(.white)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.6))
        )
    }
}

// MARK: - Preview

#Preview {
    BrewJournalListView()
}
