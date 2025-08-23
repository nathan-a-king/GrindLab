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
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: tastingNotes.brewMethod.icon)
                            .foregroundColor(.blue)
                        Text(tastingNotes.brewMethod.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= tastingNotes.overallRating ? "star.fill" : "star")
                                .foregroundColor(index <= tastingNotes.overallRating ? .yellow : .gray)
                                .font(.caption)
                        }
                    }
                    Text("\(tastingNotes.overallRating)/5")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Tasting Tags
            if !tastingNotes.tastingTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flavor Profile")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(tastingNotes.tastingTags.sorted(), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .foregroundColor(colorForTag(tag))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(colorForTag(tag).opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(colorForTag(tag).opacity(0.3), lineWidth: 1)
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
                    
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
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
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
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
        HStack(spacing: 8) {
            // Brew method icon
            Image(systemName: tastingNotes.brewMethod.icon)
                .foregroundColor(.blue)
                .font(.caption)
            
            // Rating stars
            HStack(spacing: 1) {
                ForEach(1...tastingNotes.overallRating, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption2)
                }
            }
            
            // Top tags (limit to 2-3)
            if !tastingNotes.tastingTags.isEmpty {
                let topTags = Array(tastingNotes.tastingTags.sorted().prefix(2))
                ForEach(topTags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .foregroundColor(colorForTag(tag))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorForTag(tag).opacity(0.15))
                        )
                }
                
                if tastingNotes.tastingTags.count > 2 {
                    Text("+\(tastingNotes.tastingTags.count - 2)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func colorForTag(_ tag: String) -> Color {
        // Same color logic as main view
        if ["Balanced", "Sweet", "Smooth", "Bright", "Clean", "Complex",
            "Fruity", "Floral", "Nutty", "Chocolatey", "Caramel", "Vanilla"].contains(tag) {
            return .green
        }
        
        if ["Full Body", "Light Body", "Medium Body", "Acidic", "Low Acid",
            "Earthy", "Spicy", "Herbal", "Wine-like", "Tea-like"].contains(tag) {
            return .blue
        }
        
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
