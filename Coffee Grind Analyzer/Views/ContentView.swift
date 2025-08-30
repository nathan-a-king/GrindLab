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
    @StateObject private var historyManager = CoffeeAnalysisHistoryManager()
    @State private var analysisEngine = CoffeeAnalysisEngine()
    @State private var settings = AnalysisSettings.load()
    
    @State private var showingResults = false
    @State private var analysisResults: CoffeeAnalysisResults?
    @State private var detailResults: CoffeeAnalysisResults?
    @State private var showingSettings = false
    @State private var selectedGrindType: CoffeeGrindType?
    @State private var showingCamera = false
    @State private var isAnalyzing = false
    @State private var showingGallery = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var dragOffset: CGFloat = 0
    @State private var pressedCard: CoffeeGrindType? = nil
    
    var body: some View {
        TabView {
            // Main Analysis Tab
            NavigationView {
                Group {
                    if showingCamera, let grindType = selectedGrindType {
                        cameraView(for: grindType)
                    } else {
                        grindSelectionView
                    }
                }
            }
            .tabItem {
                Image(systemName: "camera.fill")
                Text("Analyze")
            }
            
            // History Tab
            HistoryView()
                .environmentObject(historyManager)
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: $settings)
        }
        .sheet(isPresented: $showingResults) {
            if let results = detailResults {
                ResultsView(results: results, isFromHistory: false)
                    .environmentObject(historyManager)
                    .onDisappear {
                        // Clear detail results when sheet is dismissed
                        detailResults = nil
                    }
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
            
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                        .padding(.top, 20) // Add some top padding
                    
                    grindTypeCards
                    
                    // Settings button at bottom
                    // Settings button removed - now in toolbar
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
    }
    
    private var backgroundGradient: some View {
        Color.brown.opacity(0.7)
            .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("app-icon-display")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Text("GrindLab")
                .font(.system(size: 42, weight: .thin, design: .default))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .tracking(-1)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            Text("Select your grind type to begin analysis")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
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
        let (icon, _) = iconAndColor(for: type)
        let isPressed = pressedCard == type

        return ZStack {
            // Shadow layer (separate from the button)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.clear)
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                .allowsHitTesting(false)            // so it doesn't steal taps

            // Card content (no Button, just the visual)
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)

                Text(type.displayName)
                    .font(.headline).fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Target: \(type.targetSizeRange)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
            .background(cardBackgroundView)
            // Keep the visual rounded shape consistent for hit-testing/rasterization:
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Quick bounce animation
            withAnimation(.easeInOut(duration: 0.1)) {
                pressedCard = type
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.15)) {
                    pressedCard = nil
                }
            }
            
            // Navigate after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                selectedGrindType = type
                showingCamera = true
            }
        }
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
            .fill(Color.brown.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
            )
    }
    
    private var recentResultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Analyses")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(historyManager.totalAnalyses) saved")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(historyManager.recentAnalyses(limit: 5)) { analysis in
                        recentResultCard(analysis)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.12))
        .cornerRadius(16)
    }
    
    private func recentResultCard(_ analysis: SavedCoffeeAnalysis) -> some View {
        Button(action: {
            analysisResults = analysis.results
            showingResults = true
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(analysis.results.grindType.displayName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    let isInRange = analysis.results.grindType.targetSizeMicrons.contains(analysis.results.averageSize)
                    Text(isInRange ? "In Range" : "Out of Range")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isInRange ? .green : .red)
                }
                
                Text(analysis.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(analysis.savedDate, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 160, alignment: .leading)
            .padding(16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var settingsButton: some View {
        EmptyView() // Removed - now using toolbar button
    }
    
    // MARK: - Camera View
    
    private func cameraView(for grindType: CoffeeGrindType) -> some View {
        ZStack {
            // Modern gradient background instead of black
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.15, green: 0.12, blue: 0.10), // Dark coffee brown
                    Color(red: 0.08, green: 0.06, blue: 0.05)  // Almost black brown
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                cameraHeader(grindType: grindType)
                cameraPreviewSection
                
                CameraControls(
                    camera: camera,
                    onCapture: capturePhoto,
                    onGallery: { showingGallery = true }
                )
                
                // Add spacer to prevent results from affecting layout
                Spacer(minLength: 0)
            }
            
            // Results preview as overlay
            if let results = analysisResults {
                VStack {
                    Spacer()
                    resultsPreview(results: results)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50) // Position midway between camera preview and controls
                        .offset(y: dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    // Only allow downward dragging
                                    if gesture.translation.height > 0 {
                                        dragOffset = gesture.translation.height
                                    }
                                }
                                .onEnded { gesture in
                                    // Swipe down to dismiss (threshold: 50 points downward)
                                    if gesture.translation.height > 50 {
                                        // Animate card sliding down before dismissing
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            dragOffset = 300 // Slide off screen
                                        }
                                        // Then dismiss after animation
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            analysisResults = nil
                                            dragOffset = 0
                                        }
                                    } else {
                                        // Snap back if not swiped far enough
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                        )
                }
                .allowsHitTesting(true)
            }
            
            if isAnalyzing {
                analysisOverlay
            }
        }
        .navigationTitle(grindType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    showingCamera = false
                    selectedGrindType = nil
                    analysisResults = nil
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .onAppear {
            camera.startSession()
        }
        .onDisappear {
            camera.stopSession()
        }
    }
    
    private func cameraHeader(grindType: CoffeeGrindType) -> some View {
        VStack(spacing: 4) {
            Text("Position coffee grounds in view")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var cameraPreviewSection: some View {
        ZStack {
            Group {
                if camera.authorizationStatus == .authorized {
                    CoffeeGrindCameraPreview(session: camera.session) { devicePoint in
                        guard camera.isSessionRunning else { return }
                        // Don't pass UIView(), handle the conversion differently
                        camera.focusAt(point: devicePoint)
                    }
                    .aspectRatio(3/4, contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                } else {
                    CameraPermissionView {
                        camera.checkPermissions()
                    }
                    .aspectRatio(3/4, contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .onTapGesture {
                        // Prevent any unintended tap handling
                    }
                }
            }
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 5)
            .overlay(
                GridOverlay(isVisible: camera.showGrid)
                    .aspectRatio(3/4, contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .cornerRadius(20)
                    .allowsHitTesting(false)
            )
        }
        .padding(.horizontal, 16)
    }
    
    private func resultsPreview(results: CoffeeAnalysisResults) -> some View {
        VStack(spacing: 16) {
            // Drag handle and header
            VStack(spacing: 12) {
                // Visual drag handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 4)
                
                HStack {
                    Button("Dismiss") {
                        withAnimation(.easeOut(duration: 0.2)) {
                            analysisResults = nil
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("Analysis Results")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("View Details") {
                        // Store results for detail view before clearing card
                        detailResults = results
                        showingResults = true
                        // Clear results so card doesn't appear when user returns
                        analysisResults = nil
                    }
                    .foregroundColor(.blue)
                    .font(.caption)
                }
            }
            
            HStack(spacing: 16) {
                let isInRange = results.grindType.targetSizeMicrons.contains(results.averageSize)
                resultCard(
                    title: "Size Match",
                    value: isInRange ? "In Range" : "Out of Range",
                    color: isInRange ? .green : .red
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
                    title: "Particles",
                    value: "\(results.particleCount)",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var analysisOverlay: some View {
        ZStack {
            // Blur the camera preview instead of covering with solid color
            Color.clear
                .background(.ultraThinMaterial)
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
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.brown.opacity(0.5))
                    .shadow(color: .black.opacity(0.4), radius: 15)
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

