//
//  BrewJournalModels.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 11/8/25.
//

import Foundation
import SwiftUI

// MARK: - Roast Level

enum RoastLevel: String, CaseIterable, Codable, Hashable {
    case light = "Light"
    case mediumLight = "Medium-Light"
    case medium = "Medium"
    case mediumDark = "Medium-Dark"
    case dark = "Dark"

    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .mediumLight:
            return "sun.max"
        case .medium:
            return "circle.lefthalf.filled"
        case .mediumDark:
            return "moon.fill"
        case .dark:
            return "moon.stars.fill"
        }
    }
}

// MARK: - Coffee Bean Info

struct CoffeeBeanInfo: Codable, Equatable, Hashable {
    var name: String
    var roaster: String?
    var roastDate: Date?
    var roastLevel: RoastLevel?
    var origin: String?
    var process: String? // e.g., "Washed", "Natural", "Honey"
    var notes: String?

    // Computed property for freshness
    var daysFromRoast: Int? {
        guard let roastDate = roastDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: roastDate, to: Date())
        return components.day
    }

    var freshnessStatus: String? {
        guard let days = daysFromRoast else { return nil }

        switch days {
        case ..<0:
            return "Future roast date"
        case 0...3:
            return "Very Fresh"
        case 4...14:
            return "Fresh"
        case 15...30:
            return "Good"
        case 31...60:
            return "Aging"
        default:
            return "Stale"
        }
    }

    // Display string for the bean
    var displayName: String {
        if !name.isEmpty {
            return name
        } else if let roaster = roaster {
            return roaster
        } else {
            return "Unknown Bean"
        }
    }
}

// MARK: - Brew Parameters

struct BrewParameters: Codable, Equatable, Hashable {
    var brewMethod: TastingNotes.BrewMethod
    var doseIn: Double? // Coffee dose in grams
    var yieldOut: Double? // Output weight in grams or ml
    var brewTime: TimeInterval? // Total brew time in seconds
    var waterTemp: Double? // Water temperature in Celsius
    var grindSetting: String? // Grinder setting (e.g., "4.5", "Medium-Fine")

    // Computed properties
    var ratio: Double? {
        guard let doseIn = doseIn, let yieldOut = yieldOut, doseIn > 0 else {
            return nil
        }
        return yieldOut / doseIn
    }

    var ratioDisplay: String? {
        guard let ratio = ratio else { return nil }
        return String(format: "1:%.1f", ratio)
    }

    var brewTimeDisplay: String? {
        guard let brewTime = brewTime else { return nil }
        let minutes = Int(brewTime) / 60
        let seconds = Int(brewTime) % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    var waterTempDisplay: String? {
        guard let waterTemp = waterTemp else { return nil }
        return String(format: "%.0f°C", waterTemp)
    }

    // Check if parameters are within typical ranges
    var hasUnusualParameters: Bool {
        // Check for extreme values that might indicate data entry errors
        if let temp = waterTemp, (temp < 50 || temp > 100) {
            return true
        }
        if let dose = doseIn, (dose < 5 || dose > 100) {
            return true
        }
        if let yield = yieldOut, (yield < 10 || yield > 1000) {
            return true
        }
        if let time = brewTime, (time < 10 || time > 600) {
            return true
        }
        return false
    }
}

// MARK: - Brew Journal Entry

struct BrewJournalEntry: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var timestamp: Date
    var grindType: CoffeeGrindType
    var coffeeBean: CoffeeBeanInfo?
    var brewParameters: BrewParameters
    var tastingNotes: TastingNotes?
    var linkedAnalysisId: UUID? // Optional link to CoffeeAnalysisResults
    var notes: String? // General free-form notes
    var photos: [UUID]? // Photo IDs for future photo support

    // Initialization
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        grindType: CoffeeGrindType,
        coffeeBean: CoffeeBeanInfo? = nil,
        brewParameters: BrewParameters,
        tastingNotes: TastingNotes? = nil,
        linkedAnalysisId: UUID? = nil,
        notes: String? = nil,
        photos: [UUID]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.grindType = grindType
        self.coffeeBean = coffeeBean
        self.brewParameters = brewParameters
        self.tastingNotes = tastingNotes
        self.linkedAnalysisId = linkedAnalysisId
        self.notes = notes
        self.photos = photos
    }

    // MARK: - Computed Properties

    var hasLinkedAnalysis: Bool {
        linkedAnalysisId != nil
    }

    var displayTitle: String {
        if let beanName = coffeeBean?.displayName, !beanName.isEmpty && beanName != "Unknown Bean" {
            return beanName
        }
        return "\(grindType.displayName) - \(brewParameters.brewMethod.rawValue)"
    }

    var rating: Int? {
        tastingNotes?.overallRating
    }

    var hasRating: Bool {
        tastingNotes?.overallRating != nil
    }

    var brewMethodIcon: String {
        brewParameters.brewMethod.icon
    }

    var hasCompleteInfo: Bool {
        // Entry is "complete" if it has tasting notes and bean info
        coffeeBean != nil && tastingNotes != nil
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var shortTimeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    // MARK: - Helper Methods

    func hasTag(_ tag: String) -> Bool {
        tastingNotes?.tastingTags.contains(tag) ?? false
    }

    func matchesSearchQuery(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        // Search in bean name
        if let beanName = coffeeBean?.name.lowercased(), beanName.contains(lowercaseQuery) {
            return true
        }

        // Search in roaster
        if let roaster = coffeeBean?.roaster?.lowercased(), roaster.contains(lowercaseQuery) {
            return true
        }

        // Search in notes
        if let notes = notes?.lowercased(), notes.contains(lowercaseQuery) {
            return true
        }

        // Search in tasting notes
        if let extractionNotes = tastingNotes?.extractionNotes?.lowercased(), extractionNotes.contains(lowercaseQuery) {
            return true
        }

        // Search in tasting tags
        if let tags = tastingNotes?.tastingTags {
            for tag in tags {
                if tag.lowercased().contains(lowercaseQuery) {
                    return true
                }
            }
        }

        // Search in grind type
        if grindType.displayName.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in brew method
        if brewParameters.brewMethod.rawValue.lowercased().contains(lowercaseQuery) {
            return true
        }

        return false
    }
}

// MARK: - Convenience Extensions

extension BrewJournalEntry {
    // Create a minimal entry for quick logging
    static func quickEntry(
        grindType: CoffeeGrindType,
        brewMethod: TastingNotes.BrewMethod,
        rating: Int? = nil
    ) -> BrewJournalEntry {
        let brewParams = BrewParameters(brewMethod: brewMethod)

        var tastingNotes: TastingNotes? = nil
        if let rating = rating {
            tastingNotes = TastingNotes(
                brewMethod: brewMethod,
                overallRating: rating,
                tastingTags: [],
                extractionNotes: nil,
                extractionTime: nil,
                waterTemp: nil,
                doseIn: nil,
                yieldOut: nil
            )
        }

        return BrewJournalEntry(
            grindType: grindType,
            brewParameters: brewParams,
            tastingNotes: tastingNotes
        )
    }
}
