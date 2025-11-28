//
//  SettingsView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//  Patched: integrates CalibrationImageOverlay for correct circle drawing with .scaledToFit
//

import SwiftUI
import OSLog

private let settingsLogger = Logger(subsystem: "com.nateking.GrindLab", category: "SettingsView")

// CGRect.area extension removed - already defined elsewhere in project

struct SettingsView: View {
    @Binding var settings: AnalysisSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showingHelp = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height

                ZStack {
                    // Match History view background
                    Color.brown.opacity(0.7)
                        .ignoresSafeArea()

                    ScrollView {
                        settingsContent(isLandscape: isLandscape)
                            .frame(minHeight: geometry.size.height)
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .onChange(of: settings.analysisMode) { saveSettings() }
        .onChange(of: settings.contrastThreshold) { saveSettings() }
        .onChange(of: settings.minParticleSize) { saveSettings() }
        .onChange(of: settings.maxParticleSize) { saveSettings() }
        .onChange(of: settings.enableAdvancedFiltering) { saveSettings() }
        .onChange(of: settings.calibrationFactor) { saveSettings() }
    }

    @ViewBuilder
    private func settingsContent(isLandscape: Bool) -> some View {
        if isLandscape {
            // Landscape: 2-column grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                analysisSection

                if settings.analysisMode == .advanced {
                    advancedSection
                }

                aboutSection

                #if DEBUG
                debugSection
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else {
            // Portrait: stacked layout
            VStack(spacing: 20) {
                analysisSection

                if settings.analysisMode == .advanced {
                    advancedSection
                }

                aboutSection

                #if DEBUG
                debugSection
                #endif
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }

    private var analysisSection: some View {
        SettingsCard(title: "Analysis Settings") {
            VStack(spacing: 20) {
                // Analysis Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analysis Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Picker("Analysis Mode", selection: $settings.analysisMode) {
                        ForEach(AnalysisSettings.AnalysisMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .colorScheme(.dark)
                    .accentColor(.white)
                    
                    Text(modeDescription)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Contrast Threshold
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Contrast Threshold")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.1f", settings.contrastThreshold))
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: $settings.contrastThreshold, in: 0.1...0.9, step: 0.1)
                        .tint(.white)
                    
                    Text("Higher values detect only high-contrast particles")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    private var modeDescription: String {
        switch settings.analysisMode {
        case .basic:
            return "Quick analysis with essential metrics only. Good for casual users."
        case .standard:
            return "Balanced analysis with comprehensive particle detection and statistics."
        case .advanced:
            return "Detailed analysis with fine-tuned controls for particle filtering and detection."
        }
    }
    
    private var advancedSection: some View {
        SettingsCard(title: "Advanced Options") {
            VStack(spacing: 20) {
                // Enhanced Filtering Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enhanced Filtering")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Text("Improved quality with shape analysis")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Toggle("", isOn: $settings.enableAdvancedFiltering)
                        .tint(.blue)
                }
                
                // Min Particle Size
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Min Particle Size")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(settings.minParticleSize) μm")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(settings.minParticleSize) },
                        set: { settings.minParticleSize = Int($0) }
                    ), in: 50...500, step: 10)
                    .tint(.white)
                }
                
                // Max Particle Size
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Max Particle Size")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(settings.maxParticleSize) μm")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(settings.maxParticleSize) },
                        set: { settings.maxParticleSize = Int($0) }
                    ), in: 500...3000, step: 50)
                    .tint(.white)
                }
            }
        }
    }

    #if DEBUG
    private var debugSection: some View {
        SettingsCard(title: "Debug Tools") {
            VStack(spacing: 12) {
                Button(action: {
                    settingsLogger.info("Running validation test")
                    let engine = CoffeeAnalysisEngine()
                    engine.runValidationTest()
                }) {
                    HStack {
                        Image(systemName: "testtube.2")
                        Text("Run Analysis Validation Test")
                        Spacer()
                    }
                    .foregroundColor(.white)
                }

                Button(action: {
                    settingsLogger.debug("Generating grid test image")
                    let (_, particles) = AnalysisValidation.createGridTestImage()
                    settingsLogger.debug("Generated grid test image with \(particles.count, privacy: .public) particles")
                }) {
                    HStack {
                        Image(systemName: "grid")
                        Text("Generate Test Image (Grid)")
                        Spacer()
                    }
                    .foregroundColor(.white)
                }

                Button(action: {
                    settingsLogger.debug("Generating random test image")
                    let (_, particles) = AnalysisValidation.createTestImage()
                    settingsLogger.debug("Generated random test image with \(particles.count, privacy: .public) particles")
                }) {
                    HStack {
                        Image(systemName: "dice")
                        Text("Generate Test Image (Random)")
                        Spacer()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    #endif
    
    private var aboutSection: some View {
        SettingsCard(title: "About") {
            VStack(spacing: 20) {
                // App Info
                VStack(spacing: 12) {
                    HStack {
                        Text("Version")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Build")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("240822.1")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: { showingHelp = true }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Help & Tips")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                    
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        settingsLogger.info("Reset all settings requested")
                        AnalysisSettings.resetToDefaults()
                        settings.analysisMode = .standard
                        settings.contrastThreshold = 0.3
                        settings.minParticleSize = 100
                        settings.maxParticleSize = 3000
                        settings.enableAdvancedFiltering = false
                        settings.calibrationFactor = 150.0
                        settingsLogger.info("Settings reset completed")
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset All Settings")
                            Spacer()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        settingsLogger.debug("saveSettings invoked")
        settings.save()
        settingsLogger.debug("Analysis settings persisted")
    }
}


// MARK: - Settings Card Component

struct SettingsCard<Content: View>: View {
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

// MARK: - Help View

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                // Match Settings view background
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        helpSection(
                            title: "Getting Started",
                            items: [
                                "Choose your grind type (Filter, Espresso, etc.)",
                                "Place coffee on a white or contrasting surface",
                                "Ensure good, even lighting",
                                "Capture or select an image",
                                "Wait for analysis to complete"
                            ]
                        )
                        
                        helpSection(
                            title: "Calibration",
                            items: [
                                "For accurate results, all analysis photos must be taken from the same distance as the calibration photo.",
                                "Changing the capture distance requires a new calibration to ensure consistent measurements."
                            ]
                        )

                        helpSection(
                            title: "Best Practices",
                            items: [
                                "Use natural light when possible",
                                "Avoid shadows on the coffee",
                                "Spread coffee evenly in a thin layer",
                                "Keep camera steady during capture"
                            ]
                        )

                        helpSection(
                            title: "Understanding Results",
                            items: [
                                "Uniformity Score: Higher is better (0-100%)",
                                "Average Size: Mean particle size in microns",
                                "Fines: Small particles that can cause over-extraction",
                                "Boulders: Large particles that under-extract",
                                "Confidence: Reliability of the analysis"
                            ]
                        )

                        helpSection(
                            title: "Troubleshooting",
                            items: [
                                "Poor results? Check lighting and contrast",
                                "No particles detected? Use white background",
                                "Inaccurate sizes? Calibrate the app",
                                "App crashes? Restart and try again",
                                "Still having issues? Check app permissions"
                            ]
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Help & Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func helpSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.4))
                            .fontWeight(.bold)

                        Text(item)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                }
            }
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

// MARK: - Keyboard Dismiss Extension

extension View {
    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: .constant(AnalysisSettings()))
    }
}
#endif
