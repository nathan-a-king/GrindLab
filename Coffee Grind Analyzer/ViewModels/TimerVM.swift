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

final class TimerVM: ObservableObject {
    @Published var recipe: Recipe?
    @Published var stepIndex: Int = 0
    @Published var remaining: TimeInterval = 0
    @Published var isRunning = false

    private var timerCancellable: AnyCancellable?
    private var targetDate: Date?

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
    }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard let recipe = recipe,
              recipe.steps.indices.contains(stepIndex) else { return }
        isRunning = true
        targetDate = Date().addingTimeInterval(remaining)
        scheduleStepNotification()
        timerCancellable = Timer
            .publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        isRunning = false
        invalidateTimer()
        clearScheduledNotifications()
    }

    func nextStep() {
        guard let recipe = recipe else { return }
        stepIndex += 1
        guard stepIndex < recipe.steps.count else { finish(); return }
        remaining = recipe.steps[stepIndex].duration
        if isRunning { start() }
    }

    private func finish() {
        isRunning = false
        invalidateTimer()
        remaining = 0
        clearScheduledNotifications()
        if let recipe = recipe {
            notify(title: "Brew complete", body: "\(recipe.name) is ready ☕️")
        }
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
}
