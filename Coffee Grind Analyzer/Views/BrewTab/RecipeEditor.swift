//
//  RecipeEditor.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//

import SwiftUI

struct RecipeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var recipe: Recipe
    var onSave: (Recipe) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        basicsCard
                        stepsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(recipe); dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basics")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                TextField("Name", text: $recipe.name)
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                HStack {
                    Text("Coffee (g)")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("g", value: $recipe.coffeeGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .frame(width: 100)
                }

                HStack {
                    Text("Water (g)")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("g", value: $recipe.waterGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .frame(width: 100)
                }

                TextField("Grind note (optional)", text: Binding<String>($recipe.grindNote, replacingNilWith: ""))
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Steps")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            ForEach($recipe.steps) { $step in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Title", text: $step.title)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)

                        if recipe.steps.count > 1 {
                            Button {
                                if let index = recipe.steps.firstIndex(where: { $0.id == step.id }) {
                                    recipe.steps.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(12)
                            }
                        }
                    }

                    HStack {
                        Text("Seconds")
                            .foregroundColor(.white)
                        Spacer()
                        TextField("sec", value: $step.duration, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .frame(width: 100)
                    }

                    TextField("Note (optional)", text: Binding($step.note, replacingNilWith: ""))
                        .font(.footnote)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }

            Button {
                recipe.steps.append(BrewStep(title: "New Step", duration: 30))
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Step")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}

// Wrapper for editing existing recipes
struct RecipeEditorWrapper: View {
    let recipe: Recipe
    let onSave: (Recipe) -> Void
    @State private var editableRecipe: Recipe

    init(recipe: Recipe, onSave: @escaping (Recipe) -> Void) {
        self.recipe = recipe
        self.onSave = onSave
        _editableRecipe = State(initialValue: recipe)
    }

    var body: some View {
        RecipeEditor(recipe: $editableRecipe, onSave: onSave)
    }
}

extension Binding {
    init(_ source: Binding<String?>, replacingNilWith replacement: String) where Value == String {
        self.init(
            get: { source.wrappedValue ?? replacement },
            set: { newValue in source.wrappedValue = newValue.isEmpty ? nil : newValue }
        )
    }
}
