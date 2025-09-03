//
//  MarkdownText.swift
//  Coffee Grind Analyzer
//
//  Created by Assistant on 8/31/25.
//

import SwiftUI

struct MarkdownText: View {
    let markdown: String
    let baseColor: Color
    
    init(_ markdown: String, color: Color = .white) {
        self.markdown = markdown
        self.baseColor = color
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            // Use AttributedString for iOS 15+
            Text(attributedString)
                .font(.subheadline)
        } else {
            // Fallback for older iOS versions
            Text(processedText)
                .font(.subheadline)
                .foregroundColor(baseColor.opacity(0.9))
        }
    }
    
    @available(iOS 15.0, *)
    private var attributedString: AttributedString {
        do {
            var attributedString = try AttributedString(markdown: markdown, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            
            // Apply custom styling
            attributedString.foregroundColor = UIColor(baseColor.opacity(0.9))
            
            // Style specific markdown elements
            for run in attributedString.runs {
                // Check for inlinePresentationIntent which contains the formatting info
                if let presentationIntent = run.inlinePresentationIntent {
                    // Check if it contains strong emphasis (bold)
                    if presentationIntent.contains(.stronglyEmphasized) {
                        attributedString[run.range].foregroundColor = UIColor(baseColor)
                        attributedString[run.range].font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                    }
                    // Check if it contains emphasis (italic)
                    else if presentationIntent.contains(.emphasized) {
                        attributedString[run.range].foregroundColor = UIColor(baseColor.opacity(0.95))
                        attributedString[run.range].font = UIFont.italicSystemFont(ofSize: 15)
                    }
                    // Check if it contains code
                    else if presentationIntent.contains(.code) {
                        attributedString[run.range].foregroundColor = UIColor(.green)
                        attributedString[run.range].backgroundColor = UIColor(Color.black.opacity(0.3))
                        attributedString[run.range].font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
                    }
                }
            }
            
            return attributedString
        } catch {
            // Fallback to plain text if markdown parsing fails
            var fallback = AttributedString(processedText)
            fallback.foregroundColor = UIColor(baseColor.opacity(0.9))
            fallback.font = UIFont.systemFont(ofSize: 15)
            return fallback
        }
    }
    
    // Simple text processing for older iOS versions
    private var processedText: String {
        var text = markdown
        
        // Remove markdown syntax for fallback
        text = text.replacingOccurrences(of: "**", with: "")
        text = text.replacingOccurrences(of: "*", with: "")
        text = text.replacingOccurrences(of: "`", with: "")
        text = text.replacingOccurrences(of: "#", with: "")
        
        return text
    }
}

// Alternative approach using a more custom renderer for better styling
struct CustomMarkdownText: View {
    let markdown: String
    let baseColor: Color
    
    init(_ markdown: String, color: Color = .white) {
        self.markdown = markdown
        self.baseColor = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseMarkdown(markdown), id: \.id) { element in
                renderElement(element)
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        let lines = text.components(separatedBy: .newlines)
        var elements: [MarkdownElement] = []
        var currentList: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                // Finish current list if exists
                if !currentList.isEmpty {
                    elements.append(.list(items: currentList))
                    currentList = []
                }
                continue
            }
            
            if trimmedLine.hasPrefix("#") {
                // Finish current list if exists
                if !currentList.isEmpty {
                    elements.append(.list(items: currentList))
                    currentList = []
                }
                
                let level = trimmedLine.prefix(while: { $0 == "#" }).count
                let title = String(trimmedLine.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                elements.append(.header(text: title, level: level))
                
            } else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("• ") {
                let item = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                currentList.append(item)
                
            } else {
                // Finish current list if exists
                if !currentList.isEmpty {
                    elements.append(.list(items: currentList))
                    currentList = []
                }
                
                elements.append(.paragraph(text: trimmedLine))
            }
        }
        
        // Don't forget the last list
        if !currentList.isEmpty {
            elements.append(.list(items: currentList))
        }
        
        return elements
    }
    
    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element {
        case .header(let text, let level):
            Text(processInlineMarkdown(text))
                .font(level == 1 ? .title2 : (level == 2 ? .headline : .subheadline))
                .fontWeight(.bold)
                .foregroundColor(baseColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, level == 1 ? 16 : 8)
                
        case .paragraph(let text):
            Text(processInlineMarkdown(text))
                .font(.subheadline)
                .foregroundColor(baseColor.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                
        case .list(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(baseColor.opacity(0.7))
                            .font(.subheadline)
                        Text(processInlineMarkdown(item))
                            .font(.subheadline)
                            .foregroundColor(baseColor.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }
    
    private func processInlineMarkdown(_ text: String) -> AttributedString {
        if #available(iOS 15.0, *) {
            do {
                return try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            } catch {
                return AttributedString(text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: ""))
            }
        } else {
            return AttributedString(text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: ""))
        }
    }
}

enum MarkdownElement {
    case header(text: String, level: Int)
    case paragraph(text: String)
    case list(items: [String])
    
    var id: String {
        switch self {
        case .header(let text, let level):
            return "header-\(level)-\(text.hashValue)"
        case .paragraph(let text):
            return "paragraph-\(text.hashValue)"
        case .list(let items):
            return "list-\(items.joined().hashValue)"
        }
    }
}

#if DEBUG
struct MarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        let sampleMarkdown = """
        # Brewing Recommendations
        
        Based on your analysis, here are my suggestions:
        
        ## Grind Adjustments
        - **Grind finer** by 2-3 clicks on your grinder
        - This will increase extraction and reduce sourness
        
        ## Brewing Parameters
        - Increase water temperature to **205°F**
        - Extend brew time by *30 seconds*
        - Use a 1:15 coffee-to-water ratio
        
        Your current grind shows `good uniformity` but needs adjustment for optimal extraction.
        """
        
        VStack(spacing: 20) {
            CustomMarkdownText(sampleMarkdown, color: .white)
                .padding()
                .background(Color.brown.opacity(0.7))
        }
        .padding()
        .background(Color.black)
        .previewDisplayName("Custom Markdown")
    }
}
#endif
