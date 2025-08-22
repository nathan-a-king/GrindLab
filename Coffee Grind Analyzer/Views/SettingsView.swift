//
//  SettingsView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI

struct SettingsView: View {
    @Binding var settings: AnalysisSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCalibration = false
    @State private var showingHelp = false
    
    var body: some View {
        NavigationView {
            Form {
                analysisSection
                
                if settings.analysisMode != .basic {
                    advancedSection
                }
                
                calibrationSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCalibration) {
            CalibrationView(calibrationFactor: $settings.calibrationFactor)
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
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
            
            Button("Reset All Settings") {
                settings = AnalysisSettings()
            }
            .foregroundColor(.red)
        }
    }
}

// MARK: - Calibration View

struct CalibrationView: View {
    @Binding var calibrationFactor: Double
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingImagePicker = false
    @State private var calibrationImage: UIImage?
    @State private var knownDistance: Double = 10.0 // mm
    @State private var measuredPixels: Double = 100.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                instructionSection
                
                if let image = calibrationImage {
                    calibrationImageSection(image: image)
                } else {
                    placeholderImageSection
                }
                
                measurementSection
                calculationSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        calculateCalibration()
                        dismiss()
                    }
                    .disabled(calibrationImage == nil)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotoPickerView { image in
                calibrationImage = image
            }
        }
    }
    
    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calibration Instructions")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Place a ruler or coin in your photo", systemImage: "1.circle.fill")
                Label("Capture or select the calibration image", systemImage: "2.circle.fill")
                Label("Measure the known object in pixels", systemImage: "3.circle.fill")
                Label("Enter the real-world size", systemImage: "4.circle.fill")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var placeholderImageSection: some View {
        Button(action: { showingImagePicker = true }) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("Select Calibration Image")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                )
        }
    }
    
    private func calibrationImageSection(image: UIImage) -> some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .cornerRadius(12)
            
            Button("Change Image") {
                showingImagePicker = true
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
    }
    
    private var measurementSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("Known Distance (mm)")
                    .font(.subheadline)
                
                TextField("Distance", value: $knownDistance, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
            }
            
            VStack(alignment: .leading) {
                Text("Measured Pixels")
                    .font(.subheadline)
                
                TextField("Pixels", value: $measuredPixels, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
            }
        }
    }
    
    private var calculationSection: some View {
        VStack(spacing: 12) {
            Text("Calculated Calibration")
                .font(.headline)
            
            let calculatedFactor = (knownDistance * 1000) / measuredPixels // Convert mm to μm
            
            Text(String(format: "%.2f μm/pixel", calculatedFactor))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            Text("This will be your new calibration factor")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func calculateCalibration() {
        let newFactor = (knownDistance * 1000) / measuredPixels // Convert mm to μm
        calibrationFactor = newFactor
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

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settings: .constant(AnalysisSettings()))
    }
}
#endif
