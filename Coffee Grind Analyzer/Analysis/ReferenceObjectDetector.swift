//
//  ReferenceObjectDetector.swift
//  Coffee Grind Analyzer
//
//  Detects reference objects (coins) in images using Vision framework
//

import UIKit
import Vision
import CoreImage
import OSLog

/// Detects and identifies reference objects (coins) for automatic calibration
class ReferenceObjectDetector {

    // MARK: - Properties

    private let database: ReferenceObjectDatabase
    private let logger = Logger(subsystem: "com.nateking.GrindLab", category: "ReferenceDetection")

    // Configuration constants
    private let minimumConfidence: Double = 0.75
    private let minimumCircularity: Double = 0.85
    private let coinSizeRange: ClosedRange<Double> = 80...300 // pixels (typical range for coins in photos)
    private let contrastAdjustment: Float = 1.0
    private let gaussianBlurRadius: Double = 2.0

    // MARK: - Initialization

    init(database: ReferenceObjectDatabase = ReferenceObjectDatabase.shared) {
        self.database = database
        logger.debug("ReferenceObjectDetector initialized")
    }

    // MARK: - Public API

    /// Detect coins in the provided image
    /// - Parameter image: The image to analyze
    /// - Returns: Array of detected coins, sorted by confidence (highest first)
    /// - Throws: Detection errors
    func detectCoins(in image: UIImage) async throws -> [DetectedCoin] {
        logger.info("🔍 Starting coin detection")
        let startTime = CFAbsoluteTimeGetCurrent()

        // Convert to CGImage
        guard let cgImage = image.cgImage else {
            logger.error("Failed to convert UIImage to CGImage")
            throw DetectionError.invalidImage
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        logger.debug("Image size: \(cgImage.width)x\(cgImage.height)")

        // Preprocess image
        let processedImage = try preprocessImage(cgImage)
        logger.debug("Image preprocessing complete")

        // Detect contours using Vision
        let contours = try await detectCircularContours(in: processedImage)
        logger.debug("Found \(contours.count) potential circular contours")

        // Analyze each contour for coin characteristics
        var detectedCoins: [DetectedCoin] = []

        for (index, contour) in contours.enumerated() {
            if let coin = analyzeContourForCoin(contour, imageSize: imageSize) {
                logger.debug("Contour \(index): Identified as \(coin.coinType.rawValue) with confidence \(String(format: "%.2f", coin.confidence))")
                detectedCoins.append(coin)
            }
        }

        // Filter by confidence and sort
        let validCoins = detectedCoins
            .filter { $0.confidence >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("✓ Detected \(validCoins.count) coin(s) in \(String(format: "%.3f", elapsed))s")

        return validCoins
    }

    /// Get the best (highest confidence) detected coin
    /// - Parameter coins: Array of detected coins
    /// - Returns: The coin with the highest confidence, or nil if array is empty
    func getBestCoin(from coins: [DetectedCoin]) -> DetectedCoin? {
        return coins.first // Already sorted by confidence
    }

    // MARK: - Image Preprocessing

    /// Preprocess image to enhance coin detection
    /// - Parameter cgImage: Input image
    /// - Returns: Processed CGImage
    /// - Throws: DetectionError if preprocessing fails
    private func preprocessImage(_ cgImage: CGImage) throws -> CGImage {
        let ciImage = CIImage(cgImage: cgImage)

        // Apply Gaussian blur to reduce noise while preserving edges
        let blurred = ciImage.applyingGaussianBlur(sigma: gaussianBlurRadius)

        // Enhance contrast and convert to grayscale
        let enhanced = blurred.applyingFilter("CIColorControls", parameters: [
            "inputSaturation": 0.0,          // Convert to grayscale
            "inputContrast": 1.2,            // Increase contrast
            "inputBrightness": 0.0           // Keep brightness neutral
        ])

        // Convert back to CGImage
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let outputImage = context.createCGImage(enhanced, from: enhanced.extent) else {
            logger.error("Failed to create CGImage from CIImage")
            throw DetectionError.preprocessingFailed
        }

        return outputImage
    }

    // MARK: - Contour Detection

    /// Detect circular contours in the image using Vision framework
    /// - Parameter cgImage: Preprocessed image
    /// - Returns: Array of contour observations that appear circular
    /// - Throws: Vision framework errors
    private func detectCircularContours(in cgImage: CGImage) async throws -> [VNContoursObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            // Create contour detection request
            let request = VNDetectContoursRequest { request, error in
                if let error = error {
                    self.logger.error("Vision request failed: \(error.localizedDescription)")
                    continuation.resume(throwing: DetectionError.visionRequestFailed)
                    return
                }

                guard let observations = request.results as? [VNContoursObservation] else {
                    self.logger.debug("No contours detected")
                    continuation.resume(returning: [])
                    return
                }

                self.logger.debug("Vision detected \(observations.count) total contours")

                // Filter for circular-looking contours
                let circularContours = observations.filter { observation in
                    let circularity = self.estimateCircularity(of: observation)
                    return circularity > self.minimumCircularity
                }

                self.logger.debug("Filtered to \(circularContours.count) circular contours")
                continuation.resume(returning: circularContours)
            }

            // Configure request for coin detection
            request.contrastAdjustment = self.contrastAdjustment
            request.detectsDarkOnLight = false // Coins are typically lighter/shinier than coffee

            // Perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                self.logger.error("Failed to perform Vision request: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Circularity Analysis

    /// Estimate how circular a contour is
    /// - Parameter observation: The contour observation
    /// - Returns: Circularity score (0.0 to 1.0, where 1.0 is a perfect circle)
    private func estimateCircularity(of observation: VNContoursObservation) -> Double {
        let contour = observation.normalizedPath

        // Get bounding box
        let bounds = contour.boundingBox
        let width = bounds.width
        let height = bounds.height

        // Avoid division by zero
        guard width > 0 && height > 0 else {
            return 0.0
        }

        // Perfect circle has aspect ratio of 1.0
        let aspectRatio = min(width, height) / max(width, height)

        // Calculate area and perimeter approximations
        let area = width * height
        // Approximate perimeter from bounding box
        let perimeter = 2.0 * (width + height)

        // Avoid division by zero
        guard perimeter > 0 else {
            return aspectRatio // Fall back to aspect ratio only
        }

        // Circularity formula: 4π × area / perimeter²
        // For perfect circle, this equals 1.0
        let pi: Double = .pi
        let circularityScore = (4.0 * pi * area) / (perimeter * perimeter)

        // Combined score (aspect ratio weighted heavily as it's more reliable)
        let combinedScore = (aspectRatio * 0.7) + (min(circularityScore, 1.0) * 0.3)

        return max(0.0, min(1.0, combinedScore))
    }

    // MARK: - Coin Analysis

    /// Analyze a contour to determine if it's a coin and identify the type
    /// - Parameters:
    ///   - contour: The contour observation
    ///   - imageSize: Size of the source image
    /// - Returns: DetectedCoin if valid, nil otherwise
    private func analyzeContourForCoin(_ contour: VNContoursObservation, imageSize: CGSize) -> DetectedCoin? {
        // Convert normalized coordinates to pixels
        let bounds = contour.normalizedPath.boundingBox

        // Vision uses normalized coordinates with origin at bottom-left
        // Convert to pixel coordinates with origin at top-left
        let centerX = bounds.midX * imageSize.width
        let centerY = (1.0 - bounds.midY) * imageSize.height
        let diameterPixels = max(bounds.width * imageSize.width, bounds.height * imageSize.height)

        // Check if size is in valid range for coins
        guard coinSizeRange.contains(diameterPixels) else {
            logger.debug("Rejected contour: diameter \(String(format: "%.1f", diameterPixels))px outside valid range (\(self.coinSizeRange))")
            return nil
        }

        // Identify coin type based on size
        guard let coinType = database.identifyByDiameter(diameterPixels, imageSize: imageSize) else {
            logger.debug("Rejected contour: diameter \(String(format: "%.1f", diameterPixels))px doesn't match any known coin")
            return nil
        }

        // Calculate confidence score
        let circularity = estimateCircularity(of: contour)
        let sizeMatchScore = calculateSizeMatchScore(
            diameter: diameterPixels,
            coinType: coinType,
            imageSize: imageSize
        )

        // Weighted confidence: circularity (40%) + size match (60%)
        let confidence = (circularity * 0.4) + (sizeMatchScore * 0.6)

        logger.debug("Coin candidate: \(coinType.rawValue), diameter: \(String(format: "%.1f", diameterPixels))px, circularity: \(String(format: "%.2f", circularity)), size match: \(String(format: "%.2f", sizeMatchScore)), confidence: \(String(format: "%.2f", confidence))")

        return DetectedCoin(
            coinType: coinType,
            diameterInPixels: diameterPixels,
            centerPoint: CGPoint(x: centerX, y: centerY),
            confidence: confidence,
            circularity: circularity
        )
    }

    /// Calculate how well the measured diameter matches the expected size for a coin type
    /// - Parameters:
    ///   - diameter: Measured diameter in pixels
    ///   - coinType: The identified coin type
    ///   - imageSize: Size of the source image
    /// - Returns: Match score (0.0 to 1.0)
    private func calculateSizeMatchScore(
        diameter: Double,
        coinType: CoinType,
        imageSize: CGSize
    ) -> Double {
        // Get expected size for this coin type
        let expectedDiameterMM = database.getDiameter(for: coinType)

        // Assume typical phone camera calibration (~150 μm/pixel)
        // This is a reasonable assumption for modern smartphone cameras at typical distances
        let assumedCalibration = 150.0 // μm/pixel
        let expectedDiameterPixels = (expectedDiameterMM * 1000.0) / assumedCalibration

        // Calculate relative difference
        let difference = abs(diameter - expectedDiameterPixels) / expectedDiameterPixels

        // Score based on difference percentage
        // Perfect match (0% diff): 1.0
        // 5% difference: 1.0
        // 10% difference: 0.75
        // 20% difference: 0.5
        // >30% difference: 0.0
        if difference <= 0.05 {
            return 1.0
        } else if difference <= 0.10 {
            return 1.0 - ((difference - 0.05) / 0.05) * 0.25 // Linear decrease to 0.75
        } else if difference <= 0.20 {
            return 0.75 - ((difference - 0.10) / 0.10) * 0.25 // Linear decrease to 0.5
        } else if difference <= 0.30 {
            return 0.5 - ((difference - 0.20) / 0.10) * 0.5 // Linear decrease to 0.0
        } else {
            return 0.0
        }
    }
}
