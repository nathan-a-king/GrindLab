//
//  RecommendationView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/29/25.
//

import SwiftUI

struct RecommendationView: View {
    let analysisResults: CoffeeAnalysisResults
    let flavorProfile: FlavorProfile
    @Environment(\.dismiss) private var dismiss
    
    @State private var recommendations: [BrewingRecommendation] = []
    @State private var isLoading = true
    
    init(analysisResults: CoffeeAnalysisResults, flavorProfile: FlavorProfile) {
        self.analysisResults = analysisResults
        self.flavorProfile = flavorProfile
        
        print("🔵 RecommendationView INIT called")
        print("   - Analysis avg size: \(analysisResults.averageSize)")
        print("   - Flavor profile: \(flavorProfile.overallTaste.rawValue)")
        
        // Set appearance for navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.brown.opacity(0.1))
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        let _ = print("🟢 RecommendationView BODY called")
        let _ = print("   - isLoading: \(isLoading)")
        let _ = print("   - recommendations count: \(recommendations.count)")
        
        NavigationView {
            ZStack {
                // Much darker background color that's always visible
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()
                    .onAppear {
                        print("🟤 Brown background appeared")
                    }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                            .onAppear {
                                print("📝 Header section appeared")
                            }
                        
                        if isLoading {
                            ProgressView("Analyzing your coffee...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.white)
                                .padding()
                                .onAppear {
                                    print("⏳ Loading spinner appeared")
                                }
                        } else if !recommendations.isEmpty {
                            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                                RecommendationCard(
                                    recommendation: recommendation,
                                    isPrimary: index == 0
                                )
                            }
                            .onAppear {
                                print("✅ Recommendations list appeared with \(recommendations.count) items")
                            }
                        } else {
                            Text("No recommendations available")
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                                .onAppear {
                                    print("❌ No recommendations text appeared")
                                }
                        }
                        
                        grindAnalysisSection
                    }
                    .padding()
                }
            }
            .background(Color.brown.opacity(0.7))
            .navigationTitle("Brewing Recommendations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.brown)
                }
            }
        }
        .onAppear {
            print("🎯 RecommendationView onAppear triggered")
            print("   - Current recommendations count: \(recommendations.count)")
            // Generate recommendations immediately
            if recommendations.isEmpty {
                print("   - Generating recommendations...")
                generateRecommendations()
            } else {
                print("   - Recommendations already exist, skipping generation")
            }
        }
        .task {
            print("📌 RecommendationView task triggered")
            // Also generate as a task to ensure it runs
            if recommendations.isEmpty {
                print("   - Task: Generating recommendations...")
                generateRecommendations()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                VStack(alignment: .leading) {
                    Text("Coffee Compass")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Based on your taste feedback and grind analysis")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            TasteProfileSummary(flavorProfile: flavorProfile)
        }
    }
    
    private var grindAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Grind Analysis")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                GrindMetricCard(
                    title: "Average Size",
                    value: "\(String(format: "%.0f", analysisResults.averageSize))μm",
                    target: analysisResults.grindType.targetSizeRange,
                    color: grindSizeColor
                )
                
                GrindMetricCard(
                    title: "Uniformity",
                    value: "\(String(format: "%.1f", analysisResults.uniformityScore))%",
                    target: analysisResults.uniformityGrade,
                    color: analysisResults.uniformityColor
                )
                
                GrindMetricCard(
                    title: "Fines",
                    value: "\(String(format: "%.1f", analysisResults.finesPercentage))%",
                    target: finesStatus,
                    color: finesColor
                )
                
                GrindMetricCard(
                    title: "Particles",
                    value: "\(analysisResults.particleCount)",
                    target: "Detected",
                    color: .blue
                )
            }
        }
    }
    
    
    // MARK: - Computed Properties
    
    private var grindSizeColor: Color {
        let targetRange = analysisResults.grindType.targetSizeMicrons
        let avgSize = analysisResults.averageSize
        
        if targetRange.contains(avgSize) {
            return .green
        } else if avgSize < targetRange.lowerBound * 0.8 || avgSize > targetRange.upperBound * 1.2 {
            return .red
        } else {
            return .orange
        }
    }
    
    private var finesColor: Color {
        let idealRange = analysisResults.grindType.idealFinesPercentage
        let actualFines = analysisResults.finesPercentage
        
        if idealRange.contains(actualFines) {
            return .green
        } else if actualFines > idealRange.upperBound * 1.3 {
            return .red
        } else {
            return .orange
        }
    }
    
    private var finesStatus: String {
        let idealRange = analysisResults.grindType.idealFinesPercentage
        let actualFines = analysisResults.finesPercentage
        
        if idealRange.contains(actualFines) {
            return "Good"
        } else if actualFines > idealRange.upperBound {
            return "High"
        } else {
            return "Low"
        }
    }
    
    // MARK: - Actions
    
    private func generateRecommendations() {
        print("🔨 generateRecommendations() called")
        print("   - Starting with isLoading: \(isLoading)")
        
        // Generate recommendations synchronously but quickly
        let generatedRecs = CoffeeCompass.generateRecommendations(
            from: analysisResults,
            flavorProfile: flavorProfile
        )
        
        print("   - Generated \(generatedRecs.count) recommendations")
        
        recommendations = generatedRecs
        isLoading = false
        
        print("   - Finished with isLoading: \(isLoading)")
        print("   - Final recommendations count: \(recommendations.count)")
    }
    
}

// MARK: - Supporting Views

struct RecommendationCard: View {
    let recommendation: BrewingRecommendation
    let isPrimary: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack {
                    Image(systemName: recommendation.primaryAction.icon)
                        .foregroundColor(isPrimary ? .white : .brown)
                    Text(isPrimary ? "Primary Recommendation" : "Additional Suggestion")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isPrimary ? .white : .brown)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isPrimary ? Color.brown : Color.brown.opacity(0.2))
                .cornerRadius(6)
                
                Spacer()
                
                ConfidenceBadge(confidence: recommendation.confidence)
            }
            
            Text(recommendation.primaryAction.displayText)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(recommendation.reasoning)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            if !recommendation.secondaryActions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Also try:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))
                    
                    ForEach(recommendation.secondaryActions, id: \.displayText) { action in
                        HStack {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text(action.displayText)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.green)
                Text(recommendation.expectedImprovement)
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.brown.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPrimary ? Color.brown : Color.clear, lineWidth: isPrimary ? 2 : 0)
        )
    }
}

struct TasteProfileSummary: View {
    let flavorProfile: FlavorProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: tasteIcon)
                    .foregroundColor(tasteColor)
                Text(flavorProfile.overallTaste.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            
            if !flavorProfile.flavorIssues.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(flavorProfile.flavorIssues, id: \.self) { issue in
                            Text(issue.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.brown.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding()
        .background(Color.brown.opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }
    
    private var tasteIcon: String {
        switch flavorProfile.overallTaste {
        case .balanced:
            return "checkmark.circle.fill"
        case .underExtracted:
            return "minus.circle.fill"
        case .overExtracted:
            return "plus.circle.fill"
        case .weak:
            return "drop.circle.fill"
        case .harsh:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var tasteColor: Color {
        switch flavorProfile.overallTaste {
        case .balanced:
            return .green
        case .underExtracted:
            return .orange
        case .overExtracted:
            return .red
        case .weak:
            return .blue
        case .harsh:
            return .red
        }
    }
}

struct GrindMetricCard: View {
    let title: String
    let value: String
    let target: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(target)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.brown.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var body: some View {
        Text("\(String(format: "%.0f", confidence))%")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(confidenceColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(confidenceColor.opacity(0.2))
            .cornerRadius(4)
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 80...:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
}


#Preview {
    RecommendationView(
        analysisResults: CoffeeAnalysisResults(
            uniformityScore: 65.0,
            averageSize: 450.0,
            medianSize: 420.0,
            standardDeviation: 220.0,
            finesPercentage: 25.0,
            bouldersPercentage: 12.0,
            particleCount: 156,
            particles: [],
            confidence: 72.0,
            image: nil,
            processedImage: nil,
            grindType: .espresso,
            timestamp: Date(),
            calibrationInfo: CalibrationInfo.defaultPreview
        ),
        flavorProfile: FlavorProfile(
            overallTaste: .underExtracted,
            flavorIssues: [.sour, .weak],
            intensity: .mild,
            notes: "Coffee tastes quite sour and lacks body",
            timestamp: Date()
        )
    )
}