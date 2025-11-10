//
//  BrewJournalRowView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 11/8/25.
//

import SwiftUI

struct BrewJournalRowView: View {
    let entry: BrewJournalEntry

    var body: some View {
        HStack(spacing: 12) {
            // Left: Brew method icon
            Image(systemName: entry.brewMethodIcon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.brown.opacity(0.6))
                )

            // Middle: Content
            VStack(alignment: .leading, spacing: 4) {
                // Title: Bean name or fallback
                Text(entry.displayTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Subtitle: Brew method + Grind type
                HStack(spacing: 6) {
                    Text(entry.brewParameters.brewMethod.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))

                    Text("•")
                        .foregroundColor(.white.opacity(0.5))

                    Text(entry.grindType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Timestamp
                Text(entry.shortTimeAgo)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Right: Indicators
            VStack(alignment: .trailing, spacing: 4) {
                // Rating stars (if available)
                if let rating = entry.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(star <= rating ? .white : .white.opacity(0.3))
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
        )
    }
}

// MARK: - Preview

#Preview("With Rating & Link") {
    let entry = BrewJournalEntry(
        timestamp: Date(),
        grindType: .espresso,
        coffeeBean: CoffeeBeanInfo(
            name: "Ethiopia Yirgacheffe",
            roaster: "Blue Bottle",
            roastDate: Date(),
            roastLevel: .mediumLight
        ),
        brewParameters: BrewParameters(brewMethod: .espresso),
        tastingNotes: TastingNotes(
            brewMethod: .espresso,
            overallRating: 4,
            tastingTags: ["Bright", "Fruity"],
            extractionNotes: nil,
            extractionTime: nil,
            waterTemp: nil,
            doseIn: nil,
            yieldOut: nil
        )
    )

    return BrewJournalRowView(entry: entry)
        .padding()
        .background(Color.brown.opacity(0.7))
}

#Preview("No Rating") {
    let entry = BrewJournalEntry(
        timestamp: Date().addingTimeInterval(-3600),
        grindType: .filter,
        coffeeBean: CoffeeBeanInfo(
            name: "Colombia Supremo",
            roaster: nil,
            roastDate: nil,
            roastLevel: nil
        ),
        brewParameters: BrewParameters(brewMethod: .pourOver)
    )

    return BrewJournalRowView(entry: entry)
        .padding()
        .background(Color.brown.opacity(0.7))
}

#Preview("Minimal Entry") {
    let entry = BrewJournalEntry(
        timestamp: Date().addingTimeInterval(-7200),
        grindType: .frenchPress,
        brewParameters: BrewParameters(brewMethod: .frenchPress)
    )

    return BrewJournalRowView(entry: entry)
        .padding()
        .background(Color.brown.opacity(0.7))
}
