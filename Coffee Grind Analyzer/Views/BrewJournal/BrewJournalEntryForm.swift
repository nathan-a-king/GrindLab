//
//  BrewJournalEntryForm.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 11/8/25.
//

import SwiftUI

struct BrewJournalEntryForm: View {
    let entry: BrewJournalEntry?
    let onSave: (BrewJournalEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    // Coffee Bean Info
    @State private var beanName: String
    @State private var roaster: String
    @State private var roastDate: Date
    @State private var roastLevel: RoastLevel?
    @State private var origin: String
    @State private var process: String
    @State private var beanNotes: String

    // Grind Info
    @State private var grindType: CoffeeGrindType
    @State private var grindSetting: String
    @State private var linkedAnalysisId: UUID?

    // Brew Parameters
    @State private var brewMethod: TastingNotes.BrewMethod
    @State private var doseIn: String
    @State private var yieldOut: String
    @State private var brewTime: String
    @State private var waterTemp: String

    // Tasting Notes
    @State private var hasRating: Bool
    @State private var overallRating: Int
    @State private var selectedTags: Set<String>
    @State private var extractionNotes: String

    // General
    @State private var generalNotes: String
    @State private var timestamp: Date

    // UI State
    @State private var showAnalysisPicker = false

    init(entry: BrewJournalEntry? = nil, onSave: @escaping (BrewJournalEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave

        if let existing = entry {
            // Edit mode - load existing entry
            _beanName = State(initialValue: existing.coffeeBean?.name ?? "")
            _roaster = State(initialValue: existing.coffeeBean?.roaster ?? "")
            _roastDate = State(initialValue: existing.coffeeBean?.roastDate ?? Date())
            _roastLevel = State(initialValue: existing.coffeeBean?.roastLevel)
            _origin = State(initialValue: existing.coffeeBean?.origin ?? "")
            _process = State(initialValue: existing.coffeeBean?.process ?? "")
            _beanNotes = State(initialValue: existing.coffeeBean?.notes ?? "")

            _grindType = State(initialValue: existing.grindType)
            _grindSetting = State(initialValue: existing.brewParameters.grindSetting ?? "")
            _linkedAnalysisId = State(initialValue: existing.linkedAnalysisId)

            _brewMethod = State(initialValue: existing.brewParameters.brewMethod)
            _doseIn = State(initialValue: existing.brewParameters.doseIn != nil ? String(format: "%.1f", existing.brewParameters.doseIn!) : "")
            _yieldOut = State(initialValue: existing.brewParameters.yieldOut != nil ? String(format: "%.1f", existing.brewParameters.yieldOut!) : "")
            _brewTime = State(initialValue: existing.brewParameters.brewTime != nil ? String(format: "%.0f", existing.brewParameters.brewTime!) : "")
            _waterTemp = State(initialValue: existing.brewParameters.waterTemp != nil ? String(format: "%.0f", existing.brewParameters.waterTemp!) : "")

            _hasRating = State(initialValue: existing.tastingNotes != nil)
            _overallRating = State(initialValue: existing.tastingNotes?.overallRating ?? 3)
            _selectedTags = State(initialValue: Set(existing.tastingNotes?.tastingTags ?? []))
            _extractionNotes = State(initialValue: existing.tastingNotes?.extractionNotes ?? "")

            _generalNotes = State(initialValue: existing.notes ?? "")
            _timestamp = State(initialValue: existing.timestamp)
        } else {
            // Create mode - use defaults
            _beanName = State(initialValue: "")
            _roaster = State(initialValue: "")
            _roastDate = State(initialValue: Date())
            _roastLevel = State(initialValue: nil)
            _origin = State(initialValue: "")
            _process = State(initialValue: "")
            _beanNotes = State(initialValue: "")

            _grindType = State(initialValue: .espresso)
            _grindSetting = State(initialValue: "")
            _linkedAnalysisId = State(initialValue: nil)

            _brewMethod = State(initialValue: .espresso)
            _doseIn = State(initialValue: "")
            _yieldOut = State(initialValue: "")
            _brewTime = State(initialValue: "")
            _waterTemp = State(initialValue: "")

            _hasRating = State(initialValue: false)
            _overallRating = State(initialValue: 3)
            _selectedTags = State(initialValue: Set<String>())
            _extractionNotes = State(initialValue: "")

            _generalNotes = State(initialValue: "")
            _timestamp = State(initialValue: Date())
        }
    }

    var body: some View {
        ZStack {
            Color.brown.opacity(0.7)
                .ignoresSafeArea()

            NavigationStack {
                Form {
                    coffeeInfoSection
                    grindSection
                    brewParametersSection
                    tastingNotesSection
                    generalNotesSection
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(isEditMode ? "Edit Brew Log" : "New Brew Log")
                .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Form Sections

    private var coffeeInfoSection: some View {
        Section {
            TextField("Bean Name", text: $beanName)
                .foregroundColor(.white)

            TextField("Roaster", text: $roaster)
                .foregroundColor(.white)

            DatePicker("Roast Date", selection: $roastDate, displayedComponents: .date)
                .foregroundColor(.white)

            Picker("Roast Level", selection: $roastLevel) {
                Text("Not Specified").tag(nil as RoastLevel?)
                ForEach(RoastLevel.allCases, id: \.self) { level in
                    HStack {
                        Image(systemName: level.icon)
                        Text(level.rawValue)
                    }.tag(level as RoastLevel?)
                }
            }
            .foregroundColor(.white)

            TextField("Origin", text: $origin)
                .foregroundColor(.white)

            TextField("Process (Washed, Natural, etc.)", text: $process)
                .foregroundColor(.white)

            TextField("Bean Notes", text: $beanNotes, axis: .vertical)
                .lineLimit(2...4)
                .foregroundColor(.white)
        } header: {
            Text("Coffee Bean Info")
                .foregroundColor(.white)
        } footer: {
            Text("Optional: Add details about the coffee beans used")
                .foregroundColor(.white.opacity(0.7))
        }
        .listRowBackground(Color.brown.opacity(0.5))
    }

    private var grindSection: some View {
        Section {
            Picker("Grind Type", selection: $grindType) {
                ForEach(CoffeeGrindType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .foregroundColor(.white)
            .onChange(of: grindType) { oldValue, newValue in
                // Auto-update brew method when grind type changes
                brewMethod = defaultBrewMethod(for: newValue)
            }

            TextField("Grind Setting (e.g., 4.5, Medium-Fine)", text: $grindSetting)
                .foregroundColor(.white)

            if linkedAnalysisId != nil {
                HStack {
                    Text("Linked to Analysis")
                        .foregroundColor(.white)
                    Spacer()
                    Button("Change") {
                        showAnalysisPicker = true
                    }
                    .foregroundColor(.blue)
                }
            } else {
                Button {
                    showAnalysisPicker = true
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text("Link to Analysis")
                    }
                    .foregroundColor(.blue)
                }
            }
        } header: {
            Text("Grind")
                .foregroundColor(.white)
        }
        .listRowBackground(Color.brown.opacity(0.5))
    }

    private var brewParametersSection: some View {
        Section {
            Picker("Brew Method", selection: $brewMethod) {
                ForEach(TastingNotes.BrewMethod.allCases, id: \.self) { method in
                    HStack {
                        Image(systemName: method.icon)
                        Text(method.rawValue)
                    }.tag(method)
                }
            }
            .foregroundColor(.white)

            HStack {
                Text("Dose In (g)")
                    .foregroundColor(.white)
                Spacer()
                TextField("18.0", text: $doseIn)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.white)
                    .frame(width: 80)
            }

            HStack {
                Text("Yield Out (g/ml)")
                    .foregroundColor(.white)
                Spacer()
                TextField("36.0", text: $yieldOut)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.white)
                    .frame(width: 80)
            }

            if let ratio = calculateRatio() {
                HStack {
                    Text("Ratio")
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(ratio)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            HStack {
                Text("Brew Time (s)")
                    .foregroundColor(.white)
                Spacer()
                TextField("28", text: $brewTime)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.white)
                    .frame(width: 80)
            }

            HStack {
                Text("Water Temp (°C)")
                    .foregroundColor(.white)
                Spacer()
                TextField("93", text: $waterTemp)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.white)
                    .frame(width: 80)
            }
        } header: {
            Text("Brew Parameters")
                .foregroundColor(.white)
        } footer: {
            Text("Optional: Add brewing details")
                .foregroundColor(.white.opacity(0.7))
        }
        .listRowBackground(Color.brown.opacity(0.5))
    }

    private var tastingNotesSection: some View {
        Section {
            Toggle("Add Rating & Tasting Notes", isOn: $hasRating)
                .foregroundColor(.white)

            if hasRating {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rating")
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= overallRating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    overallRating = star
                                }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tasting Tags")
                        .foregroundColor(.white)

                    FlowLayout(spacing: 8) {
                        ForEach(TastingNotes.availableTags, id: \.self) { tag in
                            BrewTagButton(
                                tag: tag,
                                isSelected: selectedTags.contains(tag),
                                action: { toggleTag(tag) }
                            )
                        }
                    }
                }

                TextField("Extraction Notes", text: $extractionNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundColor(.white)
            }
        } header: {
            Text("Tasting Notes")
                .foregroundColor(.white)
        }
        .listRowBackground(Color.brown.opacity(0.5))
    }

    private var generalNotesSection: some View {
        Section {
            DatePicker("Brew Time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                .foregroundColor(.white)

            TextField("General Notes", text: $generalNotes, axis: .vertical)
                .lineLimit(3...6)
                .foregroundColor(.white)
        } header: {
            Text("Additional Info")
                .foregroundColor(.white)
        }
        .listRowBackground(Color.brown.opacity(0.5))
    }

    // MARK: - Helper Properties

    private var isEditMode: Bool {
        entry != nil
    }

    private var canSave: Bool {
        // At minimum, we need a grind type and brew method
        return true
    }

    // MARK: - Helper Methods

    private func defaultBrewMethod(for grindType: CoffeeGrindType) -> TastingNotes.BrewMethod {
        switch grindType {
        case .espresso:
            return .espresso
        case .filter:
            return .pourOver
        case .frenchPress:
            return .frenchPress
        case .coldBrew:
            return .coldBrew
        }
    }

    private func calculateRatio() -> String? {
        guard let dose = Double(doseIn), let yield = Double(yieldOut), dose > 0 else {
            return nil
        }
        let ratio = yield / dose
        return String(format: "1:%.1f", ratio)
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func saveEntry() {
        // Build coffee bean info (only if any field is filled)
        var beanInfo: CoffeeBeanInfo? = nil
        if !beanName.isEmpty || !roaster.isEmpty {
            beanInfo = CoffeeBeanInfo(
                name: beanName.isEmpty ? "Unknown" : beanName,
                roaster: roaster.isEmpty ? nil : roaster,
                roastDate: roastDate,
                roastLevel: roastLevel,
                origin: origin.isEmpty ? nil : origin,
                process: process.isEmpty ? nil : process,
                notes: beanNotes.isEmpty ? nil : beanNotes
            )
        }

        // Build brew parameters
        let brewParams = BrewParameters(
            brewMethod: brewMethod,
            doseIn: Double(doseIn),
            yieldOut: Double(yieldOut),
            brewTime: Double(brewTime),
            waterTemp: Double(waterTemp),
            grindSetting: grindSetting.isEmpty ? nil : grindSetting
        )

        // Build tasting notes (only if rating enabled)
        var tastingNotes: TastingNotes? = nil
        if hasRating {
            tastingNotes = TastingNotes(
                brewMethod: brewMethod,
                overallRating: overallRating,
                tastingTags: Array(selectedTags),
                extractionNotes: extractionNotes.isEmpty ? nil : extractionNotes,
                extractionTime: nil,
                waterTemp: nil,
                doseIn: nil,
                yieldOut: nil
            )
        }

        // Build the entry
        let newEntry = BrewJournalEntry(
            id: entry?.id ?? UUID(),
            timestamp: timestamp,
            grindType: grindType,
            coffeeBean: beanInfo,
            brewParameters: brewParams,
            tastingNotes: tastingNotes,
            linkedAnalysisId: linkedAnalysisId,
            notes: generalNotes.isEmpty ? nil : generalNotes
        )

        onSave(newEntry)
        dismiss()
    }
}

// MARK: - Supporting Views

private struct BrewTagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorForTag(tag).opacity(isSelected ? 0.6 : 0.4))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Simple flow layout for tags
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))

                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    BrewJournalEntryForm { entry in
        print("Saved: \(entry)")
    }
}
