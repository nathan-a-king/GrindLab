import SwiftUI
import AVFoundation
import UIKit
import Combine

// MARK: - Grind Type Enum
enum GrindType: CaseIterable {
    case filter
    case espresso
    
    var displayName: String {
        switch self {
        case .filter:
            return "Filter/Pour-Over"
        case .espresso:
            return "Espresso"
        }
    }
    
    var analysisParameters: AnalysisParameters {
        switch self {
        case .filter:
            return AnalysisParameters(
                targetSizeRange: "0.7-1.2mm",
                optimalUniformity: 80,
                maxFinesPercentage: 15
            )
        case .espresso:
            return AnalysisParameters(
                targetSizeRange: "0.2-0.5mm",
                optimalUniformity: 85,
                maxFinesPercentage: 25
            )
        }
    }
}

// MARK: - Analysis Parameters
struct AnalysisParameters {
    let targetSizeRange: String
    let optimalUniformity: Double
    let maxFinesPercentage: Double
}

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingResults = false
    @State private var analysisResults: AnalysisResults?
    @State private var showingSettings = false
    @State private var selectedGrindType: GrindType?
    @State private var showingCamera = false
    
    var body: some View {
        NavigationView {
            if showingCamera, let grindType = selectedGrindType {
                cameraView(for: grindType)
            } else {
                grindSelectionView
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingResults) {
            if let results = analysisResults {
                DetailedResultsView(results: results)
            }
        }
    }
    
    // MARK: - Grind Selection View
    private var grindSelectionView: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.brown.opacity(0.8), Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Coffee Grind Analyzer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Select your grind type to begin analysis")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // Grind type selection cards
                VStack(spacing: 20) {
                    grindTypeCard(
                        type: .filter,
                        title: "Filter/Pour-Over",
                        description: "Medium to coarse grind for drip coffee, pour-over, and French press",
                        icon: "drop.circle.fill",
                        color: .blue
                    )
                    
                    grindTypeCard(
                        type: .espresso,
                        title: "Espresso",
                        description: "Fine grind for espresso machines and moka pots",
                        icon: "cup.and.saucer.fill",
                        color: .orange
                    )
                }
                
                Spacer()
                
                // Settings button
                Button(action: { showingSettings = true }) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
    }
    
    private func grindTypeCard(type: GrindType, title: String, description: String, icon: String, color: Color) -> some View {
        Button(action: {
            selectedGrindType = type
            showingCamera = true
            cameraManager.checkPermissions()
        }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                    .frame(width: 50)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Camera View
    private func cameraView(for grindType: GrindType) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button
                cameraHeaderView(grindType: grindType)
                
                // Camera View
                cameraPreviewView
                
                // Controls
                controlsView
                
                // Results Section (if available)
                if let results = analysisResults {
                    resultsView(results: results)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func cameraHeaderView(grindType: GrindType) -> some View {
        HStack {
            Button(action: {
                showingCamera = false
                selectedGrindType = nil
                analysisResults = nil
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Text(grindType.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var cameraPreviewView: some View {
        ZStack {
            // Camera Preview
            CameraPreview(session: cameraManager.session)
                .aspectRatio(4/3, contentMode: .fit)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            
            // Grid overlay for composition
            gridOverlay
            
            // Focus indicator
            if cameraManager.showFocusIndicator {
                focusIndicator
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    private var gridOverlay: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                VStack {
                    Divider().background(Color.white.opacity(0.3))
                    Spacer()
                    Divider().background(Color.white.opacity(0.3))
                }
                .overlay(
                    HStack {
                        Divider().background(Color.white.opacity(0.3))
                        Spacer()
                        Divider().background(Color.white.opacity(0.3))
                    }
                )
            )
            .opacity(cameraManager.showGrid ? 1 : 0)
    }
    
    private var focusIndicator: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .position(cameraManager.focusPoint)
            .opacity(cameraManager.showFocusIndicator ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: cameraManager.showFocusIndicator)
    }
    
    private var controlsView: some View {
        HStack(spacing: 30) {
            // Flash toggle
            Button(action: { cameraManager.toggleFlash() }) {
                VStack(spacing: 4) {
                    Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.title2)
                    Text("Flash")
                        .font(.caption)
                }
                .foregroundColor(cameraManager.isFlashOn ? .yellow : .white)
            }
            
            // Grid toggle
            Button(action: { cameraManager.toggleGrid() }) {
                VStack(spacing: 4) {
                    Image(systemName: "grid")
                        .font(.title2)
                    Text("Grid")
                        .font(.caption)
                }
                .foregroundColor(cameraManager.showGrid ? .blue : .white)
            }
            
            // Capture button
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .scaleEffect(cameraManager.isCapturing ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: cameraManager.isCapturing)
                }
            }
            .disabled(cameraManager.isCapturing)
            
            // Timer toggle
            Button(action: { cameraManager.toggleTimer() }) {
                VStack(spacing: 4) {
                    Image(systemName: cameraManager.timerEnabled ? "timer" : "timer")
                        .font(.title2)
                    Text("Timer")
                        .font(.caption)
                }
                .foregroundColor(cameraManager.timerEnabled ? .orange : .white)
            }
            
            // Gallery
            Button(action: { /* Open gallery */ }) {
                VStack(spacing: 4) {
                    Image(systemName: "photo.stack")
                        .font(.title2)
                    Text("Gallery")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
    
    private func resultsView(results: AnalysisResults) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Analysis Results")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View Details") {
                    showingResults = true
                }
                .foregroundColor(.blue)
                .font(.subheadline)
            }
            
            HStack(spacing: 20) {
                resultCard(title: "Uniformity", value: "\(Int(results.uniformityScore))%", color: results.uniformityColor)
                resultCard(title: "Avg Size", value: results.averageSize, color: .blue)
                resultCard(title: "Fines", value: "\(Int(results.finesPercentage))%", color: .orange)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
        .padding(.horizontal, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func resultCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            // Simulate analysis (replace with actual analysis)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let mockResults = AnalysisResults(
                    uniformityScore: Double.random(in: 60...95),
                    averageSize: "0.8mm",
                    finesPercentage: Double.random(in: 5...20),
                    image: image
                )
                
                withAnimation(.spring()) {
                    self.analysisResults = mockResults
                }
            }
        }
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isFlashOn = false
    @Published var showGrid = false
    @Published var timerEnabled = false
    @Published var isCapturing = false
    @Published var showFocusIndicator = false
    @Published var focusPoint = CGPoint(x: 100, y: 100)
    
    private var photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            session.beginConfiguration()
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            
            session.sessionPreset = .photo
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
        } catch {
            print("Camera setup error: \(error)")
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    func toggleGrid() {
        showGrid.toggle()
    }
    
    func toggleTimer() {
        timerEnabled.toggle()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        isCapturing = true
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        // Simulate capture animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isCapturing = false
        }
    }
}

// MARK: - Photo Capture Delegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            captureCompletion?(nil)
            return
        }
        
        captureCompletion?(image)
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Analysis Results Model
struct AnalysisResults {
    let uniformityScore: Double
    let averageSize: String
    let finesPercentage: Double
    let image: UIImage?
    
    var uniformityColor: Color {
        switch uniformityScore {
        case 80...: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var analysisMode = 0
    @State private var showAdvancedOptions = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Analysis Settings") {
                    Picker("Mode", selection: $analysisMode) {
                        Text("Basic").tag(0)
                        Text("Advanced").tag(1)
                        Text("Professional").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Toggle("Show Advanced Options", isOn: $showAdvancedOptions)
                }
                
                if showAdvancedOptions {
                    Section("Advanced") {
                        HStack {
                            Text("Sensitivity")
                            Spacer()
                            Text("Medium")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Calibration")
                            Spacer()
                            Button("Calibrate") {
                                // Calibration action
                            }
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
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
    }
}

// MARK: - Detailed Results View
struct DetailedResultsView: View {
    let results: AnalysisResults
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Image
                    if let image = results.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(12)
                    }
                    
                    // Detailed metrics
                    VStack(spacing: 16) {
                        metricRow(title: "Uniformity Score", value: "\(Int(results.uniformityScore))%", color: results.uniformityColor)
                        metricRow(title: "Average Particle Size", value: results.averageSize, color: .blue)
                        metricRow(title: "Fines Percentage", value: "\(Int(results.finesPercentage))%", color: .orange)
                        metricRow(title: "Coarse Percentage", value: "\(Int(100 - results.finesPercentage - 60))%", color: .purple)
                    }
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.headline)
                        
                        Text("• Adjust grinder to reduce fines percentage")
                        Text("• Consider a burr grinder for better uniformity")
                        Text("• Current grind is suitable for pour-over methods")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Analysis Results")
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
    
    private func metricRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - App Entry Point (remove this section if using existing App file)
