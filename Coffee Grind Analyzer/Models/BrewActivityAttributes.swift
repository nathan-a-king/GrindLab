//
//  BrewActivityAttributes.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//

import ActivityKit
import Foundation

// MARK: - Shared Live Activity Attributes
// This model is used by both the main app and the widget extension

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
