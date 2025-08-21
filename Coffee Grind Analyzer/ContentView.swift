import SwiftUI
import AVFoundation
import UIKit
import Combine
import Vision
import Accelerate

// MARK: - Core Data Structures

enum CoffeeGrindType: CaseIterable {
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
    
    var targetSizeRange: String {
        switch self {
        case .filter:
            return "0.7-1.2mm"
        case .espresso:
            return "0.2-0.5mm"
        }
    }
}

struct CoffeeAnalysisResults {
    let uniformityScore: Double
    let averageSize: String
    let finesPercentage: Double
    let image: UIImage?
    let particleCount: Int
    let confidence: Double
    
    var uniformityColor: Color {
        switch uniformityScore {
        case 80...: return .green
        case 60..<80: return .yellow
        default: return .red
        }
    }
}

enum CoffeeAnalysisError: Error, LocalizedError {
    case imageProcessingFailed
    case noParticlesDetected
    case analysisError(String)
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the image"
        case .noParticlesDetected:
            return "No coffee particles detected in the image"
        case .analysisError(let message):
            return "Analysis error: \(message)"
        }
    }
}

// MARK: - Analysis Engine

class CoffeeAnalysisEngine {
    
    func analyzeGrind(
        image: UIImage,
        grindType: CoffeeGrindType,
        completion: @escaping (Result<CoffeeAnalysisResults, CoffeeAnalysisError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Simulate analysis processing
            Thread.sleep(forTimeInterval: 2.0)
            
            let mockResults = CoffeeAnalysisResults(
                uniformityScore: Double.random(in: 60...95),
                averageSize: grindType == .espresso ? "0.4mm" : "0.8mm",
                finesPercentage: Double.random(in: 5...20),
                image: image,
                particleCount: Int.random(in: 150...500),
                confidence: Double.random(in: 75...95)
            )
            
            DispatchQueue.main.async {
                completion(.success(mockResults))
            }
        }
    }
}

// MARK: - Camera Manager

class CoffeeCamera: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isFlashOn = false
    @Published var showGrid = false
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
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        captureCompletion = completion
        isCapturing = true
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isCapturing = false
        }
    }
}

extension CoffeeCamera: AVCapturePhotoCaptureDelegate {
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

struct CoffeeGrindCameraPreview: UIViewRepresentable {
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

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var camera = CoffeeCamera()
    @State private var analysisEngine = CoffeeAnalysisEngine()
    @State private var showingResults = false
    @State private var analysisResults: CoffeeAnalysisResults?
    @State private var showingSettings = false
    @State private var selectedGrindType: CoffeeGrindType?
    @State private var showingCamera = false
    @State private var isAnalyzing = false
    
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
                ResultsView(results: results)
            }
        }
    }
    
    private var grindSelectionView: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 40) {
                headerSection
                grindTypeCards
                Spacer()
                settingsButton
            }
            .padding(.horizontal, 30)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.brown.opacity(0.8), Color.black]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Custom coffee magnifier image asset replaces system icon
            Image("coffee_magnifier")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 84, height: 84)
                .shadow(radius: 6)
                .padding(.bottom, 6)
            
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
    }
    
    private var grindTypeCards: some View {
        VStack(spacing: 20) {
            grindTypeCard(
                type: .filter,
                title: "Filter/Pour-Over",
                description: "Medium to coarse grind for drip coffee",
                icon: "drop.circle.fill",
                color: .blue
            )
            
            grindTypeCard(
                type: .espresso,
                title: "Espresso",
                description: "Fine grind for espresso machines",
                icon: "cup.and.saucer.fill",
                color: .orange
            )
        }
    }
    
    private func grindTypeCard(
        type: CoffeeGrindType,
        title: String,
        description: String,
        icon: String,
        color: Color
    ) -> some View {
        Button(action: {
            selectedGrindType = type
            showingCamera = true
            camera.checkPermissions()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                    .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    
                    Text("Target: \(type.targetSizeRange)")
                        .font(.caption)
                        .foregroundColor(color.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 8)
                
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)
            .background(cardBackgroundView)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var cardBackgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            HStack {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
            .foregroundColor(.white.opacity(0.8))
            .font(.subheadline)
        }
    }
    
    private func cameraView(for grindType: CoffeeGrindType) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                cameraHeader(grindType: grindType)
                cameraPreviewSection
                cameraControls
                
                if let results = analysisResults {
                    resultsPreview(results: results)
                }
            }
            
            if isAnalyzing {
                analysisOverlay
            }
        }
        .navigationBarHidden(true)
    }
    
    private func cameraHeader(grindType: CoffeeGrindType) -> some View {
        HStack {
            Button(action: {
                showingCamera = false
                selectedGrindType = nil
                analysisResults = nil
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                    Text("Back")
                        .font(.headline)
                }
                .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 2) {
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
    
    private var cameraPreviewSection: some View {
        ZStack {
            CoffeeGrindCameraPreview(session: camera.session)
                .aspectRatio(4/3, contentMode: .fit)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            
            if camera.showGrid {
                gridOverlay
            }
            
            if camera.showFocusIndicator {
                focusIndicator
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    private var gridOverlay: some View {
        VStack {
            Spacer()
            Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.3))
            Spacer()
            Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.3))
            Spacer()
        }
        .overlay(
            HStack {
                Spacer()
                Rectangle().frame(width: 1).foregroundColor(.white.opacity(0.3))
                Spacer()
                Rectangle().frame(width: 1).foregroundColor(.white.opacity(0.3))
                Spacer()
            }
        )
    }
    
    private var focusIndicator: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .position(camera.focusPoint)
            .opacity(camera.showFocusIndicator ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: camera.showFocusIndicator)
    }
    
    private var cameraControls: some View {
        HStack(spacing: 30) {
            controlButton(
                icon: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                label: "Flash",
                isActive: camera.isFlashOn,
                action: { camera.toggleFlash() }
            )
            
            controlButton(
                icon: "grid",
                label: "Grid",
                isActive: camera.showGrid,
                action: { camera.toggleGrid() }
            )
            
            captureButton
            
            Button(action: {}) {
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
    
    private func controlButton(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isActive ? .yellow : .white)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(isActive ? .yellow : .white)
            }
        }
    }
    
    private var captureButton: some View {
        Button(action: capturePhoto) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .scaleEffect(camera.isCapturing ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: camera.isCapturing)
            }
        }
        .disabled(camera.isCapturing || isAnalyzing)
    }
    
    private func resultsPreview(results: CoffeeAnalysisResults) -> some View {
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
                resultCard(
                    title: "Uniformity",
                    value: "\(Int(results.uniformityScore))%",
                    color: results.uniformityColor
                )
                
                resultCard(
                    title: "Avg Size",
                    value: results.averageSize,
                    color: .blue
                )
                
                resultCard(
                    title: "Fines",
                    value: "\(Int(results.finesPercentage))%",
                    color: .orange
                )
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
    
    private var analysisOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Analyzing coffee grind...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("This may take a few seconds")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
    
    private func capturePhoto() {
        guard let grindType = selectedGrindType else { return }
        
        camera.capturePhoto { image in
            guard let capturedImage = image else { return }
            
            DispatchQueue.main.async {
                self.isAnalyzing = true
            }
            
            analysisEngine.analyzeGrind(image: capturedImage, grindType: grindType) { result in
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    
                    switch result {
                    case .success(let results):
                        withAnimation(.spring()) {
                            self.analysisResults = results
                        }
                        
                    case .failure(let error):
                        print("Analysis failed: \(error.localizedDescription)")
                    }
                }
            }
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

// MARK: - Results View

struct ResultsView: View {
    let results: CoffeeAnalysisResults
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = results.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(12)
                    }
                    
                    VStack(spacing: 16) {
                        metricRow(
                            title: "Uniformity Score",
                            value: "\(Int(results.uniformityScore))%",
                            color: results.uniformityColor
                        )
                        
                        metricRow(
                            title: "Average Particle Size",
                            value: results.averageSize,
                            color: .blue
                        )
                        
                        metricRow(
                            title: "Fines Percentage",
                            value: "\(Int(results.finesPercentage))%",
                            color: .orange
                        )
                        
                        metricRow(
                            title: "Particle Count",
                            value: "\(results.particleCount)",
                            color: .green
                        )
                        
                        metricRow(
                            title: "Confidence",
                            value: "\(Int(results.confidence))%",
                            color: .purple
                        )
                    }
                    
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

// MARK: - Preview Providers

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
#endif
