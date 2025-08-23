//
//  CoinCalibrationDetector.swift
//  Coffee Grind Analyzer
//
//  Automatic coin detection for calibration - Working Implementation
//

import UIKit
import Vision
import CoreImage
import Accelerate

// MARK: - Reference Objects
enum ReferenceObject: CaseIterable {
    case usQuarter
    case usPenny
    case usNickel
    case usDime
    case euroOne
    case euroTwo
    
    var displayName: String {
        switch self {
        case .usQuarter: return "US Quarter"
        case .usPenny: return "US Penny"
        case .usNickel: return "US Nickel"
        case .usDime: return "US Dime"
        case .euroOne: return "1 Euro"
        case .euroTwo: return "2 Euro"
        }
    }
    
    var diameterMM: Double {
        switch self {
        case .usQuarter: return 24.26
        case .usPenny: return 19.05
        case .usNickel: return 21.21
        case .usDime: return 17.91
        case .euroOne: return 23.25
        case .euroTwo: return 25.75
        }
    }
    
    // Color characteristics (Hue, Saturation ranges)
    var colorCharacteristics: (hueRange: ClosedRange<Float>, saturationMin: Float, brightnessMin: Float) {
        switch self {
        case .usPenny:
            // Copper/bronze color
            return (hueRange: 0.02...0.08, saturationMin: 0.3, brightnessMin: 0.3)
        case .usQuarter, .usNickel, .usDime:
            // Silver/nickel color (low saturation)
            return (hueRange: 0.0...1.0, saturationMin: 0.0, brightnessMin: 0.5)
        case .euroOne, .euroTwo:
            // Bi-metallic (varies)
            return (hueRange: 0.0...1.0, saturationMin: 0.0, brightnessMin: 0.4)
        }
    }
}

// MARK: - Detection Results
struct CoinDetection {
    let coinType: ReferenceObject
    let diameterPixels: Double
    let center: CGPoint
    let confidence: Double
    let boundingBox: CGRect
    
    var calibrationFactor: Double {
        return (coinType.diameterMM * 1000) / diameterPixels
    }
}

struct DetectedCircle {
    let center: CGPoint
    let radius: Double
    let circularity: Double
    let averageColor: UIColor
    let edgeStrength: Double
}

// MARK: - CGRect Extension
extension CGRect {
    var area: CGFloat {
        return width * height
    }
}

// MARK: - Coin Calibration Detector
class CoinCalibrationDetector {
    
    // MARK: - Public Methods
    func detectAndMeasureCoins(in image: UIImage, completion: @escaping ([CoinDetection]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let detections = self.performDetection(in: image)
            DispatchQueue.main.async {
                completion(detections)
            }
        }
    }
    
    // MARK: - Main Detection Pipeline
    private func performDetection(in image: UIImage) -> [CoinDetection] {
        print("🔍 Starting coin detection...")
        
        // Step 1: Preprocess the image
        guard let processedImage = preprocessImage(image) else {
            print("❌ Failed to preprocess image")
            return []
        }
        
        // Step 2: Detect circles using Vision or custom detection
        let circles = detectCircles(in: processedImage, originalImage: image)
        print("📊 Found \(circles.count) potential circles")
        
        // Step 3: Analyze each circle and identify coins
        var detections: [CoinDetection] = []
        for circle in circles {
            if let detection = identifyCoin(circle: circle, in: image) {
                detections.append(detection)
            }
        }
        
        print("✅ Identified \(detections.count) coins")
        return detections.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Image Preprocessing
    private func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        
        // Chain of filters for better edge detection
        var outputImage = ciImage
        
        // 1. Reduce noise
        if let noiseReduction = CIFilter(name: "CINoiseReduction") {
            noiseReduction.setValue(outputImage, forKey: kCIInputImageKey)
            noiseReduction.setValue(0.02, forKey: "inputNoiseLevel")
            noiseReduction.setValue(0.40, forKey: "inputSharpness")
            outputImage = noiseReduction.outputImage ?? outputImage
        }
        
        // 2. Enhance contrast
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(outputImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.2, forKey: kCIInputContrastKey)
            contrastFilter.setValue(0.0, forKey: kCIInputBrightnessKey)
            contrastFilter.setValue(1.0, forKey: kCIInputSaturationKey)
            outputImage = contrastFilter.outputImage ?? outputImage
        }
        
        // 3. Convert to grayscale for edge detection
        if let grayscaleFilter = CIFilter(name: "CIPhotoEffectNoir") {
            grayscaleFilter.setValue(outputImage, forKey: kCIInputImageKey)
            outputImage = grayscaleFilter.outputImage ?? outputImage
        }
        
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Circle Detection
    private func detectCircles(in processedImage: UIImage, originalImage: UIImage) -> [DetectedCircle] {
        guard let inputCGImage = processedImage.cgImage else { return [] }
        
        var circles: [DetectedCircle] = []
        
        // Try Vision framework for contour detection
        let request = VNDetectContoursRequest { [weak self] request, error in
            guard let self = self,
                  error == nil,
                  let observations = request.results as? [VNContoursObservation] else { return }
            
            // Process contours to find circular ones
            for observation in observations {
                if let detectedCircles = self.extractCirclesFromContour(
                    observation,
                    imageSize: processedImage.size,
                    originalImage: originalImage
                ) {
                    circles.append(contentsOf: detectedCircles)
                }
            }
        }
        
        // Configure request
        request.contrastAdjustment = 2.0
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 1024
        
        // Perform request
        let handler = VNImageRequestHandler(cgImage: inputCGImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision request failed: \(error)")
        }
        
        // If Vision doesn't find circles, use custom detection
        if circles.isEmpty {
            circles = customCircleDetection(in: processedImage, originalImage: originalImage)
        }
        
        return circles
    }
    
    // MARK: - Extract Circles from Contour
    private func extractCirclesFromContour(
        _ contour: VNContoursObservation,
        imageSize: CGSize,
        originalImage: UIImage
    ) -> [DetectedCircle]? {
        
        var circles: [DetectedCircle] = []
        
        // Check if contour could be circular
        let path = contour.normalizedPath
        let boundingBox = path.boundingBox
        
        // Check aspect ratio
        let aspectRatio = boundingBox.width / boundingBox.height
        guard abs(aspectRatio - 1.0) < 0.3 else { return nil }
        
        // Convert to image coordinates
        let center = CGPoint(
            x: boundingBox.midX * imageSize.width,
            y: (1 - boundingBox.midY) * imageSize.height
        )
        let radius = (min(boundingBox.width, boundingBox.height) * min(imageSize.width, imageSize.height)) / 2
        
        // Estimate circularity based on contour properties
        let circularity = estimateCircularityFromPath(path)
        
        // Get color at center
        let averageColor = getAverageColor(at: center, radius: radius, in: originalImage)
        
        if circularity > 0.7 {
            circles.append(DetectedCircle(
                center: center,
                radius: radius,
                circularity: circularity,
                averageColor: averageColor,
                edgeStrength: 1.0
            ))
        }
        
        return circles.isEmpty ? nil : circles
    }
    
    // MARK: - Estimate Circularity from Path
    private func estimateCircularityFromPath(_ path: CGPath) -> Double {
        // Simple circularity estimation based on bounding box
        let boundingBox = path.boundingBox
        let area = Double(boundingBox.width * boundingBox.height)
        let radius = Double(min(boundingBox.width, boundingBox.height) / 2)
        let expectedCircleArea = Double.pi * radius * radius
        
        // Ratio of expected circle area to bounding box area
        let fillRatio = expectedCircleArea / area
        
        // For a perfect circle in a square, this ratio is π/4 ≈ 0.785
        // Map this to a 0-1 scale
        return min(fillRatio / 0.785, 1.0)
    }
    
    // MARK: - Custom Circle Detection
    private func customCircleDetection(in image: UIImage, originalImage: UIImage) -> [DetectedCircle] {
        guard let cgImage = image.cgImage else { return [] }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create edge map using Sobel operator
        guard let edgeMap = applySobelEdgeDetection(to: cgImage) else { return [] }
        
        // Use simplified Hough Transform for circle detection
        return houghCircleTransform(
            edgeMap: edgeMap,
            imageWidth: width,
            imageHeight: height,
            originalImage: originalImage
        )
    }
    
    // MARK: - Sobel Edge Detection
    private func applySobelEdgeDetection(to cgImage: CGImage) -> [[Double]]? {
        let width = cgImage.width
        let height = cgImage.height
        
        // Get pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelBuffer = context.data else { return nil }
        let pixelData = pixelBuffer.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        var edgeMap = Array(repeating: Array(repeating: 0.0, count: width), count: height)
        
        // Sobel kernels
        let sobelX: [[Double]] = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]]
        let sobelY: [[Double]] = [[-1, -2, -1], [0, 0, 0], [1, 2, 1]]
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var gx = 0.0
                var gy = 0.0
                
                // Apply Sobel kernels
                for ky in -1...1 {
                    for kx in -1...1 {
                        let pixelIndex = ((y + ky) * width + (x + kx)) * bytesPerPixel
                        // Use red channel for grayscale
                        let intensity = Double(pixelData[pixelIndex]) / 255.0
                        
                        gx += intensity * sobelX[ky + 1][kx + 1]
                        gy += intensity * sobelY[ky + 1][kx + 1]
                    }
                }
                
                // Calculate edge magnitude
                edgeMap[y][x] = sqrt(gx * gx + gy * gy)
            }
        }
        
        return edgeMap
    }
    
    // MARK: - Simplified Hough Circle Transform
    private func houghCircleTransform(
        edgeMap: [[Double]],
        imageWidth: Int,
        imageHeight: Int,
        originalImage: UIImage
    ) -> [DetectedCircle] {
        
        let height = edgeMap.count
        let width = edgeMap[0].count
        
        print("🔍 Starting Hough transform for \(width)x\(height) image")
        
        // Define search parameters - make them more aggressive
        let minRadius = max(20, min(width, height) / 30)  // Minimum coin size
        let maxRadius = min(width/4, height/4, 200)  // Maximum coin size, capped at 200px
        let radiusStep = 10  // Larger steps for faster processing
        
        print("📏 Searching for circles with radius \(minRadius)-\(maxRadius)")
        
        var circles: [DetectedCircle] = []
        
        // Accumulator for voting
        var accumulator: [String: Int] = [:]
        
        // Edge threshold
        let edgeThreshold = 0.2  // Lower threshold to get more edge points
        
        // Find edge points
        var edgePoints: [(x: Int, y: Int)] = []
        for y in stride(from: 0, to: height, by: 2) {  // Sample every other pixel
            for x in stride(from: 0, to: width, by: 2) {
                if edgeMap[y][x] > edgeThreshold {
                    edgePoints.append((x: x, y: y))
                }
            }
        }
        
        print("📍 Found \(edgePoints.count) edge points")
        
        // Limit edge points to prevent excessive computation
        let maxEdgePoints = 2000  // Reduced from 5000
        if edgePoints.count > maxEdgePoints {
            edgePoints = Array(edgePoints.shuffled().prefix(maxEdgePoints))
            print("📍 Limited to \(maxEdgePoints) edge points")
        }
        
        // Vote for circles - use fewer angle samples
        for radius in stride(from: minRadius, to: maxRadius, by: radiusStep) {
            for (index, point) in edgePoints.enumerated() {
                // Show progress
                if index % 100 == 0 {
                    let progress = Float(index) / Float(edgePoints.count)
                    print("⏳ Processing radius \(radius): \(Int(progress * 100))%")
                }
                
                // Vote for possible circle centers - use fewer angles
                for angle in stride(from: 0, to: 2 * Double.pi, by: Double.pi / 12) {  // Reduced from 18 to 12
                    let cx = Int(Double(point.x) - Double(radius) * cos(angle))
                    let cy = Int(Double(point.y) - Double(radius) * sin(angle))
                    
                    if cx >= radius && cx < width - radius && cy >= radius && cy < height - radius {
                        let key = "\(cx),\(cy),\(radius)"
                        accumulator[key, default: 0] += 1
                    }
                }
            }
        }
        
        print("🗳️ Voting complete, analyzing \(accumulator.count) candidates")
        
        // Find peaks in accumulator - lower threshold
        let threshold = max(10, edgePoints.count / 100)  // Dynamic threshold
        var detectedCircles: [(center: CGPoint, radius: Double, votes: Int)] = []
        
        for (key, votes) in accumulator where votes > threshold {
            let components = key.split(separator: ",")
            if components.count == 3,
               let cx = Int(components[0]),
               let cy = Int(components[1]),
               let radius = Int(components[2]) {
                
                let center = CGPoint(x: cx, y: cy)
                detectedCircles.append((center: center, radius: Double(radius), votes: votes))
            }
        }
        
        print("🎯 Found \(detectedCircles.count) circles above threshold")
        
        // Sort by votes and take top candidates
        detectedCircles.sort { $0.votes > $1.votes }
        
        // Remove overlapping circles
        var finalCircles: [DetectedCircle] = []
        for candidate in detectedCircles.prefix(10) {  // Reduced from 20
            // Check if this circle overlaps with already selected ones
            let isUnique = !finalCircles.contains { existing in
                let dx = existing.center.x - candidate.center.x
                let dy = existing.center.y - candidate.center.y
                let distance = sqrt(dx * dx + dy * dy)
                return distance < (existing.radius + candidate.radius) * 0.5
            }
            
            if isUnique {
                // Quick circularity check - don't be too strict
                let circularity = calculateCircularity(
                    center: candidate.center,
                    radius: candidate.radius,
                    edgeMap: edgeMap
                )
                
                // Get average color from original image
                let averageColor = getAverageColor(
                    at: candidate.center,
                    radius: candidate.radius,
                    in: originalImage
                )
                
                print("⭕ Circle at (\(Int(candidate.center.x)), \(Int(candidate.center.y))), radius: \(Int(candidate.radius)), circularity: \(circularity)")
                
                if circularity > 0.4 {  // Lowered from 0.6
                    finalCircles.append(DetectedCircle(
                        center: candidate.center,
                        radius: candidate.radius,
                        circularity: circularity,
                        averageColor: averageColor,
                        edgeStrength: Double(candidate.votes) / Double(threshold)
                    ))
                }
            }
        }
        
        print("✅ Returning \(finalCircles.count) final circles")
        return finalCircles
    }
    
    // MARK: - Calculate Actual Circularity
    private func calculateCircularity(center: CGPoint, radius: Double, edgeMap: [[Double]]) -> Double {
        let samples = 36  // Sample points around the circle
        var edgeCount = 0
        
        for i in 0..<samples {
            let angle = (Double(i) * 2 * Double.pi) / Double(samples)
            let x = Int(center.x + radius * cos(angle))
            let y = Int(center.y + radius * sin(angle))
            
            // Check if this point is on an edge
            if y >= 0 && y < edgeMap.count && x >= 0 && x < edgeMap[0].count {
                if edgeMap[y][x] > 0.3 {
                    edgeCount += 1
                }
            }
        }
        
        // Circularity is the ratio of edge points to total samples
        return Double(edgeCount) / Double(samples)
    }
    
    // MARK: - Get Average Color
    private func getAverageColor(at center: CGPoint, radius: Double, in image: UIImage) -> UIColor {
        guard let cgImage = image.cgImage else { return UIColor.gray }
        
        // Create a small context to sample the circle area
        let sampleSize = Int(radius * 2)
        guard sampleSize > 0 else { return UIColor.gray }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return UIColor.gray }
        
        // Draw the circular region
        let rect = CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize)
        context.addEllipse(in: rect)
        context.clip()
        
        // Calculate source rectangle
        let sourceRect = CGRect(
            x: max(0, center.x - radius),
            y: max(0, center.y - radius),
            width: min(radius * 2, Double(cgImage.width) - (center.x - radius)),
            height: min(radius * 2, Double(cgImage.height) - (center.y - radius))
        )
        
        if sourceRect.width > 0 && sourceRect.height > 0,
           let croppedImage = cgImage.cropping(to: sourceRect) {
            context.draw(croppedImage, in: rect)
        }
        
        // Get pixel data
        guard let pixelData = context.data else { return UIColor.gray }
        
        let data = pixelData.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)
        
        var totalR: Int = 0
        var totalG: Int = 0
        var totalB: Int = 0
        var pixelCount = 0
        
        for y in 0..<sampleSize {
            for x in 0..<sampleSize {
                // Check if pixel is within circle
                let dx = Double(x) - Double(sampleSize) / 2
                let dy = Double(y) - Double(sampleSize) / 2
                if dx * dx + dy * dy <= radius * radius {
                    let index = ((y * sampleSize) + x) * 4
                    totalR += Int(data[index])
                    totalG += Int(data[index + 1])
                    totalB += Int(data[index + 2])
                    pixelCount += 1
                }
            }
        }
        
        guard pixelCount > 0 else { return UIColor.gray }
        
        return UIColor(
            red: CGFloat(totalR) / CGFloat(pixelCount) / 255.0,
            green: CGFloat(totalG) / CGFloat(pixelCount) / 255.0,
            blue: CGFloat(totalB) / CGFloat(pixelCount) / 255.0,
            alpha: 1.0
        )
    }
    
    // MARK: - Identify Coin Type
    private func identifyCoin(circle: DetectedCircle, in image: UIImage) -> CoinDetection? {
        // Get HSB values from average color
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        circle.averageColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        print("🎨 Circle color - H: \(hue), S: \(saturation), B: \(brightness)")
        print("📐 Circle properties - radius: \(circle.radius), circularity: \(circle.circularity)")
        
        // Score each coin type
        var bestMatch: (coin: ReferenceObject, score: Double)?
        
        for coinType in ReferenceObject.allCases {
            var score = 0.0
            
            // Check color match - be more lenient
            let colorChar = coinType.colorCharacteristics
            
            // For silver coins (low saturation), be very lenient
            if colorChar.saturationMin == 0 {
                // Silver coins - just check brightness
                if brightness >= 0.4 {  // Lowered threshold
                    score += 0.5
                }
            } else {
                // Colored coins (penny) - check hue
                if colorChar.hueRange.contains(Float(hue)) {
                    score += 0.3
                }
                if saturation >= CGFloat(colorChar.saturationMin) {
                    score += 0.2
                }
            }
            
            // Add circularity score (reduced weight)
            score += circle.circularity * 0.3
            
            // Add edge strength score
            score += min(circle.edgeStrength / 5.0, 1.0) * 0.2
            
            print("💰 \(coinType.displayName) score: \(score)")
            
            // Store best match
            if bestMatch == nil || score > bestMatch!.score {
                bestMatch = (coin: coinType, score: score)
            }
        }
        
        // Lower threshold for acceptance
        guard let match = bestMatch, match.score > 0.3 else {  // Lowered from 0.5
            print("❌ No coin matched minimum score threshold (best was \(bestMatch?.score ?? 0))")
            return nil
        }
        
        let boundingBox = CGRect(
            x: circle.center.x - circle.radius,
            y: circle.center.y - circle.radius,
            width: circle.radius * 2,
            height: circle.radius * 2
        )
        
        let detection = CoinDetection(
            coinType: match.coin,
            diameterPixels: circle.radius * 2,
            center: circle.center,
            confidence: min(match.score, 1.0),
            boundingBox: boundingBox
        )
        
        print("✅ Detected \(match.coin.displayName) with confidence \(match.score)")
        
        return detection
    }
}
