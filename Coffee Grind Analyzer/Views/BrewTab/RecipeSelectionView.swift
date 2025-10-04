//
//  RecipeSelectionView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//

import SwiftUI

struct RecipeSelectionView: View {
    @EnvironmentObject var brewState: BrewAppState
    @Binding var showingTimer: Bool
    @State private var showingNew = false
    @State private var editingRecipe: Recipe?
    @State private var newRecipe = Recipe.v60Basic

    var body: some View {
        ZStack {
            Color.brown.opacity(0.7)
                .ignoresSafeArea()

            if brewState.recipes.isEmpty {
                emptyStateView
            } else {
                List {
                    if let grindAnalysis = brewState.currentGrindAnalysis {
                        grindContextCard(grindAnalysis)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }

                    ForEach(brewState.recipes) { recipe in
                        recipeCard(recipe)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    brewState.deleteRecipe(recipe)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Select Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                // Create a fresh recipe with a new ID each time
                newRecipe = Recipe(
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
                showingNew = true
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showingNew) {
            RecipeEditor(recipe: $newRecipe) { created in
                brewState.addRecipe(created)
            }
        }
        .sheet(item: $editingRecipe) { recipe in
            RecipeEditorWrapper(recipe: recipe) { updated in
                brewState.updateRecipe(updated)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.6))

            Text("No Recipes")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Tap + to create your first brew recipe")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private func grindContextCard(_ analysis: SavedCoffeeAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.white.opacity(0.8))
                Text("Based on your grind analysis")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grind Type")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(analysis.results.grindType.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Uniformity")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(analysis.results.uniformityScore))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(analysis.results.uniformityColor)
                }

                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Size")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(Int(analysis.results.averageSize))μm")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    private func recipeCard(_ recipe: Recipe) -> some View {
        Button {
            // Haptic feedback
            #if canImport(UIKit)
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            #endif

            brewState.selectRecipe(recipe)
            showingTimer = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(recipe.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    if brewState.selectedRecipe?.id == recipe.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(Int(recipe.coffeeGrams))g")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(Int(recipe.waterGrams))g")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    if let grindNote = recipe.grindNote {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.grid.cross.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text(grindNote)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }

                HStack {
                    Text("\(recipe.steps.count) steps")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    Button {
                        // Select the recipe being edited
                        brewState.selectRecipe(recipe)
                        editingRecipe = recipe
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brown.opacity(brewState.selectedRecipe?.id == recipe.id ? 0.6 : 0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                brewState.selectedRecipe?.id == recipe.id
                                    ? Color.green.opacity(0.6)
                                    : Color.white.opacity(0.3),
                                lineWidth: brewState.selectedRecipe?.id == recipe.id ? 3 : 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                brewState.deleteRecipe(recipe)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
