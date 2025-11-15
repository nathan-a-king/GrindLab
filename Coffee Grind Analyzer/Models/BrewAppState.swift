//
//  BrewAppState.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//

import Foundation
import Combine
import OSLog

// MARK: - Brew App State

class BrewAppState: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var selectedRecipe: Recipe?
    @Published var currentGrindAnalysis: SavedCoffeeAnalysis?

    private let persistenceQueue = DispatchQueue(label: "com.nateking.GrindLab.recipesPersistence", qos: .utility)
    private let recipeRepository = RecipeRepository()
    private let logger = Logger(subsystem: "com.nateking.GrindLab", category: "BrewAppState")

    init() {
        loadRecipes()
    }

    // MARK: - Recipe Management

    func selectRecipe(_ recipe: Recipe) {
        selectedRecipe = recipe
    }

    func addRecipe(_ recipe: Recipe) {
        recipes.append(recipe)
        persistRecipes()
    }

    func updateRecipe(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
            if selectedRecipe?.id == recipe.id {
                selectedRecipe = recipe
            }
            persistRecipes()
        }
    }

    func deleteRecipe(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        if selectedRecipe?.id == recipe.id {
            selectedRecipe = nil
        }
        persistRecipes()
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
        persistenceQueue.async { [weak self] in
            guard let self else { return }
            let loaded = self.recipeRepository.loadRecipes()
            DispatchQueue.main.async { [weak self] in
                self?.recipes = loaded
                if self?.selectedRecipe == nil {
                    self?.selectedRecipe = loaded.first
                }
            }
        }
    }

    private func persistRecipes() {
        let snapshot = recipes
        persistenceQueue.async { [weak self] in
            guard let self else { return }
            self.recipeRepository.persist(recipes: snapshot)
            self.logger.info("Persisted \(snapshot.count, privacy: .public) recipes")
        }
    }
}
