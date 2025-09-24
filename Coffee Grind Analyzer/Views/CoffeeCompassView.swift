//
//  CoffeeCompassView.swift
//  Coffee Grind Analyzer
//
//  Created by Claude on 8/30/25.
//

import SwiftUI

struct CoffeeCompassView: View {
    let flavorProfile: FlavorProfile?
    let currentPosition: CoffeeCompassPosition

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Brew Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if let profile = flavorProfile {
                    Text(profile.overallTaste.rawValue)
                        .font(.headline)
                        .foregroundColor(currentPosition.color)
                }
            }

            VStack(spacing: 32) {
                // Extraction Level Bar
                VStack(alignment: .leading, spacing: 12) {
                    Text("EXTRACTION")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))

                    ExtractionBar(position: currentPosition)
                }

                // Strength Level Bar
                VStack(alignment: .leading, spacing: 12) {
                    Text("STRENGTH")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))

                    StrengthBar(position: currentPosition)
                }
            }

            // Recommendations
            if let profile = flavorProfile {
                BrewAdjustmentCard(profile: profile, position: currentPosition)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brown.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Extraction Bar

struct ExtractionBar: View {
    let position: CoffeeCompassPosition

    var extractionLevel: Double {
        switch position.taste {
        case .underExtracted:
            return 0.2
        case .balanced:
            return 0.5
        case .overExtracted:
            return 0.8
        case .weak:
            return 0.35  // Slightly under
        case .harsh:
            return 0.65  // Slightly over
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background zones
                HStack(spacing: 0) {
                    // Under-extracted zone
                    Rectangle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: geometry.size.width * 0.33)

                    // Optimal zone
                    Rectangle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: geometry.size.width * 0.34)

                    // Over-extracted zone
                    Rectangle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: geometry.size.width * 0.33)
                }
                .cornerRadius(8)

                // Zone labels
                HStack {
                    Text("Under")
                        .font(.caption2)
                        .foregroundColor(.yellow.opacity(0.8))
                        .frame(width: geometry.size.width * 0.33)

                    Text("Optimal")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green.opacity(0.8))
                        .frame(width: geometry.size.width * 0.34)

                    Text("Over")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: geometry.size.width * 0.33)
                }

                // Current position indicator
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .position(
                        x: geometry.size.width * CGFloat(extractionLevel),
                        y: geometry.size.height / 2
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: extractionLevel)
            }
        }
        .frame(height: 40)
    }

    var indicatorColor: Color {
        if extractionLevel < 0.33 {
            return .yellow
        } else if extractionLevel < 0.67 {
            return .green
        } else {
            return .red
        }
    }
}

// MARK: - Strength Bar

struct StrengthBar: View {
    let position: CoffeeCompassPosition

    var strengthLevel: Double {
        switch position.intensity {
        case .veryMild:
            return 0.1
        case .mild:
            return 0.3
        case .moderate:
            return 0.5
        case .strong:
            return 0.7
        case .veryStrong:
            return 0.9
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.2),
                        Color.green.opacity(0.2),
                        Color.orange.opacity(0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(8)

                // Zone labels
                HStack {
                    Text("Weak")
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.8))
                        .padding(.leading, 12)

                    Spacer()

                    Text("Balanced")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.green.opacity(0.8))

                    Spacer()

                    Text("Strong")
                        .font(.caption2)
                        .foregroundColor(.orange.opacity(0.8))
                        .padding(.trailing, 12)
                }

                // Current position indicator
                Circle()
                    .fill(strengthIndicatorColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .position(
                        x: geometry.size.width * CGFloat(strengthLevel),
                        y: geometry.size.height / 2
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: strengthLevel)
            }
        }
        .frame(height: 40)
    }

    var strengthIndicatorColor: Color {
        if strengthLevel < 0.33 {
            return .blue
        } else if strengthLevel < 0.67 {
            return .green
        } else {
            return .orange
        }
    }
}

// MARK: - Brew Adjustment Card

struct BrewAdjustmentCard: View {
    let profile: FlavorProfile
    let position: CoffeeCompassPosition

    var recommendations: [String] {
        var tips: [String] = []

        switch position.taste {
        case .underExtracted:
            tips.append("• Grind finer")
            tips.append("• Increase brew time")
            tips.append("• Increase water temperature")
        case .overExtracted:
            tips.append("• Grind coarser")
            tips.append("• Reduce brew time")
            tips.append("• Lower water temperature")
        case .weak:
            tips.append("• Use more coffee")
            tips.append("• Grind slightly finer")
        case .harsh:
            tips.append("• Use less coffee")
            tips.append("• Check grind consistency")
        case .balanced:
            tips.append("• Great extraction!")
            tips.append("• Consider minor adjustments for preference")
        }

        return tips
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)

                Text("ADJUSTMENTS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(recommendations, id: \.self) { tip in
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Coffee Compass Position

struct CoffeeCompassPosition {
    let taste: FlavorProfile.OverallTaste
    let intensity: FlavorProfile.TasteIntensity

    init(flavorProfile: FlavorProfile) {
        self.taste = flavorProfile.overallTaste
        self.intensity = flavorProfile.intensity
    }

    var color: Color {
        switch taste {
        case .balanced: return .green
        case .underExtracted: return .yellow
        case .overExtracted: return .red
        case .weak: return .blue
        case .harsh: return .orange
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CoffeeCompassView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Under-extracted example
            CoffeeCompassView(
                flavorProfile: FlavorProfile(
                    overallTaste: .underExtracted,
                    flavorIssues: [.sour, .weak],
                    intensity: .mild,
                    notes: "Tastes quite sour",
                    timestamp: Date()
                ),
                currentPosition: CoffeeCompassPosition(
                    flavorProfile: FlavorProfile(
                        overallTaste: .underExtracted,
                        flavorIssues: [.sour, .weak],
                        intensity: .mild,
                        notes: "Tastes quite sour",
                        timestamp: Date()
                    )
                )
            )

            // Balanced example
            CoffeeCompassView(
                flavorProfile: FlavorProfile(
                    overallTaste: .balanced,
                    flavorIssues: [],
                    intensity: .moderate,
                    notes: "Perfect cup!",
                    timestamp: Date()
                ),
                currentPosition: CoffeeCompassPosition(
                    flavorProfile: FlavorProfile(
                        overallTaste: .balanced,
                        flavorIssues: [],
                        intensity: .moderate,
                        notes: "Perfect cup!",
                        timestamp: Date()
                    )
                )
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
#endif