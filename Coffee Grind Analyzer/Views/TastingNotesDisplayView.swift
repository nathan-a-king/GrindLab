//
//  TastingNotesDisplayView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/22/25.
//

import SwiftUI

struct TastingNotesDisplayView: View {
    let tastingNotes: TastingNotes
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with brew method and rating
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tasting Notes")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Image(systemName: tastingNotes.brewMethod.icon)
                            .foregroundColor(.white.opacity(0.8))
                        Text(tastingNotes.brewMethod.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= tastingNotes.overallRating ? "star.fill" : "star")
                                .foregroundColor(index <= tastingNotes.overallRating ? .white : .gray)
                                .font(.caption)
                        }
                    }
                    Text("\(tastingNotes.overallRating)/5")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Tasting Tags
            if !tastingNotes.tastingTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flavor Profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(tastingNotes.tastingTags.sorted(), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorForTag(tag).opacity(0.4))
                                )
                        }
                    }
                }
            }
            
            // Brewing Details
            if hasBrewingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brewing Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 6) {
                        if let extractionTime = tastingNotes.extractionTime {
                            brewDetailRow(label: "Extraction Time", value: "\(String(format: "%.0f", extractionTime))s")
                        }
                        
                        if let waterTemp = tastingNotes.waterTemp {
                            brewDetailRow(label: "Water Temp", value: "\(String(format: "%.0f", waterTemp))°C")
                        }
                        
                        if let doseIn = tastingNotes.doseIn {
                            brewDetailRow(label: "Dose In", value: "\(String(format: "%.1f", doseIn))g")
                        }
                        
                        if let yieldOut = tastingNotes.yieldOut {
                            brewDetailRow(label: "Yield Out", value: "\(String(format: "%.1f", yieldOut))g")
                        }
                        
                        if let doseIn = tastingNotes.doseIn, let yieldOut = tastingNotes.yieldOut, doseIn > 0 {
                            let ratio = yieldOut / doseIn
                            brewDetailRow(label: "Ratio", value: "1:\(String(format: "%.1f", ratio))")
                        }
                    }
                }
            }
            
            // Extraction Notes
            if let notes = tastingNotes.extractionNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.2))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.7))
                .shadow(radius: 2)
        )
    }
    
    private var hasBrewingDetails: Bool {
        return tastingNotes.extractionTime != nil ||
               tastingNotes.waterTemp != nil ||
               tastingNotes.doseIn != nil ||
               tastingNotes.yieldOut != nil
    }
    
    private func brewDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
    
    private func colorForTag(_ tag: String) -> Color {
        // Positive tags
        if ["Balanced", "Sweet", "Smooth", "Bright", "Clean", "Complex",
            "Fruity", "Floral", "Nutty", "Chocolatey", "Caramel", "Vanilla"].contains(tag) {
            return .green
        }
        
        // Neutral/Descriptive tags
        if ["Full Body", "Light Body", "Medium Body", "Acidic", "Low Acid",
            "Earthy", "Spicy", "Herbal", "Wine-like", "Tea-like"].contains(tag) {
            return .blue
        }
        
        // Issues
        if ["Bitter", "Sour", "Astringent", "Muddy", "Weak", "Over-extracted",
            "Under-extracted", "Chalky", "Harsh", "Flat"].contains(tag) {
            return .red
        }
        
        return .gray
    }
}

// MARK: - Compact Tasting Notes View (for History List)

struct CompactTastingNotesView: View {
    let tastingNotes: TastingNotes
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // First row: Brew method icon and rating stars (indented to align with metrics)
            HStack(spacing: 8) {
                // Match the indentation of the metrics above by adding leading space
                HStack(spacing: 6) {
                    // Brew method icon
                    Image(systemName: tastingNotes.brewMethod.icon)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    
                    // Rating stars
                    HStack(spacing: 1) {
                        ForEach(1...tastingNotes.overallRating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .foregroundColor(.white)
                                .font(.caption2)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Second row: Tags (indented to align with metrics)
            if !tastingNotes.tastingTags.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    // Show maximum 3 tags to prevent overcrowding
                    let displayTags = Array(tastingNotes.tastingTags.sorted().prefix(3))
                    
                    ForEach(displayTags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorForTag(tag).opacity(0.4))
                            )
                            .lineLimit(1)
                    }
                    
                    // Show count for additional tags if there are more than 3
                    if tastingNotes.tastingTags.count > 3 {
                        Text("+\(tastingNotes.tastingTags.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.leading, 0) // Add slight leading padding to indent like the metrics
    }
    
    private func colorForTag(_ tag: String) -> Color {
        // Positive tags
        if ["Balanced", "Sweet", "Smooth", "Bright", "Clean", "Complex",
            "Fruity", "Floral", "Nutty", "Chocolatey", "Caramel", "Vanilla"].contains(tag) {
            return .green
        }
        
        // Neutral/Descriptive tags
        if ["Full Body", "Light Body", "Medium Body", "Acidic", "Low Acid",
            "Earthy", "Spicy", "Herbal", "Wine-like", "Tea-like"].contains(tag) {
            return .blue
        }
        
        // Issues
        if ["Bitter", "Sour", "Astringent", "Muddy", "Weak", "Over-extracted",
            "Under-extracted", "Chalky", "Harsh", "Flat"].contains(tag) {
            return .red
        }
        
        return .gray
    }
}

// MARK: - Preview

#if DEBUG
struct TastingNotesDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleNotes = TastingNotes(
            brewMethod: .espresso,
            overallRating: 4,
            tastingTags: ["Balanced", "Chocolatey", "Smooth"],
            extractionNotes: "Great extraction with nice crema. Slightly sweet finish.",
            extractionTime: 28.0,
            waterTemp: 93.0,
            doseIn: 18.5,
            yieldOut: 37.0
        )
        
        VStack {
            TastingNotesDisplayView(tastingNotes: sampleNotes)
            
            Divider()
            
            CompactTastingNotesView(tastingNotes: sampleNotes)
        }
        .padding()
    }
}
#endif
