//
//  BrewJournalDetailView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 11/8/25.
//

import SwiftUI
import OSLog

private let detailLogger = Logger(subsystem: "com.nateking.GrindLab", category: "BrewJournalDetail")

struct BrewJournalDetailView: View {
    let baseEntry: BrewJournalEntry
    let historyManager: CoffeeAnalysisHistoryManager
    @ObservedObject private var journalManager = BrewJournalManager.shared

    @Environment(\.dismiss) private var dismiss
    @State private var showingEditForm = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var shareText = ""

    // Computed property to get current entry with updates
    private var entry: BrewJournalEntry {
        journalManager.entries.first(where: { $0.id == baseEntry.id }) ?? baseEntry
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Coffee Bean Info Section
                        if let coffeeBean = entry.coffeeBean {
                            coffeeBeanSection(coffeeBean)
                        }

                        // Grind Details Section
                        grindDetailsSection

                        // Brew Parameters Section
                        brewParametersSection

                        // Tasting Notes Section
                        if let tastingNotes = entry.tastingNotes {
                            TastingNotesDisplayView(tastingNotes: tastingNotes)
                                .padding(.horizontal, 16)
                        }

                        // General Notes Section
                        if let notes = entry.notes, !notes.isEmpty {
                            generalNotesSection(notes)
                        }

                        // Metadata Footer
                        metadataFooter
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(entry.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingEditForm = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button {
                            generateShareText()
                            showingShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            BrewJournalEntryForm(entry: entry) { updatedEntry in
                journalManager.updateEntry(updatedEntry)
            }
            .presentationBackground(.ultraThinMaterial)
        }
        .alert("Delete Brew Log?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                journalManager.deleteEntry(id: entry.id)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showingShareSheet) {
            BrewJournalShareSheet(shareText: shareText)
        }
    }

    // MARK: - Coffee Bean Section

    private func coffeeBeanSection(_ bean: CoffeeBeanInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coffee Bean")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 8) {
                if !bean.name.isEmpty {
                    detailRow(label: "Name", value: bean.name)
                }

                if let roaster = bean.roaster, !roaster.isEmpty {
                    detailRow(label: "Roaster", value: roaster)
                }

                if let origin = bean.origin, !origin.isEmpty {
                    detailRow(label: "Origin", value: origin)
                }

                if let process = bean.process, !process.isEmpty {
                    detailRow(label: "Process", value: process)
                }

                if let roastLevel = bean.roastLevel {
                    HStack {
                        Text("Roast Level")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: roastLevel.icon)
                                .font(.caption)
                            Text(roastLevel.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                    }
                }

                if let roastDate = bean.roastDate {
                    detailRow(label: "Roast Date", value: roastDate.formatted(date: .abbreviated, time: .omitted))

                    if let freshness = bean.freshnessStatus {
                        detailRow(label: "Freshness", value: freshness)
                    }
                }

                if let notes = bean.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Grind Details Section

    private var grindDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grind Details")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 8) {
                detailRow(label: "Grind Type", value: entry.grindType.displayName)

                if let grindSetting = entry.brewParameters.grindSetting, !grindSetting.isEmpty {
                    detailRow(label: "Grind Setting", value: grindSetting)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Brew Parameters Section

    private var brewParametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Brew Parameters")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 8) {
                detailRow(label: "Brew Method", value: entry.brewParameters.brewMethod.rawValue)

                if let doseIn = entry.brewParameters.doseIn {
                    detailRow(label: "Dose In", value: String(format: "%.1fg", doseIn))
                }

                if let yieldOut = entry.brewParameters.yieldOut {
                    detailRow(label: "Yield Out", value: String(format: "%.1fg", yieldOut))
                }

                if let ratio = entry.brewParameters.ratioDisplay {
                    detailRow(label: "Ratio", value: ratio)
                }

                if let brewTime = entry.brewParameters.brewTime {
                    detailRow(label: "Brew Time", value: String(format: "%.0fs", brewTime))
                }

                if let waterTemp = entry.brewParameters.waterTemp {
                    detailRow(label: "Water Temp", value: String(format: "%.0f°C", waterTemp))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - General Notes Section

    private func generalNotesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(.white)

            Text(notes)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.2))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Metadata Footer

    private var metadataFooter: some View {
        VStack(spacing: 4) {
            Text("Created \(entry.timestamp.formatted(date: .long, time: .shortened))")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            Text("ID: \(entry.id.uuidString.prefix(8))")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    // MARK: - Helper Methods

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }

    private func generateShareText() {
        var text = "☕️ \(entry.displayTitle)\n\n"

        if let bean = entry.coffeeBean {
            text += "📦 Coffee Bean\n"
            text += "• \(bean.name)\n"
            if let roaster = bean.roaster, !roaster.isEmpty {
                text += "• Roaster: \(roaster)\n"
            }
            if let origin = bean.origin, !origin.isEmpty {
                text += "• Origin: \(origin)\n"
            }
            text += "\n"
        }

        text += "⚙️ Brew Parameters\n"
        text += "• Method: \(entry.brewParameters.brewMethod.rawValue)\n"
        text += "• Grind: \(entry.grindType.displayName)\n"
        if let dose = entry.brewParameters.doseIn, let yield = entry.brewParameters.yieldOut {
            text += "• \(String(format: "%.1fg", dose)) → \(String(format: "%.1fg", yield))"
            if let ratio = entry.brewParameters.ratioDisplay {
                text += " (\(ratio))"
            }
            text += "\n"
        }
        if let temp = entry.brewParameters.waterTemp {
            text += "• Water: \(String(format: "%.0f°C", temp))\n"
        }
        if let time = entry.brewParameters.brewTime {
            text += "• Time: \(String(format: "%.0fs", time))\n"
        }
        text += "\n"

        if let tastingNotes = entry.tastingNotes {
            text += "⭐️ Rating: \(tastingNotes.overallRating)/5\n"
            if !tastingNotes.tastingTags.isEmpty {
                text += "🏷️ Tags: \(tastingNotes.tastingTags.sorted().joined(separator: ", "))\n"
            }
            text += "\n"
        }

        if let notes = entry.notes, !notes.isEmpty {
            text += "📝 Notes\n\(notes)\n\n"
        }

        text += "🕒 \(entry.timestamp.formatted(date: .long, time: .shortened))\n"
        text += "\nLogged with GrindLab"

        shareText = text
    }
}

// MARK: - Share Sheet

struct BrewJournalShareSheet: UIViewControllerRepresentable {
    let shareText: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("Complete Entry") {
    let entry = BrewJournalEntry(
        timestamp: Date(),
        grindType: .espresso,
        coffeeBean: CoffeeBeanInfo(
            name: "Ethiopia Yirgacheffe",
            roaster: "Blue Bottle",
            roastDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            roastLevel: .mediumLight,
            origin: "Yirgacheffe, Ethiopia",
            process: "Washed",
            notes: "Floral, citrus notes"
        ),
        brewParameters: BrewParameters(
            brewMethod: .espresso,
            doseIn: 18.0,
            yieldOut: 36.0,
            brewTime: 28.0,
            waterTemp: 93.0,
            grindSetting: "4.5"
        ),
        tastingNotes: TastingNotes(
            brewMethod: .espresso,
            overallRating: 4,
            tastingTags: ["Bright", "Fruity", "Balanced"],
            extractionNotes: "Great extraction with nice crema",
            extractionTime: 28.0,
            waterTemp: 93.0,
            doseIn: 18.0,
            yieldOut: 36.0
        ),
        notes: "Best shot I've pulled with this bean. Perfect temperature and time."
    )

    BrewJournalDetailView(baseEntry: entry, historyManager: CoffeeAnalysisHistoryManager())
}

#Preview("Minimal Entry") {
    let entry = BrewJournalEntry(
        timestamp: Date(),
        grindType: .filter,
        brewParameters: BrewParameters(brewMethod: .pourOver)
    )

    BrewJournalDetailView(baseEntry: entry, historyManager: CoffeeAnalysisHistoryManager())
}
