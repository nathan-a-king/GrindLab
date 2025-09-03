//
//  CoffeeAnalysisEngine.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//  Refactored version incorporating advanced particle detection from Python implementation
//

import UIKit
import Vision
import Accelerate
import CoreImage

class CoffeeAnalysisEngine {
    private let settings: AnalysisSettings
    
    // Python algorithm parameters
    private let referenceThreshold: Double = 0.4
    private let maxCost: Double = 0.35
    private let defaultThreshold: Double = 58.8
    private let minRoundness: Double = 0.0
    private let smoothingWindowSize: Int = 3
    
    // Polygon selection for region of interest
    private var analysisPolygon: [CGPoint]?
    
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
    
    // Overloaded version with reference object support
    func analyzeGrind(
        image: UIImage,
        grindType: CoffeeGrindType,
        referenceObjectDiameter: Double? = nil,
        completion: @escaping (Result<CoffeeAnalysisResults, CoffeeAnalysisError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = try self.performAdvancedAnalysis(
                    image: image,
                    grindType: grindType,
                    referenceObjectDiameter: referenceObjectDiameter
                )
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
        // Delegate to advanced analysis with no reference object
        return try performAdvancedAnalysis(image: image, grindType: grindType, referenceObjectDiameter: nil)
    }
    
    private func performAdvancedAnalysis(
        image: UIImage,
        grindType: CoffeeGrindType,
        referenceObjectDiameter: Double?
    ) throws -> CoffeeAnalysisResults {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔬 Starting advanced coffee analysis for \(grindType.displayName)...")
        print("📐 Image size: \(Int(image.size.width))x\(Int(image.size.height))")
        
        guard let cgImage = image.cgImage else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        
        // Step 1: Extract blue channel (as in Python)
        print("🔵 Step 1: Extracting blue channel...")
        let blueChannelData = try extractBlueChannel(from: cgImage)
        
        // Step 2: Apply adaptive thresholding based on median
        print("🎭 Step 2: Applying adaptive thresholding...")
        let (thresholdMask, backgroundMedian) = try applyAdaptiveThreshold(
            data: blueChannelData,
            width: cgImage.width,
            height: cgImage.height
        )
        
        // Step 3: Detect particles using clustering algorithm
        print("🔍 Step 3: Detecting particles with advanced clustering...")
        let clusters = try detectParticlesWithClustering(
            thresholdMask: thresholdMask,
            imageData: blueChannelData,
            backgroundMedian: backgroundMedian,
            width: cgImage.width,
            height: cgImage.height
        )
        
        print("📊 Found \(clusters.count) valid clusters")
        
        if clusters.isEmpty {
            throw CoffeeAnalysisError.noParticlesDetected
        }
        
        // Step 4: Convert clusters to particles with proper calibration
        print("📏 Step 4: Converting clusters to calibrated particles...")
        
        // Use manual calibration from settings
        let calibrationFactor = settings.calibrationFactor
        
        print("📏 Using manual calibration factor: \(String(format: "%.2f", calibrationFactor)) μm/pixel")
        
        let particles = convertClustersToParticles(
            clusters: clusters,
            calibrationFactor: calibrationFactor
        )
        
        // Step 5: Calculate advanced statistics
        print("📈 Step 5: Calculating advanced statistics...")
        let statistics = calculateAdvancedStatistics(
            particles: particles,
            grindType: grindType
        )
        
        // Step 6: Create visualization
        print("🎨 Step 6: Creating visualization...")
        let processedImage = createVisualization(
            originalImage: image,
            particles: particles,
            grindType: grindType
        )
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        print("🎯 Analysis complete in \(String(format: "%.2f", totalTime))s")
        
        // Final calibration summary
        print("\n📊 CALIBRATION SUMMARY:")
        print("   Source: Manual")
        print("   Factor: \(String(format: "%.2f", calibrationFactor)) μm/pixel")
        print("   Average Particle Size: \(String(format: "%.1f", statistics.averageSize)) μm")
        print("\n")
        
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
            timestamp: Date(),
            calibrationFactor: calibrationFactor
        )
    }
    
    // MARK: - Blue Channel Extraction
    
    private func extractBlueChannel(from cgImage: CGImage) throws -> [UInt8] {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Extract just the blue channel
        var blueChannel = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            blueChannel[i] = pixelData[i * 4 + 2] // Blue is at offset 2
        }
        
        return blueChannel
    }
    
    // MARK: - Adaptive Thresholding
    
    private func applyAdaptiveThreshold(
        data: [UInt8],
        width: Int,
        height: Int
    ) throws -> (mask: [(x: Int, y: Int)], backgroundMedian: Double) {
        // Calculate median of the image (or within polygon if set)
        let backgroundMedian = calculateMedian(
            data: data,
            width: width,
            height: height,
            polygon: analysisPolygon
        )
        
        print("📊 Background median: \(backgroundMedian)")
        
        // Apply threshold (defaultThreshold is percentage)
        let thresholdValue = backgroundMedian * (defaultThreshold / 100.0)
        var thresholdMask: [(x: Int, y: Int)] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let pixelValue = Double(data[index])
                
                // Check if pixel is dark enough (below threshold)
                if pixelValue < thresholdValue {
                    // If polygon is set, check if point is inside
                    if let polygon = analysisPolygon {
                        if isPointInPolygon(point: CGPoint(x: x, y: y), polygon: polygon) {
                            thresholdMask.append((x: x, y: y))
                        }
                    } else {
                        thresholdMask.append((x: x, y: y))
                    }
                }
            }
        }
        
        let thresholdPercentage = Double(thresholdMask.count) / Double(width * height) * 100.0
        print("🎭 Thresholded \(thresholdMask.count) pixels (\(String(format: "%.1f", thresholdPercentage))%)")
        
        return (thresholdMask, backgroundMedian)
    }
    
    // MARK: - Advanced Particle Detection with Clustering
    
    private struct Cluster {
        var pixels: [(x: Int, y: Int, brightness: UInt8)]
        var surface: Double
        var centroidX: Double
        var centroidY: Double
        var longAxis: Double
        var shortAxis: Double
        var roundness: Double
        var volume: Double
    }
    
    private func detectParticlesWithClustering(
        thresholdMask: [(x: Int, y: Int)],
        imageData: [UInt8],
        backgroundMedian: Double,
        width: Int,
        height: Int
    ) throws -> [Cluster] {
        // Sort threshold pixels by brightness (darkest first)
        let sortedMask = thresholdMask.sorted { pixel1, pixel2 in
            let index1 = pixel1.y * width + pixel1.x
            let index2 = pixel2.y * width + pixel2.x
            return imageData[index1] < imageData[index2]
        }
        
        // Create spatial index for fast neighbor lookups
        var pixelGrid = [String: Int]() // Maps "x,y" to index in sortedMask
        for (index, pixel) in sortedMask.enumerated() {
            pixelGrid["\(pixel.x),\(pixel.y)"] = index
        }
        
        var counted = [Bool](repeating: false, count: sortedMask.count)
        var clusters: [Cluster] = []
        // Convert micron limits to pixels for clustering
        let maxClusterAxis = Double(settings.maxParticleSize) / settings.calibrationFactor
        let minDiameterPixels = Double(settings.minParticleSize) / settings.calibrationFactor
        let minSurface = (minDiameterPixels * minDiameterPixels * Double.pi) / 4.0
        
        print("🔬 Starting clustering with \(sortedMask.count) threshold pixels...")
        
        for i in 0..<sortedMask.count {
            if i % 10000 == 0 {
                let progress = Double(i) / Double(sortedMask.count) * 100.0
                print("⏳ Clustering progress: \(String(format: "%.1f", progress))%")
            }
            
            if counted[i] { continue }
            
            let startPixel = sortedMask[i]
            let startIndex = startPixel.y * width + startPixel.x
            let startBrightness = imageData[startIndex]
            
            // Find connected pixels using improved flood fill with spatial index
            let clusterPixels = quickClusterOptimized(
                startX: startPixel.x,
                startY: startPixel.y,
                pixelGrid: pixelGrid,
                sortedMask: sortedMask,
                counted: &counted,
                maxDistance: maxClusterAxis,
                startIndex: i
            )
            
            // Apply cost function for cluster breakup (from Python)
            let filteredPixels = applyClusterBreakup(
                clusterPixels: clusterPixels,
                imageData: imageData,
                backgroundMedian: backgroundMedian,
                width: width,
                startBrightness: startBrightness
            )
            
            // Check minimum surface
            guard filteredPixels.count >= Int(minSurface) else { continue }
            
            // Calculate cluster properties
            if let cluster = createCluster(from: filteredPixels, width: width, height: height) {
                // Apply quality filters
                if cluster.roundness >= minRoundness &&
                   cluster.longAxis <= maxClusterAxis {
                    clusters.append(cluster)
                }
            }
        }
        
        print("✅ Clustering complete: \(clusters.count) valid clusters found")
        return clusters
    }
    
    private func quickClusterOptimized(
        startX: Int,
        startY: Int,
        pixelGrid: [String: Int],
        sortedMask: [(x: Int, y: Int)],
        counted: inout [Bool],
        maxDistance: Double,
        startIndex: Int
    ) -> [(x: Int, y: Int, brightness: UInt8)] {
        var result: [(x: Int, y: Int, brightness: UInt8)] = []
        var toCheck = [(startX, startY)]
        var visited = Set<String>()
        
        // Mark start pixel as counted
        counted[startIndex] = true
        result.append((x: startX, y: startY, brightness: 0))
        
        while !toCheck.isEmpty {
            let (currentX, currentY) = toCheck.removeFirst()
            
            // Check 8-connected neighbors directly (much faster than checking all pixels)
            let neighbors = [
                (currentX-1, currentY-1), (currentX, currentY-1), (currentX+1, currentY-1),
                (currentX-1, currentY),                          (currentX+1, currentY),
                (currentX-1, currentY+1), (currentX, currentY+1), (currentX+1, currentY+1)
            ]
            
            for (nx, ny) in neighbors {
                let neighborKey = "\(nx),\(ny)"
                
                // Skip if already visited
                if visited.contains(neighborKey) { continue }
                visited.insert(neighborKey)
                
                // Check if this pixel exists in our threshold mask
                if let neighborIndex = pixelGrid[neighborKey] {
                    // Skip if already counted
                    if !counted[neighborIndex] {
                        counted[neighborIndex] = true
                        result.append((x: nx, y: ny, brightness: 0))
                        toCheck.append((nx, ny))
                    }
                }
            }
        }
        
        return result
    }
    
    // Keep old method for compatibility but it's not used anymore
    private func quickCluster(
        startX: Int,
        startY: Int,
        sortedMask: [(x: Int, y: Int)],
        counted: inout [Bool],
        maxDistance: Double,
        startIndex: Int
    ) -> [(x: Int, y: Int, brightness: UInt8)] {
        var result: [(x: Int, y: Int, brightness: UInt8)] = []
        var toCheck = [(startX, startY)]
        var checked = Set<String>()
        
        // Mark start pixel as counted
        counted[startIndex] = true
        
        while !toCheck.isEmpty {
            let (checkX, checkY) = toCheck.removeFirst()
            let key = "\(checkX),\(checkY)"
            
            if checked.contains(key) { continue }
            checked.insert(key)
            
            // Find all uncounted pixels within range
            for (idx, pixel) in sortedMask.enumerated() {
                if counted[idx] { continue }
                
                let distance = sqrt(pow(Double(pixel.x - checkX), 2) + pow(Double(pixel.y - checkY), 2))
                if distance <= 1.5 { // Adjacent pixels
                    counted[idx] = true
                    result.append((x: pixel.x, y: pixel.y, brightness: 0)) // Will fill brightness later
                    toCheck.append((pixel.x, pixel.y))
                }
            }
        }
        
        return result
    }
    
    private func applyClusterBreakup(
        clusterPixels: [(x: Int, y: Int, brightness: UInt8)],
        imageData: [UInt8],
        backgroundMedian: Double,
        width: Int,
        startBrightness: UInt8
    ) -> [(x: Int, y: Int, brightness: UInt8)] {
        // This implements the cost function from Python for breaking up clumped particles
        var filteredPixels: [(x: Int, y: Int, brightness: UInt8)] = []
        
        for pixel in clusterPixels {
            let index = pixel.y * width + pixel.x
            let brightness = imageData[index]
            
            // Calculate cost function
            let cost = pow(Double(brightness) - Double(startBrightness), 2) / pow(backgroundMedian, 2)
            
            // Accept pixel if cost is below threshold
            if cost < maxCost {
                filteredPixels.append((x: pixel.x, y: pixel.y, brightness: brightness))
            }
        }
        
        return filteredPixels
    }
    
    private func createCluster(
        from pixels: [(x: Int, y: Int, brightness: UInt8)],
        width: Int,
        height: Int
    ) -> Cluster? {
        guard !pixels.isEmpty else { return nil }
        
        let surface = Double(pixels.count)
        
        // Calculate centroid
        let centroidX = Double(pixels.map { $0.x }.reduce(0, +)) / Double(pixels.count)
        let centroidY = Double(pixels.map { $0.y }.reduce(0, +)) / Double(pixels.count)
        
        // Calculate axes
        let distances = pixels.map { pixel in
            sqrt(pow(Double(pixel.x) - centroidX, 2) + pow(Double(pixel.y) - centroidY, 2))
        }
        let longAxis = distances.max() ?? 0
        let shortAxis = surface / (Double.pi * longAxis)
        
        // Calculate roundness
        let roundness = surface / (Double.pi * longAxis * longAxis)
        
        // Estimate volume (ellipsoid approximation)
        let volume = Double.pi * shortAxis * shortAxis * longAxis
        
        // Check edge proximity
        let edgeBuffer = 10.0
        if centroidX < edgeBuffer || centroidX > Double(width - Int(edgeBuffer)) ||
           centroidY < edgeBuffer || centroidY > Double(height - Int(edgeBuffer)) {
            return nil // Too close to edge
        }
        
        return Cluster(
            pixels: pixels,
            surface: surface,
            centroidX: centroidX,
            centroidY: centroidY,
            longAxis: longAxis,
            shortAxis: shortAxis,
            roundness: roundness,
            volume: volume
        )
    }
    
    // MARK: - Particle Conversion and Calibration
    
    private func calculateCalibrationFactor(
        referenceObjectDiameter: Double?,
        imageWidth: Int
    ) -> Double {
        if let diameter = referenceObjectDiameter, diameter > 0 {
            // If we have a reference object, use it for calibration
            // This would need the reference object pixel length from user selection
            // For now, return a reasonable default
            return diameter / 100.0 // Placeholder - would need actual pixel measurement
        }
        
        // Default calibration based on typical smartphone photos
        return settings.calibrationFactor
    }
    
    
    private func convertClustersToParticles(
        clusters: [Cluster],
        calibrationFactor: Double
    ) -> [CoffeeParticle] {
        // Settings already store size limits in microns
        let minSizeMicrons = Double(settings.minParticleSize)
        let maxSizeMicrons = Double(settings.maxParticleSize)
        
        print("📏 Filtering particles: \(String(format: "%.1f", minSizeMicrons)) - \(String(format: "%.1f", maxSizeMicrons)) μm")
        
        let allParticles = clusters.compactMap { cluster -> CoffeeParticle? in
            // Use actual measured span instead of equivalent circle diameter
            let diameterPixels = cluster.longAxis * 2.0
            let sizeMicrons = diameterPixels * calibrationFactor
            
            // Filter by size in microns
            guard sizeMicrons >= minSizeMicrons && sizeMicrons <= maxSizeMicrons else {
                return nil
            }
            
            // Calculate circularity (perimeter-based)
            let perimeter = calculatePerimeterFromPixels(pixels: cluster.pixels)
            let circularity = (4.0 * Double.pi * cluster.surface) / (perimeter * perimeter)
            
            // Calculate average brightness
            let avgBrightness = cluster.pixels.isEmpty ? 0.5 :
                Double(cluster.pixels.map { Int($0.brightness) }.reduce(0, +)) / Double(cluster.pixels.count) / 255.0
            
            return CoffeeParticle(
                size: sizeMicrons,
                area: cluster.surface,
                circularity: min(max(circularity, 0), 1),
                position: CGPoint(x: cluster.centroidX, y: cluster.centroidY),
                brightness: avgBrightness,
                pixels: cluster.pixels.map { (x: $0.x, y: $0.y) }
            )
        }
        
        print("✅ Filtered \(allParticles.count) particles from \(clusters.count) clusters")
        return allParticles
    }
    
    private func calculatePerimeterFromPixels(pixels: [(x: Int, y: Int, brightness: UInt8)]) -> Double {
        let pixelSet = Set(pixels.map { "\($0.x),\($0.y)" })
        var perimeter = 0.0
        
        for pixel in pixels {
            // Check 4-connected neighbors
            let neighbors = [
                "\(pixel.x-1),\(pixel.y)",
                "\(pixel.x+1),\(pixel.y)",
                "\(pixel.x),\(pixel.y-1)",
                "\(pixel.x),\(pixel.y+1)"
            ]
            
            for neighbor in neighbors {
                if !pixelSet.contains(neighbor) {
                    perimeter += 1.0
                }
            }
        }
        
        return perimeter
    }
    
    // Keep old thresholding method for validation tests
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
                        // Convert micron limits to pixels for comparison
                        let minDiameterPixels = Double(settings.minParticleSize) / settings.calibrationFactor
                        let maxDiameterPixels = Double(settings.maxParticleSize) / settings.calibrationFactor
                        
                        // Use the actual diameter calculated in createParticle for comparison
                        let actualDiameterPixels = particle.size / settings.calibrationFactor
                        
                        // Size filtering using actual diameter in pixels
                        if actualDiameterPixels >= minDiameterPixels && actualDiameterPixels <= maxDiameterPixels {
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
        
        // Calculate actual span instead of equivalent circle diameter
        let maxDistance = component.map { pixel in
            sqrt(pow(Double(pixel.x) - centroidX, 2) + pow(Double(pixel.y) - centroidY, 2))
        }.max() ?? 0
        let actualDiameter = maxDistance * 2.0
        
        // Micron conversion with calibration factor
        let pixelsToMicrons: Double
        if settings.calibrationFactor > 0.1 { // If we have ruler calibration
            pixelsToMicrons = settings.calibrationFactor
        } else {
            // Default based on typical smartphone macro photos
            // Approximately 100-150 microns per pixel for close-up coffee photos
            pixelsToMicrons = 100.0
        }
        let sizeMicrons = actualDiameter * pixelsToMicrons
        
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
        print("🔍 Component at (\(Int(centroidX)), \(Int(centroidY))): \(component.count) pixels, diameter: \(String(format: "%.1f", actualDiameter))px, size: \(String(format: "%.0f", sizeMicrons))μm")
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
            brightness: avgBrightness,
            pixels: component.map { (x: $0.x, y: $0.y) }
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
    
    // MARK: - Advanced Statistics
    
    private func calculateAdvancedStatistics(
        particles: [CoffeeParticle],
        grindType: CoffeeGrindType
    ) -> (
        uniformityScore: Double,
        averageSize: Double,
        medianSize: Double,
        standardDeviation: Double,
        finesPercentage: Double,
        bouldersPercentage: Double,
        confidence: Double
    ) {
        let sizes = particles.map { $0.size }.sorted()
        let volumes = particles.map { calculateVolume(from: $0) }
        
        // Weight by volume for more accurate statistics
        let totalVolume = volumes.reduce(0, +)
        var weightedSum = 0.0
        for i in 0..<particles.count {
            weightedSum += sizes[i] * (volumes[i] / totalVolume)
        }
        let weightedAverage = weightedSum
        
        // Calculate median
        let medianSize = sizes[sizes.count / 2]
        
        // Calculate weighted standard deviation
        var weightedVariance = 0.0
        for i in 0..<particles.count {
            let weight = volumes[i] / totalVolume
            weightedVariance += weight * pow(sizes[i] - weightedAverage, 2)
        }
        let standardDeviation = sqrt(weightedVariance)
        
        // Calculate uniformity (using coefficient of variation)
        let coefficientOfVariation = (standardDeviation / weightedAverage) * 100
        let uniformityScore = max(0, 100 - coefficientOfVariation)
        
        // Calculate fines and boulders based on grind type
        let targetRange = grindType.targetSizeMicrons
        let fineThreshold = targetRange.lowerBound * 0.6
        let boulderThreshold = targetRange.upperBound * 1.5
        
        let fines = sizes.filter { $0 < fineThreshold }.count
        let boulders = sizes.filter { $0 > boulderThreshold }.count
        
        let finesPercentage = Double(fines) / Double(particles.count) * 100
        let bouldersPercentage = Double(boulders) / Double(particles.count) * 100
        
        // Calculate confidence based on multiple factors
        let particleCountScore = min(Double(particles.count) / 500.0, 1.0)
        let uniformityScore2 = uniformityScore / 100.0
        let distributionScore = 1.0 - (finesPercentage + bouldersPercentage) / 100.0
        
        let confidence = (particleCountScore * 0.4 + uniformityScore2 * 0.3 + distributionScore * 0.3) * 100
        
        return (
            uniformityScore: uniformityScore,
            averageSize: weightedAverage,
            medianSize: medianSize,
            standardDeviation: standardDeviation,
            finesPercentage: finesPercentage,
            bouldersPercentage: bouldersPercentage,
            confidence: confidence
        )
    }
    
    private func calculateVolume(from particle: CoffeeParticle) -> Double {
        // Estimate volume from area assuming spherical particles
        let radius = sqrt(particle.area / Double.pi)
        return (4.0 / 3.0) * Double.pi * pow(radius, 3)
    }
    
    // Keep old statistics for validation tests
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
    
    // MARK: - Visualization
    
    private func createVisualization(
        originalImage: UIImage,
        particles: [CoffeeParticle],
        grindType: CoffeeGrindType
    ) -> UIImage? {
        guard let cgImage = originalImage.cgImage else { return nil }
        
        print("🎨 Creating overlay for \(particles.count) particles")
        print("🔍 CGImage size: \(cgImage.width)x\(cgImage.height), UIImage size: \(Int(originalImage.size.width))x\(Int(originalImage.size.height))")
        
        let renderer = UIGraphicsImageRenderer(size: originalImage.size)
        
        return renderer.image { context in
            originalImage.draw(at: .zero)
            
            context.cgContext.setLineWidth(3.0)
            
            for particle in particles {
                // Create a path for all pixels in this particle
                let path = CGMutablePath()
                
                // Transform each pixel and add to path
                for pixel in particle.pixels {
                    let pixelPoint = CGPoint(x: pixel.x, y: pixel.y)
                    let transformedPixel = transformCGImageToUIImageCoordinates(
                        cgPoint: pixelPoint,
                        cgImageSize: CGSize(width: cgImage.width, height: cgImage.height),
                        uiImage: originalImage
                    )
                    
                    // Add a small rectangle for each pixel to the path
                    let pixelRect = CGRect(
                        x: transformedPixel.x,
                        y: transformedPixel.y,
                        width: 1,
                        height: 1
                    )
                    path.addRect(pixelRect)
                }
                
                // Set the blue color with transparency for this particle
                context.cgContext.setFillColor(UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.5).cgColor)
                context.cgContext.addPath(path)
                context.cgContext.fillPath()
                
                // Add size label for larger particles
                if particle.size > 500 {
                    let transformedPosition = transformCGImageToUIImageCoordinates(
                        cgPoint: particle.position,
                        cgImageSize: CGSize(width: cgImage.width, height: cgImage.height),
                        uiImage: originalImage
                    )
                    
                    let sizeText = String(format: "%.0fμm", particle.size)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 10),
                        .foregroundColor: UIColor.white,
                        .backgroundColor: UIColor.black.withAlphaComponent(0.7)
                    ]
                    
                    let textSize = sizeText.size(withAttributes: attributes)
                    let textRect = CGRect(
                        x: transformedPosition.x - textSize.width/2,
                        y: transformedPosition.y - textSize.height/2,
                        width: textSize.width,
                        height: textSize.height
                    )
                    
                    sizeText.draw(in: textRect, withAttributes: attributes)
                }
            }
        }
    }
    
    // Keep old processed image method for validation tests
    private func createProcessedImage(originalImage: UIImage, cgImage: CGImage, particles: [CoffeeParticle], grindType: CoffeeGrindType) -> UIImage? {
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
                // Create a path for all pixels in this particle
                let path = CGMutablePath()
                
                // Transform each pixel and add to path
                for pixel in particle.pixels {
                    let pixelPoint = CGPoint(x: pixel.x, y: pixel.y)
                    let transformedPixel = transformCGImageToUIImageCoordinates(
                        cgPoint: pixelPoint,
                        cgImageSize: CGSize(width: cgImage.width, height: cgImage.height),
                        uiImage: originalImage
                    )
                    
                    // Add a small rectangle for each pixel to the path
                    let pixelRect = CGRect(
                        x: transformedPixel.x,
                        y: transformedPixel.y,
                        width: 1,
                        height: 1
                    )
                    path.addRect(pixelRect)
                }
                
                // Set the blue color with transparency for this particle
                context.cgContext.setFillColor(UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.5).cgColor)
                context.cgContext.addPath(path)
                context.cgContext.fillPath()
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
    
    // MARK: - Helper Functions
    
    private func calculateMedian(
        data: [UInt8],
        width: Int,
        height: Int,
        polygon: [CGPoint]?
    ) -> Double {
        var values: [UInt8] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let point = CGPoint(x: x, y: y)
                
                // If polygon is set, only include points inside
                if let polygon = polygon {
                    if isPointInPolygon(point: point, polygon: polygon) {
                        let index = y * width + x
                        values.append(data[index])
                    }
                } else {
                    let index = y * width + x
                    values.append(data[index])
                }
            }
        }
        
        values.sort()
        let count = values.count
        
        if count == 0 { return 0 }
        if count == 1 { return Double(values[0]) }
        
        if count % 2 == 0 {
            // For even count, average the two middle values
            let midIndex1 = count / 2 - 1
            let midIndex2 = count / 2
            // Prevent overflow by converting to Double before addition
            return (Double(values[midIndex1]) + Double(values[midIndex2])) / 2.0
        } else {
            // For odd count, return the middle value
            return Double(values[count / 2])
        }
    }
    
    private func isPointInPolygon(point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        var p1 = polygon.last!
        
        for p2 in polygon {
            if (p2.y > point.y) != (p1.y > point.y) {
                let slope = (point.x - p1.x) * (p2.y - p1.y) - (p2.x - p1.x) * (point.y - p1.y)
                if (p2.y > p1.y && slope < 0) || (p2.y < p1.y && slope > 0) {
                    inside = !inside
                }
            }
            p1 = p2
        }
        
        return inside
    }
    
    // MARK: - Public Methods for UI Integration
    
    func setAnalysisRegion(polygon: [CGPoint]) {
        self.analysisPolygon = polygon
        print("📍 Analysis region set with \(polygon.count) points")
    }
    
    func clearAnalysisRegion() {
        self.analysisPolygon = nil
        print("📍 Analysis region cleared")
    }
}
