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
        // Step 1: Preprocess the image
        guard let preprocessedImage = preprocessImage(image) else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        
        // Step 2: Convert to grayscale and apply filters
        guard let grayImage = convertToGrayscale(preprocessedImage) else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        
        // Step 3: Apply edge detection and thresholding
        guard let binaryImage = applyThresholding(grayImage) else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        
        // Step 4: Detect and analyze particles
        let particles = try detectParticles(in: binaryImage, originalImage: grayImage)
        
        if particles.isEmpty {
            throw CoffeeAnalysisError.noParticlesDetected
        }
        
        // Step 5: Calculate statistics
        let statistics = calculateStatistics(particles: particles, grindType: grindType)
        
        // Step 6: Create processed image for visualization
        let processedImage = createProcessedImage(originalImage: image, particles: particles)
        
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
    
    private func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        
        // Apply exposure and contrast adjustments
        let exposureFilter = CIFilter(name: "CIExposureAdjust")!
        exposureFilter.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.5, forKey: kCIInputEVKey)
        
        guard let exposureOutput = exposureFilter.outputImage else { return nil }
        
        let contrastFilter = CIFilter(name: "CIColorControls")!
        contrastFilter.setValue(exposureOutput, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.2, forKey: kCIInputContrastKey)
        contrastFilter.setValue(1.0, forKey: kCIInputSaturationKey)
        
        guard let contrastOutput = contrastFilter.outputImage,
              let cgImage = context.createCGImage(contrastOutput, from: contrastOutput.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
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
    
    private func applyThresholding(_ image: UIImage) -> UIImage? {
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
        
        // Calculate adaptive threshold using Otsu's method
        let threshold = calculateOtsuThreshold(pixelData)
        
        // Apply threshold
        for i in 0..<pixelData.count {
            pixelData[i] = pixelData[i] > threshold ? 255 : 0
        }
        
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
    
    // MARK: - Particle Detection
    
    private func detectParticles(in binaryImage: UIImage, originalImage: UIImage) throws -> [CoffeeParticle] {
        guard let cgImage = binaryImage.cgImage,
              let originalCGImage = originalImage.cgImage else {
            throw CoffeeAnalysisError.imageProcessingFailed
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
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
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                
                if !visited[index] && binaryData[index] == 0 { // Dark pixels (coffee particles)
                    let component = floodFill(
                        x: x, y: y,
                        width: width, height: height,
                        binaryData: binaryData,
                        grayData: grayData,
                        visited: &visited
                    )
                    
                    if let particle = createParticle(from: component) {
                        if particle.area >= Double(settings.minParticleSize) &&
                           particle.area <= Double(settings.maxParticleSize) {
                            particles.append(particle)
                        }
                    }
                }
            }
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
    
    private func createParticle(from component: [(x: Int, y: Int, brightness: UInt8)]) -> CoffeeParticle? {
        guard !component.isEmpty else { return nil }
        
        let area = Double(component.count)
        
        // Calculate centroid
        let centroidX = Double(component.map { $0.x }.reduce(0, +)) / Double(component.count)
        let centroidY = Double(component.map { $0.y }.reduce(0, +)) / Double(component.count)
        
        // Calculate equivalent diameter (assuming circular particles)
        let radius = sqrt(area / .pi)
        let equivalentDiameter = radius * 2
        
        // Convert to microns (rough calibration - would need actual calibration in real app)
        let sizeMicrons = equivalentDiameter * settings.calibrationFactor * 50 // Approximate scaling
        
        // Calculate circularity (perimeter²/(4π×area))
        let perimeter = calculatePerimeter(component: component)
        let circularity = (4 * .pi * area) / (perimeter * perimeter)
        
        // Calculate average brightness
        let avgBrightness = Double(component.map { Double($0.brightness) }.reduce(0, +)) / Double(component.count) / 255.0
        
        return CoffeeParticle(
            size: sizeMicrons,
            area: area,
            circularity: min(circularity, 1.0),
            position: CGPoint(x: centroidX, y: centroidY),
            brightness: avgBrightness
        )
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
    
    private func createProcessedImage(originalImage: UIImage, particles: [CoffeeParticle]) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: originalImage.size)
        
        return renderer.image { context in
            // Draw original image
            originalImage.draw(at: .zero)
            
            // Draw particle overlays
            context.cgContext.setLineWidth(1.0)
            
            for particle in particles {
                let color: UIColor
                switch particle.size {
                case 0..<400:
                    color = UIColor.red.withAlphaComponent(0.6)
                case 400..<800:
                    color = UIColor.yellow.withAlphaComponent(0.6)
                case 800..<1200:
                    color = UIColor.green.withAlphaComponent(0.6)
                default:
                    color = UIColor.blue.withAlphaComponent(0.6)
                }
                
                context.cgContext.setStrokeColor(color.cgColor)
                
                let radius = sqrt(particle.area / .pi)
                let rect = CGRect(
                    x: particle.position.x - radius,
                    y: particle.position.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                
                context.cgContext.strokeEllipse(in: rect)
            }
        }
    }
}
