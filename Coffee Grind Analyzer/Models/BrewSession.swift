//
//  BrewSession.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//

import Foundation

// MARK: - Unified Brew Session Model
// Note: Codable/Equatable conformance removed until SavedCoffeeAnalysis conforms to these protocols

struct BrewSession: Identifiable {
    let id: UUID

    // From GrindLab - the grind analysis
    let grindAnalysis: SavedCoffeeAnalysis

    // From Brew Buddy - the recipe used
    var selectedRecipe: Recipe?
    var brewStartedAt: Date?
    var brewCompletedAt: Date?

    // From GrindLab - tasting notes (already exists in CoffeeAnalysisResults)
    // We access via grindAnalysis.results.tastingNotes

    let createdAt: Date

    init(grindAnalysis: SavedCoffeeAnalysis, selectedRecipe: Recipe? = nil) {
        self.id = UUID()
        self.grindAnalysis = grindAnalysis
        self.selectedRecipe = selectedRecipe
        self.brewStartedAt = nil
        self.brewCompletedAt = nil
        self.createdAt = Date()
    }

    var hasBrewData: Bool {
        selectedRecipe != nil
    }

    var hasTastingNotes: Bool {
        grindAnalysis.results.tastingNotes != nil
    }

    var isComplete: Bool {
        hasBrewData && hasTastingNotes
    }
}
