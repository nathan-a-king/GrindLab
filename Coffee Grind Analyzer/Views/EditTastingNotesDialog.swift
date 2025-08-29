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
            .scrollContentBackground(.hidden)
            .background(Color.brown.opacity(0.7))
            .navigationTitle(hasExistingNotes ? "Edit Tasting Notes" : "Add Tasting Notes")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
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
        Section {
            HStack {
                Text("Grind Type")
                    .foregroundColor(.white)
                Spacer()
                Text(savedAnalysis.results.grindType.displayName)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            HStack {
                Text("Date")
                    .foregroundColor(.white)
                Spacer()
                Text(savedAnalysis.savedDate, style: .date)
                    .foregroundColor(.white.opacity(0.8))
            }
        } header: {
            Text("Analysis Info")
                .foregroundColor(.white)
        }
        .listRowBackground(Color.brown.opacity(0.5))
    }
    
    private var removeNotesSection: some View {
        Section {
            Toggle("Remove Tasting Notes", isOn: $removeTastingNotes)
                .foregroundColor(.red)
        } footer: {
            Text("Toggle this to remove all tasting notes from this analysis")
                .foregroundColor(.white.opacity(0.7))
        }
        .listRowBackground(Color.brown.opacity(0.5))
    }
    
    private var tastingNotesForm: some View {
        Group {
            Section {
                HStack {
                    Text("Method")
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $brewMethod) {
                        ForEach(TastingNotes.BrewMethod.allCases, id: \.self) { method in
                            HStack {
                                Image(systemName: method.icon)
                                Text(method.rawValue)
                            }.tag(method)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .accentColor(.white)
                }
            } header: {
                Text("Brew Method")
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.brown.opacity(0.5))
            
            Section {
                HStack {
                    Text("How was it?")
                        .foregroundColor(.white)
                    Spacer()
                    StarRatingView(rating: $overallRating)
                }
            } header: {
                Text("Overall Rating")
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.brown.opacity(0.5))
            
            Section {
                TastingTagsView(selectedTags: $selectedTags)
            } header: {
                Text("Tasting Profile")
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.brown.opacity(0.5))
            
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Text("Extraction Time")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("30s", text: $extractionTime)
                            .frame(width: 60)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Water Temp")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("93°C", text: $waterTemp)
                            .frame(width: 60)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Dose In")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("18g", text: $doseIn)
                            .frame(width: 60)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Yield Out")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("36g", text: $yieldOut)
                            .frame(width: 60)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            )
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                    }
                }
            } header: {
                Text("Brewing Details")
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.brown.opacity(0.5))
            
            Section {
                TextField("How did it taste? Any issues?", text: $extractionNotes, axis: .vertical)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .foregroundColor(.white)
                    .lineLimit(2...4)
            } header: {
                Text("Extraction Notes")
                    .foregroundColor(.white)
            }
            .listRowBackground(Color.brown.opacity(0.5))
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
            sizeDistribution: ["Fines (<400μm)": 12.3, "Medium (600-1000μm)": 75.0, "Boulders (>1400μm)": 8.7],
            calibrationInfo: .defaultPreview
        )
        
        let sampleAnalysis = SavedCoffeeAnalysis(
            name: "Morning Filter",
            results: sampleResults,
            savedDate: Date(),
            notes: "Breville Smart Grinder Pro",
            originalImagePath: nil,
            processedImagePath: nil
        )
        
        EditTastingNotesDialog(
            savedAnalysis: sampleAnalysis,
            onSave: { _, _ in }
        )
    }
}
#endif
