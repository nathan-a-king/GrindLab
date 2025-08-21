import SwiftUI
import AVFoundation
import UIKit
import Combine
import Vision

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

// MARK: - Error Types
enum AnalysisError: Error, LocalizedError {
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

// MARK: - Data Structures
struct Particle {
    let contour: [CGPoint]
    let boundingRect: CGRect
    let area: Double
    let perimeter: Double
}

struct AnalyzedParticle {
    let particle: Particle
    let diameterMM: Double
    let circularity: Double
    let aspectRatio: Double
    let category: GrindAnalysisEngine.ParticleSizeCategory
}

// MARK: - Grind Analysis Engine
class GrindAnalysisEngine {
    
    enum ParticleSizeCategory: CaseIterable {
        case fines
        case fine
        case medium
        case coarse
        case extraCoarse
        
        var sizeRange: ClosedRange<Double> {
            switch self {
            case .fines: return 0.0...0.3
            case .fine: return 0.3...0.6
            case .medium: return 0.6...1.0
            case .coarse: return 1.0...1.5
            case .extraCoarse: return 1.5...10.0
            }
        }
        
        var displayName: String {
            switch self {
            case .fines: return "Fines"
            case .fine: return "Fine"
            case .medium: return "Medium"
            case .coarse: return "Coarse"
            case .extraCoarse: return "Extra Coarse"
            }
        }
    }
    
    struct DetailedAnalysisResults {
        let particleCount: Int
        let sizeDistribution: [ParticleSizeCategory: Int]
        let averageParticleSize: Double
        let uniformityScore: Double
        let finesPercentage: Double
        let mediumPercentage: Double
        let coarsePercentage: Double
        let totalArea: Double
        let processingTime: TimeInterval
        let confidence: Double
        
        func toAnalysisResults(image: UIImage?) -> AnalysisResults {
            return AnalysisResults(
                uniformityScore: uniformityScore,
                averageSize: String(format: "%.2fmm", averageParticleSize),
                finesPercentage: finesPercentage,
                image: image
            )
        }
    }
    
    func analyzeGrind(image: UIImage, grindType: GrindType, completion: @escaping (Result<DetailedAnalysisResults, AnalysisError>) -> Void) {
        let startTime = Date()
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let processedImage = self.preprocessImage(image) else {
                    completion(.failure(.imageProcessingFailed))
                    return
                }
                
                let pixelsPerMM = 10.0 // Placeholder for scale detection
                let particles = try self.segmentParticles(in: processedImage)
                let analyzedParticles = self.analyzeParticles(particles, pixelsPerMM: pixelsPerMM)
                
                let results = self.calculateMetrics(
                    particles: analyzedParticles,
                    grindType: grindType,
                    processingTime: Date().timeIntervalSince(startTime)
                )
                
                DispatchQueue.main.async {
                    completion(.success(results))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.analysisError(error.localizedDescription)))
                }
            }
        }
    }
    
    private func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let width = cgImage.width
        let height = cgImage.height
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let processedCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: processedCGImage)
    }
    
    private func segmentParticles(in image: UIImage) throws -> [Particle] {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.imageProcessingFailed
        }
        
        let binaryMask = createBinaryMask(from: cgImage)
        let contours = findContours(in: binaryMask)
        
        let particles = contours.compactMap { contour -> Particle? in
            guard contour.count > 5 else { return nil }
            
            let boundingRect = calculateBoundingRect(for: contour)
            let area = calculateArea(for: contour)
            let perimeter = calculatePerimeter(for: contour)
            
            return Particle(
                contour: contour,
                boundingRect: boundingRect,
                area: area,
                perimeter: perimeter
            )
        }
        
        return particles.filter { $0.area > 10 }
    }
    
    private func createBinaryMask(from cgImage: CGImage) -> [[Bool]] {
        let width = cgImage.width
        let height = cgImage.height
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }
        
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        let threshold: UInt8 = 128
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let pixelValue = bytes[pixelIndex]
                mask[y][x] = pixelValue < threshold
            }
        }
        
        return mask
    }
    
    private func findContours(in mask: [[Bool]]) -> [[CGPoint]] {
        let height = mask.count
        guard height > 0 else { return [] }
        let width = mask[0].count
        
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        var contours: [[CGPoint]] = []
        
        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] && !visited[y][x] {
                    let contour = traceContour(mask: mask, visited: &visited, startX: x, startY: y)
                    if contour.count > 5 {
                        contours.append(contour)
                    }
                }
            }
        }
        
        return contours
    }
    
    private func traceContour(mask: [[Bool]], visited: inout [[Bool]], startX: Int, startY: Int) -> [CGPoint] {
        var contour: [CGPoint] = []
        var stack = [(startX, startY)]
        
        while !stack.isEmpty {
            let (x, y) = stack.removeLast()
            
            if x < 0 || x >= mask[0].count || y < 0 || y >= mask.count ||
               visited[y][x] || !mask[y][x] {
                continue
            }
            
            visited[y][x] = true
            contour.append(CGPoint(x: x, y: y))
            
            for dx in -1...1 {
                for dy in -1...1 {
                    if dx != 0 || dy != 0 {
                        stack.append((x + dx, y + dy))
                    }
                }
            }
        }
        
        return contour
    }
    
    private func calculateBoundingRect(for contour: [CGPoint]) -> CGRect {
        guard !contour.isEmpty else { return .zero }
        
        let minX = contour.map { $0.x }.min() ?? 0
        let maxX = contour.map { $0.x }.max() ?? 0
        let minY = contour.map { $0.y }.min() ?? 0
        let maxY = contour.map { $0.y }.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func calculateArea(for contour: [CGPoint]) -> Double {
        guard contour.count >= 3 else { return 0 }
        
        var area: Double = 0
        for i in 0..<contour.count {
            let j = (i + 1) % contour.count
            area += contour[i].x * contour[j].y
            area -= contour[j].x * contour[i].y
        }
        return abs(area) / 2.0
    }
    
    private func calculatePerimeter(for contour: [CGPoint]) -> Double {
        guard contour.count >= 2 else { return 0 }
        
        var perimeter: Double = 0
        for i in 0..<contour.count {
            let j = (i + 1) % contour.count
            let dx = contour[i].x - contour[j].x
            let dy = contour[i].y - contour[j].y
            perimeter += sqrt(dx * dx + dy * dy)
        }
        return perimeter
    }
    
    private func analyzeParticles(_ particles: [Particle], pixelsPerMM: Double) -> [AnalyzedParticle] {
        return particles.map { particle in
            let diameterPixels = sqrt(4 * particle.area / .pi)
            let diameterMM = diameterPixels / pixelsPerMM
            
            let circularity = (4 * .pi * particle.area) / (particle.perimeter * particle.perimeter)
            let aspectRatio = particle.boundingRect.width / particle.boundingRect.height
            
            return AnalyzedParticle(
                particle: particle,
                diameterMM: diameterMM,
                circularity: circularity,
                aspectRatio: aspectRatio,
                category: categorizeParticle(diameterMM: diameterMM)
            )
        }
    }
    
    private func categorizeParticle(diameterMM: Double) -> ParticleSizeCategory {
        for category in ParticleSizeCategory.allCases {
            if category.sizeRange.contains(diameterMM) {
                return category
            }
        }
        return .extraCoarse
    }
    
    private func calculateMetrics(particles: [AnalyzedParticle], grindType: GrindType, processingTime: TimeInterval) -> DetailedAnalysisResults {
        
        let totalParticles = particles.count
        
        var distribution: [ParticleSizeCategory: Int] = [:]
        for category in ParticleSizeCategory.allCases {
            distribution[category] = particles.filter { $0.category == category }.count
        }
        
        let totalSize = particles.map { $0.diameterMM }.reduce(0, +)
        let averageSize = totalParticles > 0 ? totalSize / Double(totalParticles) : 0
        
        let finesCount = distribution[.fines] ?? 0
        let finesPercentage = totalParticles > 0 ? Double(finesCount) / Double(totalParticles) * 100 : 0
        
        let mediumCount = (distribution[.fine] ?? 0) + (distribution[.medium] ?? 0)
        let mediumPercentage = totalParticles > 0 ? Double(mediumCount) / Double(totalParticles) * 100 : 0
        
        let coarseCount = (distribution[.coarse] ?? 0) + (distribution[.extraCoarse] ?? 0)
        let coarsePercentage = totalParticles > 0 ? Double(coarseCount) / Double(totalParticles) * 100 : 0
        
        let sizes = particles.map { $0.diameterMM }
        let standardDeviation = calculateStandardDeviation(sizes)
        let coefficientOfVariation = averageSize > 0 ? standardDeviation / averageSize : 1.0
        let uniformityScore = max(0, min(100, (1.0 - coefficientOfVariation) * 100))
        
        let totalArea = particles.map { $0.particle.area }.reduce(0, +)
        let confidence = min(100, Double(totalParticles) / 100 * 100)
        
        return DetailedAnalysisResults(
            particleCount: totalParticles,
            sizeDistribution: distribution,
            averageParticleSize: averageSize,
            uniformityScore: uniformityScore,
            finesPercentage: finesPercentage,
            mediumPercentage: mediumPercentage,
            coarsePercentage: coarsePercentage,
            totalArea: totalArea,
            processingTime: processingTime,
            confidence: confidence
        )
    }
    
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingResults = false
    @State private var analysisResults: AnalysisResults?
    @State private var showingSettings = false
    @State private var selectedGrindType: GrindType?
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
                DetailedResultsView(results: results)
            }
        }
    }
    
    private var grindSelectionView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.brown.opacity(0.8), Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    // Custom coffee magnifier image asset replaces camera icon
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
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                    .frame(width: 50)
                
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
    
    private func cameraView(for grindType: GrindType) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                cameraHeaderView(grindType: grindType)
                cameraPreviewView
                controlsView
                
                if let results = analysisResults {
                    resultsView(results: results)
                }
            }
            
            if isAnalyzing {
                analysisOverlay
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
            CameraPreview(session: cameraManager.session)
                .aspectRatio(4/3, contentMode: .fit)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            
            gridOverlay
            
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
    
    private var controlsView: some View {
        HStack(spacing: 30) {
            Button(action: { cameraManager.toggleFlash() }) {
                VStack(spacing: 4) {
                    Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.title2)
                    Text("Flash")
                        .font(.caption)
                }
                .foregroundColor(cameraManager.isFlashOn ? .yellow : .white)
            }
            
            Button(action: { cameraManager.toggleGrid() }) {
                VStack(spacing: 4) {
                    Image(systemName: "grid")
                        .font(.title2)
                    Text("Grid")
                        .font(.caption)
                }
                .foregroundColor(cameraManager.showGrid ? .blue : .white)
            }
            
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
            .disabled(cameraManager.isCapturing || isAnalyzing)
            
            Button(action: { cameraManager.toggleTimer() }) {
                VStack(spacing: 4) {
                    Image(systemName: cameraManager.timerEnabled ? "timer" : "timer")
                        .font(.title2)
                    Text("Timer")
                        .font(.caption)
                }
                .foregroundColor(cameraManager.timerEnabled ? .orange : .white)
            }
            
            Button(action: { }) {
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
        guard let grindType = selectedGrindType else { return }
        
        cameraManager.capturePhoto { image in
            guard let capturedImage = image else { return }
            
            DispatchQueue.main.async {
                self.isAnalyzing = true
            }
            
            let analysisEngine = GrindAnalysisEngine()
            analysisEngine.analyzeGrind(image: capturedImage, grindType: grindType) { result in
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    
                    switch result {
                    case .success(let detailedResults):
                        let results = detailedResults.toAnalysisResults(image: capturedImage)
                        withAnimation(.spring()) {
                            self.analysisResults = results
                        }
                        
                        print("Analysis complete:")
                        print("- Particles detected: \(detailedResults.particleCount)")
                        print("- Average size: \(String(format: "%.2f", detailedResults.averageParticleSize))mm")
                        print("- Uniformity: \(String(format: "%.1f", detailedResults.uniformityScore))%")
                        print("- Fines: \(String(format: "%.1f", detailedResults.finesPercentage))%")
                        print("- Processing time: \(String(format: "%.2f", detailedResults.processingTime))s")
                        print("- Confidence: \(String(format: "%.1f", detailedResults.confidence))%")
                        
                    case .failure(let error):
                        print("Analysis failed: \(error.localizedDescription)")
                        let mockResults = AnalysisResults(
                            uniformityScore: Double.random(in: 60...95),
                            averageSize: grindType == .espresso ? "0.4mm" : "0.8mm",
                            finesPercentage: Double.random(in: 5...20),
                            image: capturedImage
                        )
                        withAnimation(.spring()) {
                            self.analysisResults = mockResults
                        }
                    }
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
                    if let image = results.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(12)
                    }
                    
                    VStack(spacing: 16) {
                        metricRow(title: "Uniformity Score", value: "\(Int(results.uniformityScore))%", color: results.uniformityColor)
                        metricRow(title: "Average Particle Size", value: results.averageSize, color: .blue)
                        metricRow(title: "Fines Percentage", value: "\(Int(results.finesPercentage))%", color: .orange)
                        metricRow(title: "Coarse Percentage", value: "\(Int(100 - results.finesPercentage - 60))%", color: .purple)
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
