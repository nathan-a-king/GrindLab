//
//  EditTastingNotesDialog.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/22/25.
//

import SwiftUI

struct EditTastingNotesDialog: View {
    let savedAnalysis: SavedCoffeeAnalysis
    let onSave: (SavedCoffeeAnalysis, TastingNotes?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var brewMethod: TastingNotes.BrewMethod
    @State private var overallRating: Int
    @State private var selectedTags: Set<String>
    @State private var extractionNotes: String
    @State private var extractionTime: String
    @State private var waterTemp: String
    @State private var doseIn: String
    @State private var yieldOut: String
    @State private var removeTastingNotes: Bool = false
    
    init(savedAnalysis: SavedCoffeeAnalysis, onSave: @escaping (SavedCoffeeAnalysis, TastingNotes?) -> Void) {
        self.savedAnalysis = savedAnalysis
        self.onSave = onSave
        
        // Initialize state from existing tasting notes
        if let existing = savedAnalysis.results.tastingNotes {
            _brewMethod = State(initialValue: existing.brewMethod)
            _overallRating = State(initialValue: existing.overallRating)
            _selectedTags = State(initialValue: Set(existing.tastingTags))
            _extractionNotes = State(initialValue: existing.extractionNotes ?? "")
            _extractionTime = State(initialValue: existing.extractionTime != nil ? String(format: "%.0f", existing.extractionTime!) : "")
            _waterTemp = State(initialValue: existing.waterTemp != nil ? String(format: "%.0f", existing.waterTemp!) : "")
            _doseIn = State(initialValue: existing.doseIn != nil ? String(format: "%.1f", existing.doseIn!) : "")
            _yieldOut = State(initialValue: existing.yieldOut != nil ? String(format: "%.1f", existing.yieldOut!) : "")
        } else {
            // Initialize with defaults for new tasting notes
            let defaultMethod: TastingNotes.BrewMethod = {
                switch savedAnalysis.results.grindType {
                case .espresso: return .espresso
                case .filter: return .pourOver
                case .frenchPress: return .frenchPress
                case .coldBrew: return .coldBrew
                }
            }()
            
            _brewMethod = State(initialValue: defaultMethod)
            _overallRating = State(initialValue: 3)
            _selectedTags = State(initialValue: Set<String>())
            _extractionNotes = State(initialValue: "")
            _extractionTime = State(initialValue: "")
            _waterTemp = State(initialValue: "")
            _doseIn = State(initialValue: "")
            _yieldOut = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                analysisInfoSection
                
                if savedAnalysis.results.tastingNotes != nil {
                    removeNotesSection
                }
                
                if !removeTastingNotes {
                    tastingNotesForm
                }
            }
            .navigationTitle(hasExistingNotes ? "Edit Tasting Notes" : "Add Tasting Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTastingNotes()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var hasExistingNotes: Bool {
        return savedAnalysis.results.tastingNotes != nil
    }
    
    private var analysisInfoSection: some View {
        Section("Analysis Info") {
            HStack {
                Text("Grind Type")
                Spacer()
                Text(savedAnalysis.results.grindType.displayName)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Uniformity Score")
                Spacer()
                Text("\(Int(savedAnalysis.results.uniformityScore))%")
                    .foregroundColor(savedAnalysis.results.uniformityColor)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("Date")
                Spacer()
                Text(savedAnalysis.savedDate, style: .date)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var removeNotesSection: some View {
        Section {
            Toggle("Remove Tasting Notes", isOn: $removeTastingNotes)
                .foregroundColor(.red)
        } footer: {
            Text("Toggle this to remove all tasting notes from this analysis")
        }
    }
    
    private var tastingNotesForm: some View {
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
    
    private func saveTastingNotes() {
        let tastingNotes: TastingNotes?
        
        if removeTastingNotes {
            tastingNotes = nil
        } else {
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
        
        onSave(savedAnalysis, tastingNotes)
        dismiss()
    }
}

// MARK: - Preview

#if DEBUG
struct EditTastingNotesDialog_Previews: PreviewProvider {
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
            sizeDistribution: ["Fines (<400μm)": 12.3, "Medium (600-1000μm)": 75.0, "Boulders (>1400μm)": 8.7]
        )
        
        let sampleAnalysis = SavedCoffeeAnalysis(
            name: "Morning Filter",
            results: sampleResults,
            savedDate: Date(),
            notes: "Breville Smart Grinder Pro"
        )
        
        EditTastingNotesDialog(
            savedAnalysis: sampleAnalysis,
            onSave: { _, _ in }
        )
    }
}
#endif
