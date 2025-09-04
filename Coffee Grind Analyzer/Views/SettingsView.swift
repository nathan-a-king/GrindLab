//
//  SettingsView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//  Patched: integrates CalibrationImageOverlay for correct circle drawing with .scaledToFit
//

import SwiftUI

// CGRect.area extension removed - already defined elsewhere in project

struct SettingsView: View {
    @Binding var settings: AnalysisSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCalibration = false
    @State private var showingHelp = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Match History view background
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        analysisSection
                        
                        if settings.analysisMode == .advanced {
                            advancedSection
                        }
                        
                        calibrationSection
                        aboutSection
                        
                        #if DEBUG
                        debugSection
                        #endif
                    }
                    .padding(.horizontal)
                    .padding(.top)
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
        .sheet(isPresented: $showingCalibration) {
            CalibrationView(calibrationFactor: $settings.calibrationFactor)
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .onChange(of: settings.analysisMode) { _ in saveSettings() }
        .onChange(of: settings.contrastThreshold) { _ in saveSettings() }
        .onChange(of: settings.minParticleSize) { _ in saveSettings() }
        .onChange(of: settings.maxParticleSize) { _ in saveSettings() }
        .onChange(of: settings.enableAdvancedFiltering) { _ in saveSettings() }
        .onChange(of: settings.calibrationFactor) { _ in saveSettings() }
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
    
    private var calibrationSection: some View {
        SettingsCard(title: "Calibration") {
            VStack(spacing: 20) {
                // Current Calibration Display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Calibration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Text(String(format: "%.2f μm/pixel", settings.calibrationFactor))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Button("Calibrate") {
                            showingCalibration = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        Button("Reset") {
                            settings.calibrationFactor = 150.0
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                        .font(.caption)
                    }
                }
                
                Text("Use a ruler to measure 1 inch for accurate particle sizing")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    #if DEBUG
    private var debugSection: some View {
        SettingsCard(title: "Debug Tools") {
            VStack(spacing: 12) {
                Button(action: {
                    print("🧪 Running validation test...")
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
                    print("🎯 Generating grid test image...")
                    let (image, particles) = AnalysisValidation.createGridTestImage()
                    print("✅ Created test image with \(particles.count) particles")
                }) {
                    HStack {
                        Image(systemName: "grid")
                        Text("Generate Test Image (Grid)")
                        Spacer()
                    }
                    .foregroundColor(.white)
                }
                
                Button(action: {
                    print("🎲 Generating random test image...")
                    let (image, particles) = AnalysisValidation.createTestImage()
                    print("✅ Created test image with \(particles.count) particles")
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
                        print("🔄 Reset All Settings tapped")
                        AnalysisSettings.resetToDefaults()
                        settings.analysisMode = .standard
                        settings.contrastThreshold = 0.3
                        settings.minParticleSize = 100
                        settings.maxParticleSize = 3000
                        settings.enableAdvancedFiltering = false
                        settings.calibrationFactor = 150.0
                        print("✅ Settings reset complete")
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
        print("💾 saveSettings() called")
        settings.save()
        print("💾 settings.save() completed")
    }
}

// MARK: - Ruler-Based Calibration View
struct CalibrationView: View {
    @Binding var calibrationFactor: Double
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingImagePicker = false
    @State private var calibrationImage: UIImage?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Ruler measurement states
    @State private var startPoint: CGPoint?
    @State private var endPoint: CGPoint?
    @State private var isDragging: Bool = false
    
    // Computed properties
    private var pixelDistance: Double {
        guard let start = startPoint, let end = endPoint else { return 0 }
        return sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
    }
    
    private var isValidMeasurement: Bool {
        pixelDistance > 10 // At least 10 pixels
    }
    
    private var calculatedFactor: Double {
        guard isValidMeasurement else { return 0.0 }
        // 1 inch = 25.4 mm = 25400 μm
        return 25400 / pixelDistance
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Match Settings view background
                Color.brown.opacity(0.7)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        instructionSection
                        
                        if let image = calibrationImage {
                            rulerImageSection(image: image)
                        } else {
                            placeholderImageSection
                        }
                        
                        if isValidMeasurement {
                            calculationResultSection
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Ruler Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCalibration()
                    }
                    .disabled(!isValidMeasurement)
                    .fontWeight(.semibold)
                }
            }
            .alert("Calibration", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotoPickerView { image in
                calibrationImage = image
                // Reset measurement when new image is selected
                startPoint = nil
                endPoint = nil
                isDragging = false
            }
        }
    }
    
    // MARK: - View Components
    
    private var instructionSection: some View {
        SettingsCard(title: "Instructions") {
            VStack(alignment: .leading, spacing: 10) {
                Label("Take a photo of a ruler or measuring tape", systemImage: "1.circle.fill")
                    .foregroundColor(.white)
                
                Label("Pinch to zoom for precise alignment", systemImage: "2.circle.fill")
                    .foregroundColor(.white)
                
                Label("Drag a line over exactly 1 inch", systemImage: "3.circle.fill")
                    .foregroundColor(.white)
                
                Label("The app will count pixels automatically", systemImage: "4.circle.fill")
                    .foregroundColor(.white)
                
                Label("Save the calibration factor", systemImage: "5.circle.fill")
                    .foregroundColor(.white)
            }
            .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("For best results, use a clear ruler with distinct inch markings and good lighting")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 8)
                
                Text("Pinch to zoom in for more precise measurements")
                    .font(.caption)
                    .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.4))
            }
        }
    }
    
    private var placeholderImageSection: some View {
        Button(action: { showingImagePicker = true }) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.brown.opacity(0.3))
                .frame(height: 250)
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "ruler")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        Text("Select Ruler Photo")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Take a photo of a ruler or measuring tape")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundColor(.white.opacity(0.4))
                )
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
    }
    
    private func rulerImageSection(image: UIImage) -> some View {
        VStack(spacing: 16) {
            RulerCalibrationOverlay(
                image: image,
                startPoint: $startPoint,
                endPoint: $endPoint,
                isDragging: $isDragging
            )
            .frame(height: 350)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            HStack {
                Button(action: { showingImagePicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Change Image")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.brown.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
                
                if startPoint != nil || endPoint != nil {
                    Button(action: {
                        startPoint = nil
                        endPoint = nil
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                            Text("Clear")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            
            if pixelDistance > 0 {
                Text("Measured: \(Int(pixelDistance)) pixels")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    
    private var calculationResultSection: some View {
        SettingsCard(title: "Calibration Result") {
            VStack(spacing: 12) {
                Text(String(format: "%.2f μm/pixel", calculatedFactor))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.4))
                
                Text("Based on 1 inch = \(Int(pixelDistance)) pixels")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text("1 inch = 25.4 mm = 25,400 μm")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    
    private func saveCalibration() {
        guard isValidMeasurement else {
            alertMessage = "Please measure 1 inch on the ruler by dragging a line."
            showingAlert = true
            return
        }
        
        let newFactor = calculatedFactor
        
        // Sanity check - reasonable calibration factors for typical cameras
        guard newFactor > 0.1 && newFactor < 500 else {
            alertMessage = "Calibration factor seems unreasonable (\(String(format: "%.2f", newFactor)) μm/pixel). Please ensure you measured exactly 1 inch."
            showingAlert = true
            return
        }
        
        print("📏 Saving ruler calibration: \(newFactor) μm/pixel")
        print("📏 1 inch = \(Int(pixelDistance)) pixels")
        
        calibrationFactor = newFactor
        dismiss()
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
                        title: "Best Practices",
                        items: [
                            "Use natural light when possible",
                            "Avoid shadows on the coffee",
                            "Spread coffee evenly in a thin layer",
                            "Keep camera steady during capture",
                            "Clean camera lens for best results"
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
            .navigationTitle("Help & Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func helpSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                        
                        Text(item)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
