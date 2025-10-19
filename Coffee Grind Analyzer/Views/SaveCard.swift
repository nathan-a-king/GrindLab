//
//  SaveCard.swift
//  Coffee Grind Analyzer
//
//  Created by Xcode Assistant on 10/18/25.
//

import SwiftUI

struct SaveCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brown.opacity(0.5))
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}

#if DEBUG
#Preview("SaveCard Preview") {
    ZStack {
        Color.brown.opacity(0.7).ignoresSafeArea()
        SaveCard(title: "Save Analysis") {
            VStack(alignment: .leading, spacing: 8) {
                Text("This is where your save UI goes.")
                    .foregroundColor(.white)
                Button("Action") {}
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
#endif
