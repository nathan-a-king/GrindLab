//
//  TastingTagsView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/22/25.
//

import SwiftUI

// MARK: - Helper Function
func colorForTag(_ tag: String) -> Color {
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

struct TastingTagsView: View {
    @Binding var selectedTags: Set<String>
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tap tags that describe the taste")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(TastingNotes.availableTags, id: \.self) { tag in
                    TagButton(
                        tag: tag,
                        isSelected: selectedTags.contains(tag),
                        action: {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    )
                }
            }
            
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected (\(selectedTags.count)):")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                                SelectedTagView(tag: tag) {
                                    selectedTags.remove(tag)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Tag Button

struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorForTag(tag).opacity(isSelected ? 0.6 : 0.4))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Selected Tag View

struct SelectedTagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.caption)
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorForTag(tag).opacity(0.5))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct TastingTagsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TastingTagsView(selectedTags: .constant(["Balanced", "Fruity", "Bright"]))
            
            Divider()
            
            TastingTagsView(selectedTags: .constant(Set<String>()))
        }
        .padding()
    }
}
#endif//
//  TastingTagsView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/22/25.
//

