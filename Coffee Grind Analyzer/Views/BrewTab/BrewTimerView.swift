//
//  BrewTimerView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BrewTimerView: View {
    @EnvironmentObject var brewState: BrewAppState
    @StateObject private var vm = TimerVM()
    @State private var keepAwake = true
    @State private var showingTastingNotes = false

    var body: some View {
        ZStack {
            Color.brown.opacity(0.7)
                .ignoresSafeArea()

            if let recipe = vm.recipe {
                ScrollView {
                    VStack(spacing: 32) {
                        recipeInfoCard(recipe)
                        timerCard
                        controlsCard
                        settingsCard
                    }
                    .padding()
                }
            } else {
                emptyStateView
            }
        }
        .navigationTitle(vm.recipe?.name ?? "Timer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = keepAwake
            #endif
            // Set recipe from brew state
            if vm.recipe?.id != brewState.selectedRecipe?.id {
                vm.setRecipe(brewState.selectedRecipe)
            }
        }
        .onDisappear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
        .onChange(of: brewState.selectedRecipe) { _, newRecipe in
            vm.setRecipe(newRecipe)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "timer")
                .font(.system(size: 72))
                .foregroundColor(.white.opacity(0.6))

            Text("No Recipe Selected")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Select a recipe to start brewing")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func recipeInfoCard(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe Details")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(Int(recipe.coffeeGrams))g coffee")
                        .foregroundColor(.white.opacity(0.8))
                }

                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(Int(recipe.waterGrams))g water")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .font(.subheadline)

            if let grindNote = recipe.grindNote {
                HStack(spacing: 4) {
                    Image(systemName: "circle.grid.cross.fill")
                        .foregroundColor(.white.opacity(0.8))
                    Text(grindNote)
                        .foregroundColor(.white.opacity(0.8))
                }
                .font(.caption)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    private var timerCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: progress)

                VStack(spacing: 8) {
                    Text(currentStep.title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(timeString(vm.remaining))
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)

                    if let note = currentStep.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Remaining time \(timeString(vm.remaining)) for \(currentStep.title)")
            }
            .frame(width: 260, height: 260)

            if let recipe = vm.recipe {
                Text("Step \(vm.stepIndex + 1) of \(recipe.steps.count)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    private var controlsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                controlButton(
                    label: "Reset",
                    icon: "arrow.uturn.left",
                    action: vm.reset,
                    isPrimary: false
                )

                controlButton(
                    label: vm.isRunning ? "Pause" : "Start",
                    icon: vm.isRunning ? "pause.fill" : "play.fill",
                    action: vm.toggle,
                    isPrimary: true
                )
                .frame(maxWidth: .infinity)

                controlButton(
                    label: "Next",
                    icon: "forward.end.fill",
                    action: vm.nextStep,
                    isPrimary: false
                )
            }
        }
    }

    private func controlButton(label: String, icon: String, action: @escaping () -> Void, isPrimary: Bool) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPrimary ? Color.brown.opacity(0.8) : Color.brown.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(isPrimary ? 0.4 : 0.2), lineWidth: 1)
                    )
            )
        }
    }

    private var settingsCard: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $keepAwake) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.white.opacity(0.8))
                    Text("Keep screen awake")
                        .foregroundColor(.white)
                }
            }
            .tint(.blue)
            .onChange(of: keepAwake) { _, on in
                #if canImport(UIKit)
                UIApplication.shared.isIdleTimerDisabled = on
                #endif
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    private var currentStep: BrewStep {
        guard let recipe = vm.recipe,
              !recipe.steps.isEmpty else {
            return BrewStep(title: "No Step", duration: 0)
        }
        return recipe.steps[clampedIndex]
    }

    private var clampedIndex: Int {
        guard let recipe = vm.recipe else { return 0 }
        return max(min(vm.stepIndex, recipe.steps.count - 1), 0)
    }

    private var progress: CGFloat {
        let total = currentStep.duration
        guard total > 0 else { return 1 }
        return CGFloat(1 - vm.remaining / total)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
