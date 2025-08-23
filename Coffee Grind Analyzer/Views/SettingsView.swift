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

// MARK: - Updated Calibration View with Auto-Detection
struct CalibrationView: View {
    @Binding var calibrationFactor: Double
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingImagePicker = false
    @State private var calibrationImage: UIImage?
    @State private var knownDistance: Double = 10.0 // mm
    @State private var measuredPixels: Double = 100.0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Auto-detection states
    @State private var isDetecting = false
    @State private var detectedCoins: [CoinDetection] = []
    @State private var selectedCoin: CoinDetection?
    @State private var showManualInput = false
    @State private var detectionProgress: Double = 0.0
    
    // Computed properties
    private var isValidInput: Bool {
        knownDistance > 0 && measuredPixels > 0
    }
    
    private var calculatedFactor: Double {
        guard isValidInput else { return 0.0 }
        return (knownDistance * 1000) / measuredPixels
    }
    
    // Circles to draw in overlay (image-pixel coords)
    private var overlayDetections: [DetectedCircle] {
        if let s = selectedCoin {
            return [
                DetectedCircle(
                    center: s.center,
                    radius: s.diameterPixels / 2.0,
                    circularity: 1.0,
                    averageColor: .clear,
                    edgeStrength: 1.0
                )
            ]
        } else {
            // show a few top candidates when none selected
            return detectedCoins.prefix(3).map { c in
                DetectedCircle(
                    center: c.center,
                    radius: c.diameterPixels / 2.0,
                    circularity: 1.0,
                    averageColor: .clear,
                    edgeStrength: 1.0
                )
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    instructionSection
                    
                    if let image = calibrationImage {
                        calibrationImageSection(image: image)
                    } else {
                        placeholderImageSection
                    }
                    
                    if calibrationImage != nil {
                        detectionSection
                    }
                    
                    if !detectedCoins.isEmpty {
                        detectedCoinsSection
                    }
                    
                    if showManualInput || detectedCoins.isEmpty && calibrationImage != nil {
                        manualMeasurementSection
                    }
                    
                    if selectedCoin != nil || (showManualInput && isValidInput) {
                        calculationResultSection
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .onTapGesture {
                hideKeyboard()
            }
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
                        saveCalibration()
                    }
                    .disabled(selectedCoin == nil && !isValidInput)
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
                // Reset detection state when new image is selected
                detectedCoins = []
                selectedCoin = nil
                showManualInput = false
            }
        }
    }
    
    // MARK: - View Components
    
    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Automatic Calibration")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Place a coin next to your coffee grounds", systemImage: "1.circle.fill")
                    .foregroundColor(.primary)
                
                Label("Take a photo with both visible", systemImage: "2.circle.fill")
                    .foregroundColor(.primary)
                
                Label("Let the app detect and measure the coin", systemImage: "3.circle.fill")
                    .foregroundColor(.primary)
                
                Label("Save the calibration", systemImage: "4.circle.fill")
                    .foregroundColor(.primary)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            // Supported coins info
            DisclosureGroup("Supported Coins") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(ReferenceObject.allCases, id: \.self) { coin in
                        HStack {
                            Text(coin.displayName)
                                .font(.caption)
                            Spacer()
                            Text("\(String(format: "%.2f", coin.diameterMM)) mm")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
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
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("Select Calibration Image")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("Include a coin in the photo")
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
    
    // Replaced to use CalibrationImageOverlay (handles scaledToFit & letterboxing)
    private func calibrationImageSection(image: UIImage) -> some View {
        VStack(spacing: 8) {
            CalibrationImageOverlay(
                image: image,
                detections: overlayDetections,
                lineWidth: 3,
                color: .green
            )
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Button("Change Image") {
                showingImagePicker = true
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
    }
    
    private var detectionSection: some View {
        detectionSectionView
    }
    
    private var detectedCoinsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detected Coins")
                    .font(.headline)
                Spacer()
                Text("\(detectedCoins.count) found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Only show up to 3 best detections to avoid clutter
            ForEach(Array(detectedCoins.prefix(3).enumerated()), id: \.offset) { index, detection in
                Button(action: { selectCoin(detection) }) {
                    HStack {
                        Image(systemName: isSelected(detection) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected(detection) ? .green : .gray)
                        
                        VStack(alignment: .leading) {
                            Text(detection.coinType.displayName)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text("\(Int(detection.diameterPixels)) pixels")
                                Text("•")
                                Text("Confidence: \(Int(detection.confidence * 100))%")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(String(format: "%.2f", detection.calibrationFactor))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("μm/pixel")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected(detection) ?
                                  Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Show additional detections count if there are more than 3
            if detectedCoins.count > 3 {
                Text("+ \(detectedCoins.count - 3) more detection\(detectedCoins.count - 3 == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            // Show manual measurement option
            if !showManualInput {
                Button("Use Manual Measurement Instead") {
                    withAnimation {
                        showManualInput = true
                        selectedCoin = nil
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 4)
            }
        }
    }
    
    // Helper function to check if a detection is selected
    private func isSelected(_ detection: CoinDetection) -> Bool {
        guard let selected = selectedCoin else { return false }
        
        // Check if it's the same coin type and approximately the same position
        return selected.coinType == detection.coinType &&
               abs(selected.center.x - detection.center.x) < 10 &&
               abs(selected.center.y - detection.center.y) < 10
    }
    
    private var manualMeasurementSection: some View {
        VStack(spacing: 16) {
            Text("Manual Measurement")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Known Distance (mm)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Distance in millimeters", value: $knownDistance, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .onSubmit { hideKeyboard() }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Measured Pixels")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Number of pixels", value: $measuredPixels, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .onSubmit { hideKeyboard() }
            }
            
            Text("💡 Tip: Measure the diameter of a coin or the length of a ruler segment")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var calculationResultSection: some View {
        VStack(spacing: 12) {
            Text("Calibration Result")
                .font(.headline)
            
            if let selected = selectedCoin {
                VStack(spacing: 8) {
                    Text(String(format: "%.2f μm/pixel", selected.calibrationFactor))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Based on \(selected.coinType.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Confidence: \(Int(selected.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(selected.confidence > 0.8 ? .green : .orange)
                }
            } else if showManualInput && isValidInput {
                VStack(spacing: 8) {
                    Text(String(format: "%.2f μm/pixel", calculatedFactor))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Manual measurement")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Perform Automatic Calibration
    private func performAutomaticCalibration() {
        guard let image = calibrationImage else { return }
        
        isDetecting = true
        detectedCoins = []
        selectedCoin = nil
        detectionProgress = 0.0
        
        // Show progress
        withAnimation {
            detectionProgress = 0.2
        }
        
        let detector = CoinCalibrationDetector()
        
        // Create a work item for cancellation
        var isCancelled = false
        
        // Perform detection
        detector.detectAndMeasureCoins(in: image) { coins in
            guard !isCancelled else { return }
            
            DispatchQueue.main.async {
                withAnimation {
                    self.detectionProgress = 0.8
                }
                
                // Filter out low confidence and deduplicate
                let filteredCoins = coins.filter { $0.confidence > 0.3 }  // Lowered from 0.5
                let deduplicatedCoins = self.deduplicateCoinsImproved(filteredCoins)
                
                self.detectedCoins = deduplicatedCoins
                self.isDetecting = false
                self.detectionProgress = 1.0
                
                if let bestCoin = deduplicatedCoins.first {
                    // Auto-select only if confidence is high
                    if bestCoin.confidence > 0.6 {  // Lowered from 0.7
                        self.selectCoin(bestCoin)
                        self.alertMessage = "✅ \(bestCoin.coinType.displayName) detected with \(Int(bestCoin.confidence * 100))% confidence!"
                    } else {
                        // Still show it but with a warning
                        self.alertMessage = "⚠️ \(bestCoin.coinType.displayName) detected with moderate confidence (\(Int(bestCoin.confidence * 100))%). Please verify or use manual measurement."
                        // Don't auto-select, let user choose
                    }
                    self.showingAlert = true
                } else {
                    self.alertMessage = "No coins detected. Please ensure:\n• Coin is clearly visible\n• Good lighting\n• Contrasting background\n\nYou can also use manual measurement."
                    self.showingAlert = true
                    self.showManualInput = true
                }
                
                // Reset progress after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        self.detectionProgress = 0.0
                    }
                }
            }
        }
        
        // Timeout after 30 seconds (increased from 20)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if self.isDetecting {
                isCancelled = true
                self.isDetecting = false
                self.detectionProgress = 0.0
                self.alertMessage = "Detection timeout. The image might be too large or complex. Try:\n• Taking a photo from further away\n• Using better lighting\n• Cropping the image\n• Using manual measurement"
                self.showingAlert = true
                self.showManualInput = true
            }
        }
    }

    // MARK: - Improved Deduplication (rename to avoid conflict)
    private func deduplicateCoinsImproved(_ coins: [CoinDetection]) -> [CoinDetection] {
        guard !coins.isEmpty else { return [] }
        
        print("🔍 Deduplicating \(coins.count) coins")
        
        var uniqueCoins: [CoinDetection] = []
        
        for coin in coins {
            let isUnique = !uniqueCoins.contains { existing in
                // Check spatial overlap
                let dx = coin.center.x - existing.center.x
                let dy = coin.center.y - existing.center.y
                let distance = sqrt(dx * dx + dy * dy)
                let avgRadius = (coin.diameterPixels + existing.diameterPixels) / 4
                
                // Check if centers are too close
                if distance < avgRadius * 1.5 {
                    return true
                }
                
                // Check if bounding boxes overlap significantly
                let intersection = coin.boundingBox.intersection(existing.boundingBox)
                let unionArea = coin.boundingBox.union(existing.boundingBox).area
                let overlapRatio = intersection.area / unionArea
                
                return overlapRatio > 0.3
            }
            
            if isUnique {
                uniqueCoins.append(coin)
            } else {
                // Replace with higher confidence detection
                if let existingIndex = uniqueCoins.firstIndex(where: { existing in
                    let dx = coin.center.x - existing.center.x
                    let dy = coin.center.y - existing.center.y
                    let distance = sqrt(dx * dx + dy * dy)
                    let avgRadius = (coin.diameterPixels + existing.diameterPixels) / 4
                    return distance < avgRadius * 1.5
                }) {
                    if coin.confidence > uniqueCoins[existingIndex].confidence {
                        uniqueCoins[existingIndex] = coin
                    }
                }
            }
        }
        
        // Sort by confidence and limit results
        uniqueCoins.sort { $0.confidence > $1.confidence }
        
        // Filter coins by reasonable size relative to image
        let imageSize = calibrationImage?.size ?? CGSize(width: 1000, height: 1000)
        let minDiameter = min(imageSize.width, imageSize.height) * 0.02  // At least 2% of image
        let maxDiameter = min(imageSize.width, imageSize.height) * 1.2   // Allow up to 120% of smaller dimension
        
        print("📏 Image size: \(imageSize), diameter range: \(minDiameter)-\(maxDiameter)")
        
        let beforeFilterCount = uniqueCoins.count
        uniqueCoins = uniqueCoins.filter { coin in
            let valid = coin.diameterPixels > minDiameter
            // For very large coins, just check they're not impossibly large
            if coin.diameterPixels > maxDiameter {
                // Allow it if it's less than both dimensions
                let valid = coin.diameterPixels < imageSize.width && coin.diameterPixels < imageSize.height
                if !valid {
                    print("❌ Filtered out coin with diameter \(coin.diameterPixels) pixels (larger than image dimensions)")
                } else {
                    print("⚠️ Large coin detected with diameter \(coin.diameterPixels) pixels (larger than expected but keeping)")
                }
                return valid
            } else if !valid {
                print("❌ Filtered out coin with diameter \(coin.diameterPixels) pixels (too small)")
            } else {
                print("✅ Keeping coin with diameter \(coin.diameterPixels) pixels")
            }
            return valid
        }
        
        print("📊 Filtered from \(beforeFilterCount) to \(uniqueCoins.count) coins")
        
        return Array(uniqueCoins.prefix(5))  // Maximum 5 detections
    }

    // MARK: - Updated Detection Section View
    private var detectionSectionView: some View {
        VStack(spacing: 16) {
            Button {
                performAutomaticCalibration()
            } label: {
                HStack(spacing: 12) {
                    if isDetecting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "viewfinder.circle")
                    }
                    
                    Text(isDetecting ? "Detecting..." : "Auto-Detect Coin")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDetecting ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isDetecting)
            
            // Progress bar when detecting
            if isDetecting && detectionProgress > 0 {
                ProgressView(value: detectionProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .transition(.opacity)
            }
            
            // Tips for better detection
            if detectedCoins.isEmpty && !isDetecting && calibrationImage != nil {
                VStack(spacing: 8) {
                    Text("Tips for better detection:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Use good lighting", systemImage: "light.max")
                        Label("Place coin on contrasting surface", systemImage: "circle.square")
                        Label("Keep coin fully visible", systemImage: "eye")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Button("Enter Measurements Manually") {
                    withAnimation {
                        showManualInput = true
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
    }
    
    private func selectCoin(_ detection: CoinDetection) {
        selectedCoin = detection
        knownDistance = detection.coinType.diameterMM
        measuredPixels = detection.diameterPixels
        showManualInput = false
    }
    
    private func saveCalibration() {
        let newFactor: Double
        
        if let selected = selectedCoin {
            newFactor = selected.calibrationFactor
            print("📏 Saving auto-detected calibration: \(newFactor) μm/pixel")
            print("📏 Coin: \(selected.coinType.displayName), Confidence: \(selected.confidence)")
        } else if isValidInput {
            newFactor = calculatedFactor
            print("📏 Saving manual calibration: \(newFactor) μm/pixel")
            print("📏 Known distance: \(knownDistance) mm, Measured pixels: \(measuredPixels)")
        } else {
            alertMessage = "Please complete the calibration first."
            showingAlert = true
            return
        }
        
        // Sanity check
        guard newFactor > 0.01 && newFactor < 1000 else {
            alertMessage = "Calibration factor seems unreasonable. Please check your measurements."
            showingAlert = true
            return
        }
        
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
