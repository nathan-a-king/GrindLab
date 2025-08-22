//
//  ContentView.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI
import AVFoundation

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var camera = CoffeeCamera()
    @State private var analysisEngine = CoffeeAnalysisEngine()
    @State private var settings = AnalysisSettings()
    
    @State private var showingResults = false
    @State private var analysisResults: CoffeeAnalysisResults?
    @State private var showingSettings = false
    @State private var selectedGrindType: CoffeeGrindType?
    @State private var showingCamera = false
    @State private var isAnalyzing = false
    @State private var showingGallery = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            Group {
                if showingCamera, let grindType = selectedGrindType {
                    cameraView(for: grindType)
                } else {
                    grindSelectionView
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: $settings)
        }
        .sheet(isPresented: $showingResults) {
            if let results = analysisResults {
                ResultsView(results: results)
            }
        }
        .sheet(isPresented: $showingGallery) {
            PhotoPickerView { image in
                if let grindType = selectedGrindType {
                    analyzeImage(image, grindType: grindType)
                }
            }
        }
        .alert("Analysis Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            camera.checkPermissions()
            
            // Update analysis engine when settings change
            analysisEngine = CoffeeAnalysisEngine(settings: settings)
        }
        .onChange(of: settings) { _ in
            analysisEngine = CoffeeAnalysisEngine(settings: settings)
        }
        .onChange(of: showingCamera) { isShowing in
            if isShowing {
                // Give camera a moment to initialize when switching to camera view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !camera.isSessionRunning {
                        camera.startSession()
                    }
                }
            }
        }
    }
    
    // MARK: - Grind Selection View
    
    private var grindSelectionView: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 40) {
                headerSection
                grindTypeCards
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 30)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.brown.opacity(0.8),
                Color.black.opacity(0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 84))
                .foregroundColor(.white)
                .shadow(radius: 8)
            
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
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(CoffeeGrindType.allCases, id: \.self) { grindType in
                grindTypeCard(for: grindType)
            }
        }
    }
    
    private func grindTypeCard(for type: CoffeeGrindType) -> some View {
        let (icon, color) = iconAndColor(for: type)
        
        return Button(action: {
            selectedGrindType = type
            showingCamera = true
        }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                Text(type.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Target: \(type.targetSizeRange)")
                    .font(.caption)
                    .foregroundColor(color.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding(16)
            .background(cardBackgroundView)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconAndColor(for type: CoffeeGrindType) -> (String, Color) {
        switch type {
        case .filter:
            return ("drop.circle.fill", .blue)
        case .espresso:
            return ("cup.and.saucer.fill", .orange)
        case .frenchPress:
            return ("cylinder.fill", .green)
        case .coldBrew:
            return ("snowflake.circle.fill", .cyan)
        }
    }
    
    private var cardBackgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    private var bottomControls: some View {
        HStack {
            Button(action: { showingSettings = true }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .foregroundColor(.white.opacity(0.8))
                .font(.subheadline)
            }
            
            Spacer()
            
            if let results = analysisResults {
                Button(action: { showingResults = true }) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                        Text("Last Results")
                    }
                    .foregroundColor(.blue)
                    .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - Camera View
    
    private func cameraView(for grindType: CoffeeGrindType) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                cameraHeader(grindType: grindType)
                cameraPreviewSection
                
                CameraControls(
                    camera: camera,
                    onCapture: capturePhoto,
                    onGallery: { showingGallery = true }
                )
                
                if let results = analysisResults {
                    resultsPreview(results: results)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            if isAnalyzing {
                analysisOverlay
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            camera.startSession()
        }
        .onDisappear {
            camera.stopSession()
        }
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
            
            VStack(spacing: 2) {
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
            Group {
                if camera.authorizationStatus == .authorized {
                    CoffeeGrindCameraPreview(session: camera.session) { point in
                        // Handle tap to focus
                        camera.focusAt(point: point, in: UIView())
                    }
                } else {
                    CameraPermissionView {
                        camera.checkPermissions()
                    }
                }
            }
            .aspectRatio(4/3, contentMode: .fit)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            
            GridOverlay(isVisible: camera.showGrid)
            
            FocusIndicator(
                position: camera.focusPoint,
                isVisible: camera.showFocusIndicator
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
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
            
            HStack(spacing: 16) {
                resultCard(
                    title: "Uniformity",
                    value: "\(Int(results.uniformityScore))%",
                    color: results.uniformityColor
                )
                
                resultCard(
                    title: "Avg Size",
                    value: String(format: "%.1fμm", results.averageSize),
                    color: .blue
                )
                
                resultCard(
                    title: "Fines",
                    value: "\(Int(results.finesPercentage))%",
                    color: .orange
                )
                
                resultCard(
                    title: "Grade",
                    value: results.uniformityGrade,
                    color: results.uniformityColor
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
        .padding(.horizontal, 20)
    }
    
    private func resultCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
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
    
    // MARK: - Actions
    
    private func capturePhoto() {
        camera.capturePhoto { result in
            switch result {
            case .success(let image):
                if let grindType = selectedGrindType {
                    analyzeImage(image, grindType: grindType)
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func analyzeImage(_ image: UIImage, grindType: CoffeeGrindType) {
        isAnalyzing = true
        
        analysisEngine.analyzeGrind(image: image, grindType: grindType) { result in
            isAnalyzing = false
            
            switch result {
            case .success(let results):
                withAnimation(.spring()) {
                    self.analysisResults = results
                }
                
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Photo Picker

struct PhotoPickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
#endif
