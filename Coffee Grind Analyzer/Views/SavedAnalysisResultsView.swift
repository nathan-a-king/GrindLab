//
//  SavedAnalysisResultsView.swift
//  Coffee Grind Analyzer
//
//  Created by Claude on 8/26/25.
//

import SwiftUI

struct SavedAnalysisResultsView: View {
    let savedAnalysis: SavedCoffeeAnalysis
    let historyManager: CoffeeAnalysisHistoryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var showingEditTastingNotes = false
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Overview Tab
                overviewTab
                    .tabItem {
                        Image(systemName: "chart.pie")
                        Text("Overview")
                    }
                    .tag(0)
                
                // Details Tab
                detailsTab
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Details")
                    }
                    .tag(1)
                
                // Distribution Tab
                distributionTab
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Distribution")
                    }
                    .tag(2)
                
                // Images Tab
                imagesTab
                    .tabItem {
                        Image(systemName: "photo")
                        Text("Images")
                    }
                    .tag(3)
            }
            .navigationTitle(savedAnalysis.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Tasting Notes") {
                            showingEditTastingNotes = true
                        }
                        
                        Button("Delete Analysis", role: .destructive) {
                            historyManager.deleteAnalysis(withId: savedAnalysis.id)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditTastingNotes) {
            EditTastingNotesDialog(savedAnalysis: savedAnalysis) { updatedAnalysis, tastingNotes in
                historyManager.updateAnalysisTastingNotes(analysisId: updatedAnalysis.id, tastingNotes: tastingNotes)
            }
        }
    }
    
    // MARK: - Tab Views
    
    private var overviewTab: some View {
        ResultsView(results: savedAnalysis.results)
            .navigationBarHidden(true)
    }
    
    private var detailsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                detailSection("Particle Statistics") {
                    VStack(spacing: 8) {
                        DetailRow(label: "Average Size", value: String(format: "%.1f μm", savedAnalysis.results.averageSize))
                        DetailRow(label: "Median Size", value: String(format: "%.1f μm", savedAnalysis.results.medianSize))
                        DetailRow(label: "Standard Deviation", value: String(format: "%.1f μm", savedAnalysis.results.standardDeviation))
                        DetailRow(label: "Coefficient of Variation", value: String(format: "%.1f%%", (savedAnalysis.results.standardDeviation / savedAnalysis.results.averageSize) * 100))
                    }
                }
                
                detailSection("Analysis Info") {
                    VStack(spacing: 8) {
                        DetailRow(label: "Particles Detected", value: "\(savedAnalysis.results.particleCount)")
                        DetailRow(label: "Confidence Level", value: String(format: "%.0f%%", savedAnalysis.results.confidence))
                        DetailRow(label: "Analysis Date", value: savedAnalysis.savedDate.formatted(date: .abbreviated, time: .shortened))
                        DetailRow(label: "Grind Type", value: savedAnalysis.results.grindType.displayName)
                    }
                }
                
                if let notes = savedAnalysis.notes {
                    detailSection("Notes") {
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .background(Color.brown.opacity(0.25))
    }
    
    private var distributionTab: some View {
        ResultsView(results: savedAnalysis.results)
            .navigationBarHidden(true)
    }
    
    private var imagesTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let originalImage = loadOriginalImage() {
                    imageSection(
                        title: "Original Image",
                        image: originalImage,
                        subtitle: "Captured photo"
                    )
                }
                
                if let processedImage = loadProcessedImage() {
                    imageSection(
                        title: "Processed Image", 
                        image: processedImage,
                        subtitle: "With particle detection overlay"
                    )
                }
                
                
                if loadOriginalImage() == nil && loadProcessedImage() == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No images available")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Images were not saved with this analysis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .padding()
        }
        .background(Color.white)
    }
    
    // MARK: - Helper Views
    
    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            content()
        }
    }
    
    private func imageSection(title: String, image: UIImage, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(12)
                .shadow(radius: 4)
        }
    }
    
    // MARK: - Image Loading
    
    private func loadOriginalImage() -> UIImage? {
        guard let path = savedAnalysis.originalImagePath else { return nil }
        return historyManager.loadImage(from: path)
    }
    
    private func loadProcessedImage() -> UIImage? {
        guard let path = savedAnalysis.processedImagePath else { return nil }
        return historyManager.loadImage(from: path)
    }
}