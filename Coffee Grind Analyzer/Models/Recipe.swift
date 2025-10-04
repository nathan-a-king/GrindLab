//
//  Recipe.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//  Integrated from Brew Buddy
//

import Foundation

// MARK: - Brew Step Model

struct BrewStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var duration: TimeInterval   // seconds
    var note: String? = nil
}

// MARK: - Recipe Model

struct Recipe: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var coffeeGrams: Double
    var waterGrams: Double
    var grindNote: String?
    var steps: [BrewStep]
}

// MARK: - Default Recipes

extension Recipe {
    static let v60Basic = Recipe(
        name: "V60 – 1:16",
        coffeeGrams: 18,
        waterGrams: 288,
        grindNote: "Medium-fine (V60)",
        steps: [
            BrewStep(title: "Bloom", duration: 45, note: "40g water"),
            BrewStep(title: "Pour 1", duration: 30, note: "to 120g"),
            BrewStep(title: "Pour 2", duration: 30, note: "to 200g"),
            BrewStep(title: "Pour 3", duration: 45, note: "to 288g"),
            BrewStep(title: "Drawdown", duration: 45)
        ]
    )

    static let espresso = Recipe(
        name: "Espresso – 1:2",
        coffeeGrams: 18,
        waterGrams: 36,
        grindNote: "Fine (espresso)",
        steps: [
            BrewStep(title: "Preheat", duration: 10, note: "Flush grouphead"),
            BrewStep(title: "Extract", duration: 28, note: "25-30 seconds"),
            BrewStep(title: "Rest", duration: 5, note: "Let settle")
        ]
    )

    static let frenchPress = Recipe(
        name: "French Press – 1:15",
        coffeeGrams: 30,
        waterGrams: 450,
        grindNote: "Coarse",
        steps: [
            BrewStep(title: "Bloom", duration: 30, note: "Stir gently"),
            BrewStep(title: "Steep", duration: 210, note: "3.5 minutes"),
            BrewStep(title: "Press", duration: 30, note: "Slow and steady")
        ]
    )

    static let chemex = Recipe(
        name: "Chemex – 1:16",
        coffeeGrams: 25,
        waterGrams: 400,
        grindNote: "Medium-coarse",
        steps: [
            BrewStep(title: "Bloom", duration: 45, note: "50g water"),
            BrewStep(title: "Pour 1", duration: 30, note: "to 150g"),
            BrewStep(title: "Pour 2", duration: 30, note: "to 250g"),
            BrewStep(title: "Pour 3", duration: 45, note: "to 400g"),
            BrewStep(title: "Drawdown", duration: 60)
        ]
    )

    static let allDefaults: [Recipe] = [
        .v60Basic,
        .espresso,
        .frenchPress,
        .chemex
    ]
}
