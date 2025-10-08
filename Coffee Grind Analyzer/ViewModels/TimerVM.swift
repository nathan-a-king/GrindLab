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

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard let recipe = recipe,
              recipe.steps.indices.contains(stepIndex) else { return }
        isRunning = true
        targetDate = Date().addingTimeInterval(remaining)
        scheduleStepNotification()
        startOrUpdateLiveActivity()
        timerCancellable = Timer
            .publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        isRunning = false
        invalidateTimer()
        clearScheduledNotifications()
        updateLiveActivityState()
    }

    func nextStep() {
        guard let recipe = recipe else { return }
        stepIndex += 1
        guard stepIndex < recipe.steps.count else { finish(); return }
        remaining = recipe.steps[stepIndex].duration
        updateLiveActivityState()
        if isRunning { start() }
    }

    private func finish() {
        isRunning = false
        invalidateTimer()
        remaining = 0
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

        if remaining == 0 { nextStep() }
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
        content.body = step.note ?? "Next step"
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

            let attributes = BrewActivityAttributes(recipeName: recipe.name)
            let contentState = BrewActivityAttributes.ContentState(
                currentStepTitle: step.title,
                currentStepNote: step.note,
                stepIndex: stepIndex,
                totalSteps: recipe.steps.count,
                targetDate: targetDate ?? Date().addingTimeInterval(remaining),
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
            updateLiveActivityState()
        }
    }

    private func updateLiveActivityState() {
        guard let recipe = recipe,
              recipe.steps.indices.contains(stepIndex),
              let activity = brewActivity else { return }

        let step = recipe.steps[stepIndex]
        let contentState = BrewActivityAttributes.ContentState(
            currentStepTitle: step.title,
            currentStepNote: step.note,
            stepIndex: stepIndex,
            totalSteps: recipe.steps.count,
            targetDate: targetDate ?? Date().addingTimeInterval(remaining),
            remainingTime: remaining,
            stepDuration: step.duration,
            isRunning: isRunning
        )

        Task {
            await activity.update(.init(state: contentState, staleDate: nil))
        }
    }

    private func endLiveActivity() {
        guard let activity = brewActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            brewActivity = nil
        }
    }
}
