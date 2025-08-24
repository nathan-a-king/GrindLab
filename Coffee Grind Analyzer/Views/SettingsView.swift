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
            Form {
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
        Section("Analysis Settings") {
            Picker("Analysis Mode", selection: $settings.analysisMode) {
                ForEach(AnalysisSettings.AnalysisMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            VStack(alignment: .leading, spacing: 8) {
                Text(modeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Contrast Threshold")
                    Spacer()
                    Text(String(format: "%.1f", settings.contrastThreshold))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $settings.contrastThreshold, in: 0.1...0.9, step: 0.1)
                    .tint(.blue)
                
                Text("Higher values detect only high-contrast particles")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        Section("Advanced Options") {
            Toggle("Enhanced Filtering", isOn: $settings.enableAdvancedFiltering)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Min Particle Size")
                    Spacer()
                    Text("\(settings.minParticleSize) px")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(settings.minParticleSize) },
                    set: { settings.minParticleSize = Int($0) }
                ), in: 5...50, step: 1)
                .tint(.green)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Max Particle Size")
                    Spacer()
                    Text("\(settings.maxParticleSize) px")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(settings.maxParticleSize) },
                    set: { settings.maxParticleSize = Int($0) }
                ), in: 100...2000, step: 50)
                .tint(.orange)
            }
        }
    }
    
    private var calibrationSection: some View {
        Section("Calibration") {
            HStack {
                VStack(alignment: .leading) {
                    Text("Calibration Factor")
                    Text(String(format: "%.2f μm/pixel", settings.calibrationFactor))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Calibrate") {
                    showingCalibration = true
                }
                .buttonStyle(.bordered)
            }
            
            Button("Reset to Default") {
                settings.calibrationFactor = 1.0
            }
            .foregroundColor(.red)
        }
    }
    
    #if DEBUG
    private var debugSection: some View {
        Section("Debug Tools") {
            Button("Run Analysis Validation Test") {
                print("🧪 Running validation test...")
                let engine = CoffeeAnalysisEngine()
                engine.runValidationTest()
            }
            .foregroundColor(.blue)
            
            Button("Generate Test Image (Grid)") {
                print("🎯 Generating grid test image...")
                let (image, particles) = AnalysisValidation.createGridTestImage()
                print("✅ Created test image with \(particles.count) particles")
                // You could save this image or analyze it directly
            }
            .foregroundColor(.green)
            
            Button("Generate Test Image (Random)") {
                print("🎲 Generating random test image...")
                let (image, particles) = AnalysisValidation.createTestImage()
                print("✅ Created test image with \(particles.count) particles")
            }
            .foregroundColor(.orange)
        }
    }
    #endif
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Build")
                Spacer()
                Text("240822.1")
                    .foregroundColor(.secondary)
            }
            
            Button("Help & Tips") {
                showingHelp = true
            }
            
            Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            
            // Working reset button - replaced the problematic one
            Button(action: {
                print("🔄 Reset All Settings tapped")
                AnalysisSettings.resetToDefaults()
                settings.analysisMode = .standard
                settings.contrastThreshold = 0.3
                settings.minParticleSize = 10
                settings.maxParticleSize = 1000
                settings.enableAdvancedFiltering = false
                settings.calibrationFactor = 1.0
                print("✅ Settings reset complete")
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.red)
                    Text("Reset All Settings")
                        .foregroundColor(.red)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Ruler Calibration")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Take a photo of a ruler or measuring tape", systemImage: "1.circle.fill")
                    .foregroundColor(.primary)
                
                Label("Drag a line over exactly 1 inch", systemImage: "2.circle.fill")
                    .foregroundColor(.primary)
                
                Label("The app will count pixels automatically", systemImage: "3.circle.fill")
                    .foregroundColor(.primary)
                
                Label("Save the calibration factor", systemImage: "4.circle.fill")
                    .foregroundColor(.primary)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Text("💡 For best results, use a clear ruler with distinct inch markings and good lighting")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var placeholderImageSection: some View {
        Button(action: { showingImagePicker = true }) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "ruler")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("Select Ruler Photo")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("Take a photo of a ruler or measuring tape")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundColor(.blue.opacity(0.3))
                )
        }
    }
    
    private func rulerImageSection(image: UIImage) -> some View {
        VStack(spacing: 12) {
            RulerCalibrationOverlay(
                image: image,
                startPoint: $startPoint,
                endPoint: $endPoint,
                isDragging: $isDragging
            )
            .frame(height: 350)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 2)
            )
            
            HStack {
                Button("Change Image") {
                    showingImagePicker = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Spacer()
                
                if startPoint != nil || endPoint != nil {
                    Button("Clear Measurement") {
                        startPoint = nil
                        endPoint = nil
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            if pixelDistance > 0 {
                Text("Measured: \(Int(pixelDistance)) pixels")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    
    private var calculationResultSection: some View {
        VStack(spacing: 12) {
            Text("Calibration Result")
                .font(.headline)
            
            VStack(spacing: 8) {
                Text(String(format: "%.2f μm/pixel", calculatedFactor))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("Based on 1 inch = \(Int(pixelDistance)) pixels")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("1 inch = 25.4 mm = 25,400 μm")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
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
