//
//  TimerVM.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//  Integrated from Brew Buddy
//

import Foundation
import Combine
import UserNotifications
import ActivityKit

final class TimerVM: ObservableObject {
    @Published var recipe: Recipe?
    @Published var stepIndex: Int = 0
    @Published var remaining: TimeInterval = 0
    @Published var isRunning = false

    private var timerCancellable: AnyCancellable?
    private var targetDate: Date?
    private var brewActivity: Activity<BrewActivityAttributes>?

    var onBrewComplete: (() -> Void)?

    init() {
        requestNotificationAuth()
    }

    func setRecipe(_ recipe: Recipe?) {
        // Stop current timer if running
        if isRunning {
            pause()
        }

        self.recipe = recipe
        reset()
    }

    func reset() {
        stepIndex = 0
        remaining = recipe?.steps.first?.duration ?? 0
        isRunning = false
        invalidateTimer()
        clearScheduledNotifications()
        endLiveActivity()
    }

    func toggle() {
        if isRunning {
            pause()
        } else {
            Task { await start() }
        }
    }

    func start() async {
        guard let recipe = recipe,
              recipe.steps.indices.contains(stepIndex) else { return }
        isRunning = true
        let buffer: TimeInterval = 0.05
        targetDate = Date().addingTimeInterval(remaining + buffer)
        scheduleStepNotification()
        startOrUpdateLiveActivity()
        // If activity already exists, push an immediate update before starting timer
        await updateLiveActivityState()
        timerCancellable = Timer
            .publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        isRunning = false
        invalidateTimer()
        clearScheduledNotifications()
        // Keep a consistent target date so the Live Activity doesn't drift while paused
        targetDate = Date().addingTimeInterval(remaining)
        Task { await updateLiveActivityState() }
    }

    func nextStep() async {
        guard let recipe = recipe else { return }
        stepIndex += 1
        guard stepIndex < recipe.steps.count else { await finish(); return }
        remaining = recipe.steps[stepIndex].duration

        if isRunning {
            // Ensure no overlapping timers
            invalidateTimer()

            // Reset targetDate before updating Live Activity
            let buffer: TimeInterval = 0.05
            targetDate = Date().addingTimeInterval(remaining + buffer)
            scheduleStepNotification()
            await updateLiveActivityState()
            // Restart the timer with the new targetDate
            timerCancellable = Timer
                .publish(every: 0.05, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in self?.tick() }
        } else {
            await updateLiveActivityState()
        }
    }

    private func finish() async {
        isRunning = false
        invalidateTimer()
        remaining = 0
        targetDate = nil  // Clear targetDate to prevent counting up
        clearScheduledNotifications()
        endLiveActivity()
        if let recipe = recipe {
            notify(title: "Brew complete", body: "\(recipe.name) is ready ☕️")
        }
        // Notify view that brewing is complete
        onBrewComplete?()
    }

    private func tick() {
        guard let target = targetDate else { return }
        remaining = max(0, target.timeIntervalSinceNow)

        if remaining <= 0.001 {
            remaining = 0
            Task { [weak self] in
                await self?.nextStep()
            }
        }
    }

    private func invalidateTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    // MARK: Notifications
    private func requestNotificationAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleStepNotification() {
        guard let recipe = recipe,
              recipe.steps.indices.contains(stepIndex) else { return }
        let step = recipe.steps[stepIndex]
        let content = UNMutableNotificationContent()
        content.title = step.title + " done"

        // Check if this is the final step
        if stepIndex == recipe.steps.count - 1 {
            content.body = "Brew complete!"
        } else {
            content.body = step.note ?? "Next step"
        }

        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let req = UNNotificationRequest(identifier: "step-\(step.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func clearScheduledNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: Live Activity

    private func startOrUpdateLiveActivity() {
        print("🔵 startOrUpdateLiveActivity called")

        guard let recipe = recipe,
              recipe.steps.indices.contains(stepIndex) else {
            print("❌ No recipe or invalid step index")
            return
        }

        print("✅ Recipe: \(recipe.name), Step: \(stepIndex)")
        let step = recipe.steps[stepIndex]

        if brewActivity == nil {
            // Start new Live Activity
            print("🟢 Starting NEW Live Activity...")

            // Check if Live Activities are supported
            if #available(iOS 16.2, *) {
                print("✅ iOS 16.2+ available")
            } else {
                print("❌ iOS version too old for Live Activities")
                return
            }

            // Check activity state
            print("🔍 ActivityAuthorizationInfo.areActivitiesEnabled: \(ActivityAuthorizationInfo().areActivitiesEnabled)")

            if targetDate == nil {
                targetDate = Date().addingTimeInterval(remaining)
            }

            guard let targetDate = targetDate else { return }

            let attributes = BrewActivityAttributes(recipeName: recipe.name)
            let contentState = BrewActivityAttributes.ContentState(
                currentStepTitle: step.title,
                currentStepNote: step.note,
                stepIndex: stepIndex,
                totalSteps: recipe.steps.count,
                targetDate: targetDate,
                remainingTime: remaining,
                stepDuration: step.duration,
                isRunning: isRunning
            )

            do {
                brewActivity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: nil)
                )
                print("✅ Live Activity started successfully! ID: \(brewActivity?.id ?? "unknown")")
            } catch {
                print("❌ Failed to start Live Activity: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
            }
        } else {
            // Update existing Live Activity
            print("🔄 Updating existing Live Activity...")
            Task { await updateLiveActivityState() }
        }
    }

    @MainActor private func updateLiveActivityState() async {
        guard let recipe = recipe,
              recipe.steps.indices.contains(stepIndex),
              let activity = brewActivity,
              let targetDate = targetDate else { return }

        let step = recipe.steps[stepIndex]
        let contentState = BrewActivityAttributes.ContentState(
            currentStepTitle: step.title,
            currentStepNote: step.note,
            stepIndex: stepIndex,
            totalSteps: recipe.steps.count,
            targetDate: targetDate,
            remainingTime: remaining,
            stepDuration: step.duration,
            isRunning: isRunning
        )

        await activity.update(.init(state: contentState, staleDate: nil))
    }

    private func endLiveActivity() {
        guard let activity = brewActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            brewActivity = nil
        }
    }
}

