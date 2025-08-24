//
//  CoffeeAnalysisEngine.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import UIKit
import Vision
import Accelerate
import CoreImage

class CoffeeAnalysisEngine {
    private let settings: AnalysisSettings
    
    init(settings: AnalysisSettings = AnalysisSettings()) {
        self.settings = settings
    }
    
    // MARK: - Validation Testing
    
    func runValidationTest() {
        print("\n🧪 RUNNING ANALYSIS ENGINE VALIDATION TEST")
        print(String(repeating: "=", count: 60))
        
        // Test 1: Grid pattern with known particles
        print("\n📋 Test 1: Grid Pattern (5x5, 30px radius)")
        let (gridImage, expectedGrid) = AnalysisValidation.createGridTestImage(
            width: 1000,
            height: 1000,
            rows: 5,
            cols: 5,
            particleRadius: 30
        )
        
        do {
            let results = try AnalysisValidation.runTestAnalysis(
                image: gridImage,
                grindType: .filter,
                calibrationFactor: 5.0
            )
            let report = AnalysisValidation.validateResults(
                detected: results.particles,
                expected: expectedGrid,
                tolerance: 10.0
            )
            report.printReport()
        } catch {
            print("❌ Grid analysis failed: \(error)")
        }
        
        // Test 2: Random particles
        print("\n📋 Test 2: Random Particles (20 particles, 20-100px)")
        let (randomImage, expectedRandom) = AnalysisValidation.createTestImage(
            width: 1000,
            height: 1000,
            particleCount: 20,
            particleSizeRange: 20...100
        )
        
        do {
            let results = try AnalysisValidation.runTestAnalysis(
                image: randomImage,
                grindType: .filter,
                calibrationFactor: 5.0
            )
            let report = AnalysisValidation.validateResults(
                detected: results.particles,
                expected: expectedRandom,
                tolerance: 10.0
            )
            report.printReport()
        } catch {
            print("❌ Random analysis failed: \(error)")
        }
    }
    
    func analyzeGrind(
        image: UIImage,
        grindType: CoffeeGrindType,
        completion: @escaping (Result<CoffeeAnalysisResults, CoffeeAnalysisError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = try self.performAnalysis(image: image, grindType: grindType)
                DispatchQueue.main.async {
                    completion(.success(results))
                }
            } catch let error as CoffeeAnalysisError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.analysisError(error.localizedDescription)))
                }
            }
        }
    }
    
    private func performAnalysis(image: UIImage, grindType: CoffeeGrindType) throws -> CoffeeAnalysisResults {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔬 Starting simplified coffee analysis for \(grindType.displayName)...")
        print("📐 Image size: \(Int(image.size.width))x\(Int(image.size.height))")
        
        // Get CGImage for consistent coordinate system
        guard let originalCGImage = image.cgImage else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        
        // Step 1: Convert to grayscale
        let step1Start = CFAbsoluteTimeGetCurrent()
        print("⚫ Step 1: Converting to grayscale...")
        guard let grayImage = convertToGrayscale(image) else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        print("✅ Step 1 complete in \(String(format: "%.2f", CFAbsoluteTimeGetCurrent() - step1Start))s")
        
        // Step 2: Apply simple Otsu thresholding
        let step2Start = CFAbsoluteTimeGetCurrent()
        print("🎭 Step 2: Applying Otsu thresholding...")
        guard let binaryImage = applySimpleThresholding(grayImage) else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        print("✅ Step 2 complete in \(String(format: "%.2f", CFAbsoluteTimeGetCurrent() - step2Start))s")
        
        // Step 3: Detect and analyze particles
        let step3Start = CFAbsoluteTimeGetCurrent()
        print("🔍 Step 3: Detecting particles...")
        let particles = try detectParticles(in: binaryImage, originalImage: grayImage)
        print("✅ Step 3 complete in \(String(format: "%.2f", CFAbsoluteTimeGetCurrent() - step3Start))s")
        print("📊 Found \(particles.count) particles")
        
        if particles.isEmpty {
            throw CoffeeAnalysisError.noParticlesDetected
        }
        
        // Step 4: Calculate statistics
        let step4Start = CFAbsoluteTimeGetCurrent()
        print("📈 Step 4: Calculating statistics...")
        let statistics = calculateStatistics(particles: particles, grindType: grindType)
        print("✅ Step 4 complete in \(String(format: "%.2f", CFAbsoluteTimeGetCurrent() - step4Start))s")
        
        // Step 5: Create processed image for visualization
        let step5Start = CFAbsoluteTimeGetCurrent()
        print("🎨 Step 5: Creating processed image...")
        let processedImage = createProcessedImage(originalImage: image, cgImage: originalCGImage, particles: particles)
        print("✅ Step 5 complete in \(String(format: "%.2f", CFAbsoluteTimeGetCurrent() - step5Start))s")
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("🎯 Analysis complete in \(String(format: "%.2f", totalTime))s total")
        print("📋 Results: \(particles.count) particles, \(String(format: "%.1f", statistics.uniformityScore))% uniformity")
        
        return CoffeeAnalysisResults(
            uniformityScore: statistics.uniformityScore,
            averageSize: statistics.averageSize,
            medianSize: statistics.medianSize,
            standardDeviation: statistics.standardDeviation,
            finesPercentage: statistics.finesPercentage,
            bouldersPercentage: statistics.bouldersPercentage,
            particleCount: particles.count,
            particles: particles,
            confidence: statistics.confidence,
            image: image,
            processedImage: processedImage,
            grindType: grindType,
            timestamp: Date()
        )
    }
    
    // MARK: - Image Processing
    
    private func convertToGrayscale(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        let grayscaleFilter = CIFilter(name: "CIColorMonochrome")!
        grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(CIColor.white, forKey: kCIInputColorKey)
        grayscaleFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        
        guard let output = grayscaleFilter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func applySimpleThresholding(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        
        var pixelData = [UInt8](repeating: 0, count: width * height)
        
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Calculate Otsu threshold
        let threshold = calculateOtsuThreshold(pixelData)
        print("🌡️ Otsu threshold calculated: \(threshold)")
        
        // Count pixels before thresholding for debugging
        let darkPixelsBefore = pixelData.filter { $0 < threshold }.count
        let lightPixelsBefore = pixelData.filter { $0 >= threshold }.count
        print("📊 Before threshold: \(darkPixelsBefore) dark pixels (\(String(format: "%.1f%%", Double(darkPixelsBefore)/Double(width*height)*100))), \(lightPixelsBefore) light pixels (\(String(format: "%.1f%%", Double(lightPixelsBefore)/Double(width*height)*100)))")
        
        // Apply threshold - pixels darker than threshold become black (0), lighter become white (255)
        // This ensures dark coffee particles remain dark for detection
        for i in 0..<pixelData.count {
            pixelData[i] = pixelData[i] <= threshold ? 0 : 255
        }
        
        // Count pixels after thresholding
        let blackPixelsAfter = pixelData.filter { $0 == 0 }.count
        let whitePixelsAfter = pixelData.filter { $0 == 255 }.count
        print("📊 After threshold: \(blackPixelsAfter) black pixels (particles), \(whitePixelsAfter) white pixels (background)")
        
        #if DEBUG
        // Save debug image of thresholding result
        saveDebugImage(pixelData, width: width, height: height, filename: "debug_binary_threshold.png")
        #endif
        
        // Create binary image
        guard let binaryContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ),
        let binaryCGImage = binaryContext.makeImage() else { return nil }
        
        return UIImage(cgImage: binaryCGImage)
    }
    
    private func calculateOtsuThreshold(_ pixelData: [UInt8]) -> UInt8 {
        var histogram = [Int](repeating: 0, count: 256)
        
        // Build histogram
        for pixel in pixelData {
            histogram[Int(pixel)] += 1
        }
        
        let total = pixelData.count
        var sum = 0.0
        for i in 0..<256 {
            sum += Double(i * histogram[i])
        }
        
        var sumB = 0.0
        var wB = 0
        var wF = 0
        var varMax = 0.0
        var threshold = 0
        
        for t in 0..<256 {
            wB += histogram[t]
            if wB == 0 { continue }
            
            wF = total - wB
            if wF == 0 { break }
            
            sumB += Double(t * histogram[t])
            
            let mB = sumB / Double(wB)
            let mF = (sum - sumB) / Double(wF)
            
            let varBetween = Double(wB) * Double(wF) * (mB - mF) * (mB - mF)
            
            if varBetween > varMax {
                varMax = varBetween
                threshold = t
            }
        }
        
        return UInt8(threshold)
    }
    
    // Removed morphological operations - they were causing more issues than solving
    
    // MARK: - Particle Detection
    
    private func detectParticles(in binaryImage: UIImage, originalImage: UIImage) throws -> [CoffeeParticle] {
        guard let cgImage = binaryImage.cgImage,
              let originalCGImage = originalImage.cgImage else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Verify coordinate spaces match
        assert(width == originalCGImage.width, "Binary and original image widths must match")
        assert(height == originalCGImage.height, "Binary and original image heights must match")
        
        print("🔍 Starting particle detection on \(width)x\(height) binary image...")
        print("📍 Detection coordinates: Using CGImage dimensions \(width)x\(height) (\(width > height ? "landscape" : "portrait"))")
        print("📍 Display coordinates: UIImage size \(Int(originalImage.size.width))x\(Int(originalImage.size.height)) (\(originalImage.size.width > originalImage.size.height ? "landscape" : "portrait"))")
        print("📍 Image orientation: \(originalImage.imageOrientation.rawValue)")
        let detectionStart = CFAbsoluteTimeGetCurrent()
        
        // Extract binary pixel data
        var binaryData = [UInt8](repeating: 0, count: width * height)
        let binaryContext = CGContext(
            data: &binaryData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        binaryContext?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Extract original grayscale data for brightness analysis
        var grayData = [UInt8](repeating: 0, count: width * height)
        let grayContext = CGContext(
            data: &grayData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        grayContext?.draw(originalCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Find connected components (particles)
        var visited = [Bool](repeating: false, count: width * height)
        var particles: [CoffeeParticle] = []
        var componentsFound = 0
        var componentsAccepted = 0
        let totalPixels = width * height
        var pixelsProcessed = 0
        
        for y in 0..<height {
            // Progress logging every 5% of rows for particle detection
            if y % (height / 20) == 0 && y > 0 {
                let progress = (y * 100) / height
                print("🔍 Particle detection progress: \(progress)% (found \(componentsFound) components, accepted \(componentsAccepted))")
            }
            
            for x in 0..<width {
                let index = y * width + x
                pixelsProcessed += 1
                
                if !visited[index] && binaryData[index] == 0 { // Dark pixels (coffee particles)
                    componentsFound += 1
                    let component = floodFill(
                        x: x, y: y,
                        width: width, height: height,
                        binaryData: binaryData,
                        grayData: grayData,
                        visited: &visited
                    )
                    
                    // Debug: log component size before creating particle
                    if componentsFound <= 5 || componentsFound % 10 == 0 {
                        print("🔍 Component #\(componentsFound): \(component.count) pixels at (\(x), \(y))")
                    }
                    
                    if let particle = createParticle(from: component, cgImage: cgImage, originalImage: originalImage) {
                        // Enhanced filtering with shape and size quality checks
                        let minDiameter = Double(settings.minParticleSize) // Now using diameter instead of area
                        let maxDiameter = Double(settings.maxParticleSize) // Now using diameter instead of area
                        
                        // Calculate equivalent diameter for comparison
                        let equivalentDiameter = 2 * sqrt(particle.area / .pi)
                        
                        // Size filtering using diameter instead of area
                        if equivalentDiameter >= minDiameter && equivalentDiameter <= maxDiameter {
                            // Additional quality checks
                            let aspectRatio = calculateAspectRatio(component: component)
                            let solidity = calculateSolidity(component: component)
                            
                            // Accept particles that look reasonably coffee-like using settings
                            if aspectRatio <= settings.maxAspectRatio && // Not too elongated
                               solidity >= settings.minSolidity && // Reasonably filled shape
                               particle.circularity >= settings.minCircularity { // Some minimum roundness
                                particles.append(particle)
                                componentsAccepted += 1
                            }
                        }
                    }
                }
            }
        }
        
        let detectionTime = CFAbsoluteTimeGetCurrent() - detectionStart
        print("✅ Particle detection complete in \(String(format: "%.2f", detectionTime))s")
        print("📊 Processed \(pixelsProcessed) pixels, found \(componentsFound) components, accepted \(componentsAccepted) particles")
        print("🎯 Final particle count: \(particles.count)")
        
        // Log coordinate bounds for validation
        if !particles.isEmpty {
            let xPositions = particles.map { $0.position.x }
            let yPositions = particles.map { $0.position.y }
            print("📍 Particle position ranges:")
            print("   X: \(Int(xPositions.min() ?? 0)) to \(Int(xPositions.max() ?? 0)) (image width: \(width))")
            print("   Y: \(Int(yPositions.min() ?? 0)) to \(Int(yPositions.max() ?? 0)) (image height: \(height))")
        }
        
        return particles
    }
    
    private func floodFill(
        x: Int, y: Int,
        width: Int, height: Int,
        binaryData: [UInt8],
        grayData: [UInt8],
        visited: inout [Bool]
    ) -> [(x: Int, y: Int, brightness: UInt8)] {
        var stack = [(x, y)]
        var component: [(x: Int, y: Int, brightness: UInt8)] = []
        
        while !stack.isEmpty {
            let (cx, cy) = stack.removeLast()
            let index = cy * width + cx
            
            if cx < 0 || cx >= width || cy < 0 || cy >= height || visited[index] || binaryData[index] != 0 {
                continue
            }
            
            visited[index] = true
            component.append((cx, cy, grayData[index]))
            
            // Add 8-connected neighbors
            stack.append(contentsOf: [
                (cx-1, cy-1), (cx, cy-1), (cx+1, cy-1),
                (cx-1, cy), (cx+1, cy),
                (cx-1, cy+1), (cx, cy+1), (cx+1, cy+1)
            ])
        }
        
        return component
    }
    
    private func createParticle(from component: [(x: Int, y: Int, brightness: UInt8)], cgImage: CGImage, originalImage: UIImage) -> CoffeeParticle? {
        guard !component.isEmpty else { return nil }
        
        let area = Double(component.count)
        
        // Calculate centroid in image pixel coordinates
        let centroidX = Double(component.map { $0.x }.reduce(0, +)) / Double(component.count)
        let centroidY = Double(component.map { $0.y }.reduce(0, +)) / Double(component.count)
        
        // Calculate equivalent diameter using more accurate method
        let radius = sqrt(area / .pi)
        let equivalentDiameter = radius * 2
        
        // Micron conversion with calibration factor
        let pixelsToMicrons: Double
        if settings.calibrationFactor > 0.1 { // If we have ruler calibration
            pixelsToMicrons = settings.calibrationFactor
        } else {
            // Default based on typical smartphone macro photos
            // Approximately 100-150 microns per pixel for close-up coffee photos
            pixelsToMicrons = 100.0
        }
        let sizeMicrons = equivalentDiameter * pixelsToMicrons
        
        // Calculate circularity (4π×area/perimeter²) - corrected formula
        let perimeter = calculatePerimeter(component: component)
        let circularity = perimeter > 0 ? (4 * .pi * area) / (perimeter * perimeter) : 0
        
        // Calculate average brightness
        let avgBrightness = Double(component.map { Double($0.brightness) }.reduce(0, +)) / Double(component.count) / 255.0
        
        // Quality check - reject obviously bad particles
        // Adapt size limits based on calibration factor to handle different image scales
        let minSizeMicrons: Double
        let maxSizeMicrons: Double
        
        if settings.calibrationFactor > 100 { // High calibration factor (real photos)
            minSizeMicrons = 50.0   // 50 microns minimum 
            maxSizeMicrons = 20000.0 // 20mm maximum (very coarse)
        } else { // Low calibration factor (close-up or synthetic images)
            minSizeMicrons = 20.0   // 20 microns minimum
            maxSizeMicrons = 5000.0 // 5mm maximum
        }
        
        // Debug logging for all particles (accepted and rejected)
        let diameter = sqrt(area / .pi) * 2
        print("🔍 Component at (\(Int(centroidX)), \(Int(centroidY))): \(component.count) pixels, diameter: \(String(format: "%.1f", diameter))px, size: \(String(format: "%.0f", sizeMicrons))μm")
        print("   📊 Circularity: \(String(format: "%.2f", circularity)), Brightness: \(String(format: "%.2f", avgBrightness))")
        
        // Debug logging for rejected particles
        var rejectionReasons: [String] = []
        if !(circularity >= settings.minCircularity && circularity <= 1.0) {
            rejectionReasons.append("circularity \(String(format: "%.2f", circularity)) outside [\(settings.minCircularity), 1.0]")
        }
        if !(sizeMicrons >= minSizeMicrons && sizeMicrons <= maxSizeMicrons) {
            rejectionReasons.append("size \(String(format: "%.0f", sizeMicrons))μm outside [\(minSizeMicrons), \(maxSizeMicrons)]")
        }
        if !(avgBrightness < 0.8) {
            rejectionReasons.append("brightness \(String(format: "%.2f", avgBrightness)) too bright (> 0.8)")
        }
        
        // Calculate edge distance for filtering and logging
        let imageWidth = Double(cgImage.width)
        let imageHeight = Double(cgImage.height)
        let edgeBuffer = 20.0 // pixels from edge
        let tooCloseToEdge = centroidX < edgeBuffer || centroidX > (imageWidth - edgeBuffer) ||
                            centroidY < edgeBuffer || centroidY > (imageHeight - edgeBuffer)
        if tooCloseToEdge {
            rejectionReasons.append("too close to edge (\(Int(centroidX)), \(Int(centroidY))) within \(edgeBuffer)px border")
        }
        
        if !rejectionReasons.isEmpty {
            print("   ❌ REJECTED: \(rejectionReasons.joined(separator: ", "))")
        } else {
            print("   ✅ ACCEPTED")
        }
        
        // Apply all filters using pre-calculated values
        guard circularity >= settings.minCircularity && circularity <= 1.0,
              sizeMicrons >= minSizeMicrons && sizeMicrons <= maxSizeMicrons,
              avgBrightness < 0.8, // Coffee should be relatively dark
              !tooCloseToEdge else { // Not too close to image edges
            return nil
        }
        
        // Keep particle position in original CGImage coordinates for now
        // We'll transform during overlay rendering to ensure proper alignment
        let particle = CoffeeParticle(
            size: sizeMicrons,
            area: area,
            circularity: min(circularity, 1.0),
            position: CGPoint(x: centroidX, y: centroidY),
            brightness: avgBrightness
        )
        
        return particle
    }
    
    private func transformCGImageToUIImageCoordinates(cgPoint: CGPoint, cgImageSize: CGSize, uiImage: UIImage) -> CGPoint {
        let cgWidth = cgImageSize.width
        let cgHeight = cgImageSize.height
        let uiWidth = uiImage.size.width  
        let uiHeight = uiImage.size.height
        
        print("🔄 Transforming point (\(Int(cgPoint.x)), \(Int(cgPoint.y))) from CGImage \(Int(cgWidth))x\(Int(cgHeight)) to UIImage \(Int(uiWidth))x\(Int(uiHeight)), orientation: \(uiImage.imageOrientation.rawValue)")
        
        // Handle different orientations properly
        let transformedPoint: CGPoint
        switch uiImage.imageOrientation {
        case .up:
            // No rotation needed
            transformedPoint = cgPoint
        case .down:
            // 180° rotation
            transformedPoint = CGPoint(x: cgWidth - cgPoint.x, y: cgHeight - cgPoint.y)
        case .left:
            // 90° counterclockwise rotation: (x,y) -> (y, width-x)
            transformedPoint = CGPoint(x: cgPoint.y, y: cgWidth - cgPoint.x)
        case .right:
            // 90° clockwise rotation: (x,y) -> (height-y, x) 
            transformedPoint = CGPoint(x: cgHeight - cgPoint.y, y: cgPoint.x)
        case .upMirrored:
            // Horizontal flip
            transformedPoint = CGPoint(x: cgWidth - cgPoint.x, y: cgPoint.y)
        case .downMirrored:
            // Horizontal flip + 180° rotation
            transformedPoint = CGPoint(x: cgPoint.x, y: cgHeight - cgPoint.y)
        case .leftMirrored:
            // Horizontal flip + 90° counterclockwise rotation
            transformedPoint = CGPoint(x: cgPoint.y, y: cgPoint.x)
        case .rightMirrored:
            // Horizontal flip + 90° clockwise rotation
            transformedPoint = CGPoint(x: cgHeight - cgPoint.y, y: cgWidth - cgPoint.x)
        @unknown default:
            // Fallback to no transformation
            transformedPoint = cgPoint
        }
        
        print("🎯 Transformed to (\(Int(transformedPoint.x)), \(Int(transformedPoint.y)))")
        return transformedPoint
    }
    
    private func calculatePerimeter(component: [(x: Int, y: Int, brightness: UInt8)]) -> Double {
        // Create a hashable coordinate struct
        struct Coordinate: Hashable {
            let x: Int
            let y: Int
        }
        
        let pixels = Set(component.map { Coordinate(x: $0.x, y: $0.y) })
        var perimeter = 0.0
        
        for pixel in pixels {
            let neighbors = [
                Coordinate(x: pixel.x - 1, y: pixel.y),
                Coordinate(x: pixel.x + 1, y: pixel.y),
                Coordinate(x: pixel.x, y: pixel.y - 1),
                Coordinate(x: pixel.x, y: pixel.y + 1)
            ]
            
            for neighbor in neighbors {
                if !pixels.contains(neighbor) {
                    perimeter += 1.0
                }
            }
        }
        
        return perimeter
    }
    
    private func calculateAspectRatio(component: [(x: Int, y: Int, brightness: UInt8)]) -> Double {
        let xCoords = component.map { $0.x }
        let yCoords = component.map { $0.y }
        
        guard let minX = xCoords.min(), let maxX = xCoords.max(),
              let minY = yCoords.min(), let maxY = yCoords.max() else {
            return 1.0
        }
        
        let width = Double(maxX - minX + 1)
        let height = Double(maxY - minY + 1)
        
        return max(width / height, height / width)
    }
    
    private func calculateSolidity(component: [(x: Int, y: Int, brightness: UInt8)]) -> Double {
        let xCoords = component.map { $0.x }
        let yCoords = component.map { $0.y }
        
        guard let minX = xCoords.min(), let maxX = xCoords.max(),
              let minY = yCoords.min(), let maxY = yCoords.max() else {
            return 0.0
        }
        
        let boundingBoxArea = Double((maxX - minX + 1) * (maxY - minY + 1))
        let particleArea = Double(component.count)
        
        return particleArea / boundingBoxArea
    }
    
    // MARK: - Statistics Calculation
    
    private func calculateStatistics(particles: [CoffeeParticle], grindType: CoffeeGrindType) -> (
        uniformityScore: Double,
        averageSize: Double,
        medianSize: Double,
        standardDeviation: Double,
        finesPercentage: Double,
        bouldersPercentage: Double,
        confidence: Double
    ) {
        let sizes = particles.map { $0.size }.sorted()
        let totalCount = Double(particles.count)
        
        // Calculate basic statistics
        let averageSize = sizes.reduce(0, +) / totalCount
        let medianSize = sizes[sizes.count / 2]
        
        let variance = sizes.map { pow($0 - averageSize, 2) }.reduce(0, +) / totalCount
        let standardDeviation = sqrt(variance)
        
        // Calculate uniformity score (100 - coefficient of variation as percentage)
        let coefficientOfVariation = (standardDeviation / averageSize) * 100
        let uniformityScore = max(0, 100 - coefficientOfVariation)
        
        // Calculate fines and boulders percentages
        let fines = sizes.filter { $0 < 400 }.count
        let boulders = sizes.filter { $0 > 1400 }.count
        let finesPercentage = Double(fines) / totalCount * 100
        let bouldersPercentage = Double(boulders) / totalCount * 100
        
        // Calculate confidence based on particle count and image quality
        let particleCountFactor = min(Double(particles.count) / 200.0, 1.0)
        let uniformityFactor = uniformityScore / 100.0
        let confidence = (particleCountFactor * 0.6 + uniformityFactor * 0.4) * 100
        
        return (
            uniformityScore: uniformityScore,
            averageSize: averageSize,
            medianSize: medianSize,
            standardDeviation: standardDeviation,
            finesPercentage: finesPercentage,
            bouldersPercentage: bouldersPercentage,
            confidence: confidence
        )
    }
    
    private func createProcessedImage(originalImage: UIImage, cgImage: CGImage, particles: [CoffeeParticle]) -> UIImage? {
        print("🎨 Creating overlay for \(particles.count) particles on \(Int(originalImage.size.width))x\(Int(originalImage.size.height)) image")
        print("🔍 CGImage size: \(cgImage.width)x\(cgImage.height), UIImage size: \(Int(originalImage.size.width))x\(Int(originalImage.size.height)), orientation: \(originalImage.imageOrientation.rawValue)")
        print("🔍 UIImage scale: \(originalImage.scale)")
        
        // Verify we have valid particles
        if !particles.isEmpty {
            let firstParticle = particles[0]
            print("📍 Sample particle CGImage position: (\(Int(firstParticle.position.x)), \(Int(firstParticle.position.y)))")
        }
        
        // Use UIImage size to match how it will be displayed
        let renderer = UIGraphicsImageRenderer(size: originalImage.size)
        
        return renderer.image { context in
            // Draw original image with proper orientation handling
            originalImage.draw(at: .zero)
            
            // Draw particle overlays with coordinate transformation
            context.cgContext.setLineWidth(3.0)
            
            for particle in particles {
                let color: UIColor
                switch particle.size {
                case 0..<400:
                    color = UIColor.red.withAlphaComponent(0.8)
                case 400..<800:
                    color = UIColor.yellow.withAlphaComponent(0.8)
                case 800..<1200:
                    color = UIColor.green.withAlphaComponent(0.8)
                default:
                    color = UIColor.blue.withAlphaComponent(0.8)
                }
                
                context.cgContext.setStrokeColor(color.cgColor)
                
                // Transform particle position from CGImage coordinates to UIImage display coordinates
                let transformedPosition = transformCGImageToUIImageCoordinates(
                    cgPoint: particle.position,
                    cgImageSize: CGSize(width: cgImage.width, height: cgImage.height),
                    uiImage: originalImage
                )
                
                // Calculate radius in pixels from particle area (area is in pixels²)
                let radius = sqrt(particle.area / .pi)
                
                // Verify transformed particle is within display bounds
                let isInBounds = transformedPosition.x >= 0 && 
                                transformedPosition.x < originalImage.size.width &&
                                transformedPosition.y >= 0 && 
                                transformedPosition.y < originalImage.size.height
                
                if !isInBounds {
                    print("⚠️ Transformed particle out of bounds: CGImage=(\(Int(particle.position.x)), \(Int(particle.position.y))) -> UIImage=(\(Int(transformedPosition.x)), \(Int(transformedPosition.y))), image=\(originalImage.size)")
                } else {
                    print("✅ Drawing particle at CGImage(\(Int(particle.position.x)), \(Int(particle.position.y))) -> UIImage(\(Int(transformedPosition.x)), \(Int(transformedPosition.y))) with radius \(String(format: "%.1f", radius))px")
                }
                
                // Draw at transformed position
                let rect = CGRect(
                    x: transformedPosition.x - radius,
                    y: transformedPosition.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                
                context.cgContext.strokeEllipse(in: rect)
            }
        }
    }
    
    #if DEBUG
    private func saveDebugImage(_ pixelData: [UInt8], width: Int, height: Int, filename: String) {
        // Create debug image from binary data
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: UnsafeMutablePointer(mutating: pixelData), width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let cgImage = context.makeImage() else {
            print("⚠️ Failed to create debug image")
            return
        }
        
        let image = UIImage(cgImage: cgImage)
        
        // Save to documents directory for inspection
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imageURL = documentsPath.appendingPathComponent(filename)
            if let data = image.pngData() {
                try? data.write(to: imageURL)
                print("💾 Debug image saved: \(imageURL.path)")
            }
        }
    }
    #endif
}
