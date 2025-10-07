//
//  BrewTabView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 10/4/25.
//

import SwiftUI

struct BrewTabView: View {
    @EnvironmentObject var brewState: BrewAppState
    @State private var showingTimer = false

    var body: some View {
        NavigationView {
            ZStack {
                if showingTimer {
                    BrewTimerView(showingTimer: $showingTimer)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Recipes") {
                                    showingTimer = false
                                }
                                .foregroundColor(.white)
                            }
                        }
                } else {
                    RecipeSelectionView(showingTimer: $showingTimer)
                }
            }
        }
    }
}
