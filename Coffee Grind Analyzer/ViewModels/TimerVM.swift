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
import OSLog

final class TimerVM: ObservableObject {
    @Published var recipe: Recipe?
    @Published var stepIndex: Int = 0
    @Published var remaining: TimeInterval = 0
    @Published var isRunning = false
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var timerCancellable: AnyCancellable?
    private var targetDate: Date?
    private var brewActivity: Activity<BrewActivityAttributes>?
    private let logger = Logger(subsystem: "com.nateking.GrindLab", category: "BrewTimer")

    var onBrewComplete: (() -> Void)?

    init() {
        Task { [weak self] in
            await self?.refreshNotificationStatus()
        }
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
        targetDate = Date().addingTimeInterval(remaining)
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
            targetDate = Date().addingTimeInterval(remaining)
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
        guard let recipe = recipe else { return }

        isRunning = false
        invalidateTimer()
        remaining = 0
        let finalContentState = makeFinalContentState(for: recipe)
        targetDate = nil  // Clear targetDate to prevent counting up
        clearScheduledNotifications()
        endLiveActivity(finalState: finalContentState)
        notify(title: "Brew complete", body: "\(recipe.name) is ready ☕️")
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
    private var isNotificationAuthorized: Bool {
        switch notificationStatus {
        case .authorized, .provisional:
            return true
        default:
            if #available(iOS 14.0, *) {
                return notificationStatus == .ephemeral
            }
            return false
        }
    }

    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshNotificationStatus()
            return granted
        } catch {
            self.logger.error("Notification permission request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationStatus = settings.authorizationStatus
        }
    }

    private func scheduleStepNotification() {
        guard isNotificationAuthorized else { return }
        guard let recipe = self.recipe,
              recipe.steps.indices.contains(self.stepIndex) else { return }
        let step = recipe.steps[self.stepIndex]
        let content = UNMutableNotificationContent()
        content.title = step.title + " done"

        // Check if this is the final step
        if self.stepIndex == recipe.steps.count - 1 {
            content.body = "Brew complete!"
        } else {
            content.body = step.note ?? "Next step"
        }

        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: self.remaining, repeats: false)
        let req = UNNotificationRequest(identifier: "step-\(step.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func clearScheduledNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func notify(title: String, body: String) {
        guard isNotificationAuthorized else { return }
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
        self.logger.debug("startOrUpdateLiveActivity invoked")

        guard let recipe = self.recipe,
              recipe.steps.indices.contains(self.stepIndex) else {
            self.logger.error("Live Activity update aborted due to missing recipe or invalid step index")
            return
        }

        self.logger.debug("Preparing Live Activity for recipe: \(recipe.name, privacy: .public), step: \(self.stepIndex)")
        let step = recipe.steps[self.stepIndex]

        if self.brewActivity == nil {
            // Start new Live Activity
            self.logger.debug("Starting new Live Activity")

            // Check if Live Activities are supported
            if #available(iOS 16.2, *) {
                // Continue
            } else {
                self.logger.error("Live Activities are unavailable on this iOS version")
                return
            }

            self.logger.debug("Live Activities enabled: \(ActivityAuthorizationInfo().areActivitiesEnabled)")

            if self.targetDate == nil {
                self.targetDate = Date().addingTimeInterval(self.remaining)
            }

            guard let targetDate = self.targetDate else { return }

            let attributes = BrewActivityAttributes(recipeName: recipe.name)
            let contentState = makeContentState(
                for: step,
                stepIndex: self.stepIndex,
                totalSteps: recipe.steps.count,
                targetDate: targetDate,
                remainingTime: self.remaining,
                isRunning: self.isRunning
            )

            do {
                self.brewActivity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: contentState, staleDate: nil)
                )
                if let id = self.brewActivity?.id {
                    self.logger.info("Live Activity started (id: \(id, privacy: .public))")
                } else {
                    self.logger.info("Live Activity started")
                }
            } catch {
                self.logger.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            // Update existing Live Activity
            self.logger.debug("Updating existing Live Activity")
            Task { await self.updateLiveActivityState() }
        }
    }

    @MainActor private func updateLiveActivityState() async {
        guard let recipe = self.recipe,
              recipe.steps.indices.contains(self.stepIndex),
              let activity = self.brewActivity,
              let targetDate = self.targetDate else { return }

        let step = recipe.steps[self.stepIndex]
        let contentState = makeContentState(
            for: step,
            stepIndex: self.stepIndex,
            totalSteps: recipe.steps.count,
            targetDate: targetDate,
            remainingTime: self.remaining,
            isRunning: self.isRunning
        )

        await activity.update(.init(state: contentState, staleDate: nil))
    }

    private func endLiveActivity(finalState: BrewActivityAttributes.ContentState? = nil) {
        guard let activity = self.brewActivity else { return }

        Task {
            if let finalState = finalState {
                await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            await MainActor.run {
                self.brewActivity = nil
            }
        }
    }

    private func makeFinalContentState(for recipe: Recipe) -> BrewActivityAttributes.ContentState? {
        guard brewActivity != nil, !recipe.steps.isEmpty else { return nil }

        let finalIndex: Int
        if recipe.steps.indices.contains(stepIndex) {
            finalIndex = stepIndex
        } else if stepIndex < 0 {
            finalIndex = 0
        } else {
            finalIndex = recipe.steps.count - 1
        }
        let finalStep = recipe.steps[finalIndex]

        let finalTargetDate = Date()
        return BrewActivityAttributes.ContentState(
            currentStepTitle: finalStep.title,
            currentStepNote: finalStep.note,
            stepIndex: finalIndex,
            totalSteps: recipe.steps.count,
            targetDate: finalTargetDate,
            stepStartDate: stepStartDate(for: finalTargetDate, stepDuration: finalStep.duration),
            remainingTime: 0,
            stepDuration: finalStep.duration,
            isRunning: false
        )
    }

    private func makeContentState(
        for step: BrewStep,
        stepIndex: Int,
        totalSteps: Int,
        targetDate: Date,
        remainingTime: TimeInterval,
        isRunning: Bool
    ) -> BrewActivityAttributes.ContentState {
        BrewActivityAttributes.ContentState(
            currentStepTitle: step.title,
            currentStepNote: step.note,
            stepIndex: stepIndex,
            totalSteps: totalSteps,
            targetDate: targetDate,
            stepStartDate: stepStartDate(for: targetDate, stepDuration: step.duration),
            remainingTime: remainingTime,
            stepDuration: step.duration,
            isRunning: isRunning
        )
    }

    private func stepStartDate(for targetDate: Date, stepDuration: TimeInterval) -> Date {
        guard stepDuration > 0 else { return targetDate }
        return targetDate.addingTimeInterval(-stepDuration)
    }
}
