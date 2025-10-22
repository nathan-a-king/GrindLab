//
//  BrewActivityWidgetLiveActivity.swift
//  BrewActivityWidget
//
//  Created by Nathan King on 10/4/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Shared Attributes Model
// This must match exactly with the one in the main app

struct BrewActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentStepTitle: String
        var currentStepNote: String?
        var stepIndex: Int
        var totalSteps: Int
        var targetDate: Date
        var stepStartDate: Date
        var remainingTime: TimeInterval  // Keep for paused state display
        var stepDuration: TimeInterval
        var isRunning: Bool
    }

    // Fixed attributes that don't change during the activity
    var recipeName: String
}

// MARK: - Helper Functions

private func shouldDisplayCountdown(for state: BrewActivityAttributes.ContentState) -> Bool {
    state.isRunning && state.targetDate.timeIntervalSinceNow > 0
}

private func fallbackTime(for state: BrewActivityAttributes.ContentState) -> TimeInterval {
    state.isRunning ? 0 : max(0, state.remainingTime)
}

// MARK: - Live Activity Widget

struct BrewActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BrewActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.caption)
                        Text(context.attributes.recipeName)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.brown)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Text("Step")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(context.state.stepIndex + 1)/\(context.state.totalSteps)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.currentStepTitle)
                            .font(.headline)
                            .fontWeight(.semibold)

                        if shouldDisplayCountdown(for: context.state) {
                            Text(context.state.targetDate, style: .timer)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.brown)
                        } else {
                            Text(timeString(fallbackTime(for: context.state)))
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.brown)
                        }

                        if let note = context.state.currentStepNote {
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Progress bar
                        BrewProgressView(state: context.state)
                    }
                    .padding(.vertical, 8)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: context.state.isRunning ? "pause.circle.fill" : "play.circle.fill")
                            .foregroundColor(context.state.isRunning ? .orange : .green)
                        Text(context.state.isRunning ? "Brewing..." : "Paused")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                // Compact leading (left side of notch)
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(.brown)
            } compactTrailing: {
                // Compact trailing (right side of notch)
                HStack(spacing: 6) {
                    Text(context.state.currentStepTitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if shouldDisplayCountdown(for: context.state) {
                        Text(context.state.targetDate, style: .timer)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.brown)
                    } else {
                        Text(timeString(fallbackTime(for: context.state)))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.brown)
                    }
                }
            } minimal: {
                // Minimal presentation
                Image(systemName: context.state.isRunning ? "cup.and.saucer.fill" : "pause.circle.fill")
                    .foregroundColor(.brown)
            }
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BrewActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3)
                Text(context.attributes.recipeName)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("Step \(context.state.stepIndex + 1)/\(context.state.totalSteps)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                HStack {
                    Text(context.state.currentStepTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if shouldDisplayCountdown(for: context.state) {
                        Text(context.state.targetDate, style: .timer)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    } else {
                        Text(timeString(fallbackTime(for: context.state)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                }

                BrewProgressView(state: context.state)

                if let note = context.state.currentStepNote {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack {
                Image(systemName: context.state.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(context.state.isRunning ? .orange : .green)
                    .font(.caption)
                Text(context.state.isRunning ? "Brewing" : "Paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .activityBackgroundTint(Color.brown.opacity(0.1))
        .activitySystemActionForegroundColor(.brown)
    }

    private func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Shared Views

private struct BrewProgressView: View {
    let state: BrewActivityAttributes.ContentState

    var body: some View {
        if shouldAnimateProgress {
            ProgressView(
                timerInterval: state.stepStartDate...state.targetDate,
                countsDown: false
            )
            .tint(.brown)
        } else {
            ProgressView(value: clampedProgress)
                .tint(.brown)
        }
    }

    private var shouldAnimateProgress: Bool {
        state.isRunning && state.stepDuration > 0 && state.stepStartDate < state.targetDate
    }

    private var clampedProgress: Double {
        guard state.stepDuration > 0 else { return 0 }
        let progress = 1 - (state.remainingTime / state.stepDuration)
        return min(max(progress, 0), 1)
    }
}

// MARK: - Previews

#Preview("Notification", as: .content, using: BrewActivityAttributes(recipeName: "V60 – 1:16")) {
   BrewActivityWidgetLiveActivity()
} contentStates: {
    BrewActivityAttributes.ContentState(
        currentStepTitle: "Bloom",
        currentStepNote: "40g water",
        stepIndex: 0,
        totalSteps: 4,
        targetDate: Date().addingTimeInterval(30),
        stepStartDate: Date().addingTimeInterval(-15),
        remainingTime: 30,
        stepDuration: 45,
        isRunning: true
    )
    BrewActivityAttributes.ContentState(
        currentStepTitle: "Pour 2",
        currentStepNote: "to 200g",
        stepIndex: 1,
        totalSteps: 4,
        targetDate: Date().addingTimeInterval(15),
        stepStartDate: Date().addingTimeInterval(-15),
        remainingTime: 15,
        stepDuration: 30,
        isRunning: false
    )
}
