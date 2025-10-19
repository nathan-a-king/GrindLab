//
//  BrewTimerView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//

import SwiftUI
import OSLog
#if canImport(UIKit)
import UIKit
#endif

private let brewTimerLogger = Logger(subsystem: "com.nateking.GrindLab", category: "BrewTimerView")

struct BrewTimerView: View {
    @EnvironmentObject var brewState: BrewAppState
    @EnvironmentObject var historyManager: CoffeeAnalysisHistoryManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var vm = TimerVM()
    @Binding var showingTimer: Bool
    @State private var showingTastingNotesPrompt = false
    @State private var showingTastingNotesDialog = false
    @State private var hasExistingTastingNotes = false
    @State private var showingNotificationRationale = false
    @State private var showingNotificationSettingsPrompt = false
    @State private var isRequestingNotificationPermission = false

    var body: some View {
        ZStack {
            Color.brown.opacity(0.7)
                .ignoresSafeArea()

            if let recipe = vm.recipe {
                brewTimerContent(recipe: recipe)
            } else {
                emptyStateView
            }
        }
        .navigationTitle(vm.recipe?.name ?? "Timer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await vm.refreshNotificationStatus()
            }
            // Set recipe from brew state
            if vm.recipe?.id != brewState.selectedRecipe?.id {
                vm.setRecipe(brewState.selectedRecipe)
            }
            updateIdleTimer(for: vm.isRunning)

            // Set up completion callback
            vm.onBrewComplete = {
                brewTimerLogger.debug("Brew completion handler triggered")
                // Only prompt for tasting notes if there's a linked analysis that exists in history
                if let analysis = brewState.currentGrindAnalysis {
                    brewTimerLogger.debug("Current grind analysis exists: \(analysis.name, privacy: .public)")
                    // Check by timestamp since ID might not match if it was a temporary object
                    if let savedAnalysis = historyManager.savedAnalyses.first(where: {
                        $0.results.timestamp == analysis.results.timestamp
                    }) {
                        brewTimerLogger.debug("Analysis exists in history")
                        DispatchQueue.main.async {
                            // Check if tasting notes already exist
                            hasExistingTastingNotes = savedAnalysis.results.tastingNotes != nil
                            brewTimerLogger.debug("Has existing tasting notes: \(hasExistingTastingNotes)")
                            showingTastingNotesPrompt = true
                        }
                    } else {
                        brewTimerLogger.debug("Analysis not found in history")
                        // No grind analysis in history, reset immediately
                        DispatchQueue.main.async {
                            showingTimer = false
                            brewState.selectedRecipe = nil
                        }
                    }
                } else {
                    brewTimerLogger.debug("No current grind analysis")
                    // No grind analysis, reset immediately
                    DispatchQueue.main.async {
                        showingTimer = false
                        brewState.selectedRecipe = nil
                    }
                }
            }
        }
        .onDisappear {
            updateIdleTimer(for: false)
        }
        .onChange(of: brewState.selectedRecipe) { _, newRecipe in
            vm.setRecipe(newRecipe)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await vm.refreshNotificationStatus()
                }
            }
        }
        .onChange(of: vm.isRunning) { _, isRunning in
            updateIdleTimer(for: isRunning)
        }
        .alert(hasExistingTastingNotes ? "Update Tasting Notes?" : "Add Tasting Notes?", isPresented: $showingTastingNotesPrompt) {
            Button("Yes") {
                showingTastingNotesDialog = true
            }
            Button("Not Now", role: .cancel) {
                // User declined tasting notes, reset immediately
                showingTimer = false
                brewState.selectedRecipe = nil
            }
        } message: {
            if hasExistingTastingNotes {
                Text("This analysis already has tasting notes. Would you like to update them?")
            } else {
                Text("Would you like to add tasting notes for this brew?")
            }
        }
        .sheet(isPresented: $showingTastingNotesDialog, onDismiss: {
            // Reset brew workflow state after tasting notes dialog is dismissed
            showingTimer = false
            brewState.selectedRecipe = nil
        }) {
            if let analysis = brewState.currentGrindAnalysis {
                EditTastingNotesDialog(savedAnalysis: analysis) { _, tastingNotes in
                    // Find the actual saved analysis by timestamp (ID might not match)
                    if let savedAnalysis = historyManager.savedAnalyses.first(where: {
                        $0.results.timestamp == analysis.results.timestamp
                    }) {
                        historyManager.updateAnalysisTastingNotes(
                            analysisId: savedAnalysis.id,
                            tastingNotes: tastingNotes
                        )
                    }
                }
            }
        }
        .alert("Enable Brew Alerts", isPresented: $showingNotificationRationale) {
            Button("Not Now", role: .cancel) { }
            Button("Continue") {
                isRequestingNotificationPermission = true
                Task {
                    let granted = await vm.requestNotificationPermission()
                    await MainActor.run {
                        isRequestingNotificationPermission = false
                        if !granted && vm.notificationStatus == .denied {
                            showingNotificationSettingsPrompt = true
                        }
                    }
                }
            }
        } message: {
            Text("Enable brew alerts to get step reminders even when GrindLab is in the background.")
        }
        .confirmationDialog("Notifications Disabled", isPresented: $showingNotificationSettingsPrompt, titleVisibility: .visible) {
            #if canImport(UIKit)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            #endif
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Visit Settings > Notifications to turn brew alerts back on whenever you’re ready.")
        }
    }

    @ViewBuilder
    private func brewTimerContent(recipe: Recipe) -> some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ScrollView {
                if isLandscape {
                    HStack(alignment: .top, spacing: 20) {
                        // Left side: Timer
                        VStack(spacing: 20) {
                            timerCard
                            controlsCard
                        }
                        .frame(maxWidth: .infinity)

                        // Right side: Recipe info and settings
                        VStack(spacing: 20) {
                            recipeInfoCard(recipe)
                            settingsCard
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(width: geometry.size.width)
                } else {
                    VStack(spacing: 32) {
                        recipeInfoCard(recipe)
                        timerCard
                        controlsCard
                        settingsCard
                    }
                    .padding()
                    .frame(width: geometry.size.width)
                }
            }
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(timeString(vm.remaining))
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)

                    if let note = currentStep.note {
                        Text(note)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Remaining time \(timeString(vm.remaining)) for \(currentStep.title)")
            }
            .frame(width: 240, height: 240)

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
                    action: { Task { await vm.nextStep() } },
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
            notificationPermissionSection
            if isRequestingNotificationPermission {
                Text("Look for the system prompt to allow brew alerts.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
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

    @ViewBuilder
    private var notificationPermissionSection: some View {
        if notificationsEnabled {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.white.opacity(0.8))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brew alerts enabled")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    Text("We'll remind you when each step finishes.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
        } else if vm.notificationStatus == .denied {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.slash.fill")
                        .foregroundColor(.white.opacity(0.8))
                    Text("Brew alerts are off")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                Text("Turn notifications back on from Settings to get brew reminders.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Button {
                    showingNotificationSettingsPrompt = true
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.15))
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Button {
                showingNotificationRationale = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.white.opacity(0.8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable brew alerts")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                        Text("Get notified when each brew step finishes.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.12))
                )
            }
            .disabled(isRequestingNotificationPermission)
            .opacity(isRequestingNotificationPermission ? 0.6 : 1)
        }
    }

    private var notificationsEnabled: Bool {
        switch vm.notificationStatus {
        case .authorized, .provisional:
            return true
        default:
            if #available(iOS 14.0, *) {
                return vm.notificationStatus == .ephemeral
            }
            return false
        }
    }

    private func updateIdleTimer(for isRunning: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = isRunning
        #endif
    }
}
