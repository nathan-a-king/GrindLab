//
//  BrewAppState.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//

import Foundation
import Combine

// MARK: - Brew App State

class BrewAppState: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var selectedRecipe: Recipe?
    @Published var currentGrindAnalysis: SavedCoffeeAnalysis?

    private let recipesKey = "SavedRecipes"

    init() {
        loadRecipes()
    }

    // MARK: - Recipe Management

    func selectRecipe(_ recipe: Recipe) {
        selectedRecipe = recipe
    }

    func addRecipe(_ recipe: Recipe) {
        recipes.append(recipe)
        saveRecipes()
    }

    func updateRecipe(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
            if selectedRecipe?.id == recipe.id {
                selectedRecipe = recipe
            }
            saveRecipes()
        }
    }

    func deleteRecipe(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        if selectedRecipe?.id == recipe.id {
            selectedRecipe = nil
        }
        saveRecipes()
    }

    // MARK: - Grind Context

    func setGrindContext(_ analysis: SavedCoffeeAnalysis) {
        currentGrindAnalysis = analysis
    }

    func clearGrindContext() {
        currentGrindAnalysis = nil
    }

    // MARK: - Persistence

    private func loadRecipes() {
        guard let data = UserDefaults.standard.data(forKey: recipesKey),
              let decoded = try? JSONDecoder().decode([Recipe].self, from: data) else {
            // Load default recipes if none saved
            recipes = Recipe.allDefaults
            return
        }
        recipes = decoded
    }

    private func saveRecipes() {
        guard let encoded = try? JSONEncoder().encode(recipes) else { return }
        UserDefaults.standard.set(encoded, forKey: recipesKey)
    }
}
