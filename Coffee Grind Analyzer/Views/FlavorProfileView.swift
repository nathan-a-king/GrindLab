//
//  FlavorProfileView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/29/25.
//

import SwiftUI

struct FlavorProfileView: View {
    @Binding var flavorProfile: FlavorProfile?
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTaste: FlavorProfile.OverallTaste = .balanced
    @State private var selectedIssues: Set<FlavorProfile.FlavorIssue> = []
    @State private var selectedIntensity: FlavorProfile.TasteIntensity = .moderate
    @State private var notes: String = ""
    @State private var showingRecommendations = false
    
    let analysisResults: CoffeeAnalysisResults
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    overallTasteSection
                    flavorIssuesSection
                    intensitySection
                    notesSection
                    actionButtons
                }
                .padding()
            }
            .background(Color.brown.opacity(0.7))
            .navigationTitle("How did it taste?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.brown)
                }
            }
        }
        .sheet(isPresented: $showingRecommendations) {
            // Create a default profile if none exists (shouldn't happen but safe fallback)
            let profileToUse = flavorProfile ?? FlavorProfile(
                overallTaste: .balanced,
                flavorIssues: [],
                intensity: .moderate,
                notes: nil,
                timestamp: Date()
            )
            
            ZStack {
                Color.brown.opacity(0.25)
                    .ignoresSafeArea()
                
                RecommendationView(
                    analysisResults: analysisResults,
                    flavorProfile: profileToUse
                )
            }
            .onAppear {
                print("🎭 Sheet appeared")
                print("   - Using profile with taste: \(profileToUse.overallTaste.rawValue)")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(.brown)
                Text("Taste Feedback")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text("Tell us how your coffee tasted to get personalized brewing recommendations based on your grind analysis.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .background(Color.brown.opacity(0.3))
        .cornerRadius(12)
    }
    
    private var overallTasteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Taste")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(FlavorProfile.OverallTaste.allCases, id: \.self) { taste in
                    TasteOptionCard(
                        taste: taste,
                        isSelected: selectedTaste == taste,
                        action: { selectedTaste = taste }
                    )
                }
            }
        }
    }
    
    private var flavorIssuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Specific Issues (Optional)")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Select any specific flavors you noticed")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(FlavorProfile.FlavorIssue.allCases, id: \.self) { issue in
                    FlavorIssueChip(
                        issue: issue,
                        isSelected: selectedIssues.contains(issue),
                        action: {
                            if selectedIssues.contains(issue) {
                                selectedIssues.remove(issue)
                            } else {
                                selectedIssues.insert(issue)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intensity")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                ForEach(FlavorProfile.TasteIntensity.allCases, id: \.self) { intensity in
                    IntensityButton(
                        intensity: intensity,
                        isSelected: selectedIntensity == intensity,
                        action: { selectedIntensity = intensity }
                    )
                }
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional Notes (Optional)")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("Any other observations about the coffee...", text: $notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
                .background(Color.white.opacity(0.9))
                .cornerRadius(8)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: generateRecommendations) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                    Text("Get Brewing Recommendations")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brown)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: skipRecommendations) {
                Text("Skip - Save Analysis Only")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private func generateRecommendations() {
        print("🚀 FlavorProfileView generateRecommendations() called")
        
        let profile = FlavorProfile(
            overallTaste: selectedTaste,
            flavorIssues: Array(selectedIssues),
            intensity: selectedIntensity,
            notes: notes.isEmpty ? nil : notes,
            timestamp: Date()
        )
        
        print("   - Created profile with taste: \(profile.overallTaste.rawValue)")
        
        // Set profile first, then trigger presentation
        flavorProfile = profile
        
        // Small delay to ensure state is updated
        DispatchQueue.main.async {
            print("   - Setting showingRecommendations to true")
            self.showingRecommendations = true
        }
    }
    
    private func skipRecommendations() {
        flavorProfile = nil
        dismiss()
    }
}

// MARK: - Supporting Views

struct TasteOptionCard: View {
    let taste: FlavorProfile.OverallTaste
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(taste.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                
                Text(taste.description)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isSelected ? Color.brown.opacity(0.4) : Color.brown.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.brown : Color.clear, lineWidth: 2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FlavorIssueChip: View {
    let issue: FlavorProfile.FlavorIssue
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(issue.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.brown.opacity(0.5) : Color.brown.opacity(0.2))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct IntensityButton: View {
    let intensity: FlavorProfile.TasteIntensity
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(intensity.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.brown.opacity(0.5) : Color.brown.opacity(0.2))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FlavorProfileView(
        flavorProfile: .constant(nil),
        analysisResults: CoffeeAnalysisResults(
            uniformityScore: 75.0,
            averageSize: 650.0,
            medianSize: 620.0,
            standardDeviation: 180.0,
            finesPercentage: 15.0,
            bouldersPercentage: 8.0,
            particleCount: 342,
            particles: [],
            confidence: 85.0,
            image: nil,
            processedImage: nil,
            grindType: .filter,
            timestamp: Date(),
            calibrationFactor: 150.0
        )
    )
}