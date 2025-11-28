//
//  CoinCalibrationDetector.swift
//  Coffee Grind Analyzer
//
//  Created by Claude Code on 1/28/25.
//  US Quarter detection and automatic calibration
//

import UIKit
import CoreGraphics
import OSLog

private let coinDetectionLogger = Logger(subsystem: "com.nateking.GrindLab", category: "CoinDetection")

// MARK: - Calibration Result Model

struct CalibrationResult {
    let success: Bool
    let detectedCircle: DetectedCircle?
    let calibrationFactor: Double  // μm/pixel
    let confidence: Double         // 0-1 scale
    let errorMessage: String?

    struct DetectedCircle {
        let center: CGPoint           // In image coordinates
        let radiusPixels: Double      // Sub-pixel accuracy
        let diameterMM: Double        // Should be ~24.26mm
        let inBottomLeft: Bool        // Validation flag
    }
}

// MARK: - Coin Detection Error

enum CoinDetectionError: Error, LocalizedError {
    case noCoinDetected
    case multipleCoinsDetected
    case coinNotInBottomLeft
    case coinTooSmallOrLarge
    case imageProcessingFailed

    var errorDescription: String? {
        switch self {
        case .noCoinDetected:
            return "No quarter detected in bottom-left corner. Please ensure a US Quarter is clearly visible."
        case .multipleCoinsDetected:
            return "Multiple coins detected. Please use only one quarter in the bottom-left corner."
        case .coinNotInBottomLeft:
            return "Quarter must be placed in the bottom-left corner of the image."
        case .coinTooSmallOrLarge:
            return "Detected circle size is unreasonable. Ensure proper lighting and focus."
        case .imageProcessingFailed:
            return "Failed to process image for coin detection."
        }
    }
}

// MARK: - Main Detector Class

class CoinCalibrationDetector {
    private let openCVWrapper = OpenCVWrapper()

    // US Quarter specifications
    private let quarterDiameterMM: Double = 24.26
    private let quarterDiameterMicrons: Double = 24260.0

    // Detection parameters
    private let expectedPixelDiameterRange: ClosedRange<Double> = 300...2000
    private let calibrationFactorRange: ClosedRange<Double> = 5...300  // μm/pixel

    // OpenCV parameters for circle detection
    private let cannyHighThreshold: Double = 100
    private let houghAccumulatorThreshold: Double = 30

    /// Main detection function - detects quarter in bottom-left and calculates calibration
    func detectQuarterAndCalibrate(in image: UIImage) -> CalibrationResult {
        coinDetectionLogger.debug("🪙 Starting quarter detection for calibration")

        guard let cgImage = image.cgImage else {
            return CalibrationResult(
                success: false,
                detectedCircle: nil,
                calibrationFactor: 0,
                confidence: 0,
                errorMessage: CoinDetectionError.imageProcessingFailed.localizedDescription
            )
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        coinDetectionLogger.debug("📐 Image size: \(Int(imageSize.width))x\(Int(imageSize.height))")

        // Step 1: Estimate expected quarter size based on image resolution
        let estimatedMinRadius = Int(expectedPixelDiameterRange.lowerBound / 2)
        let estimatedMaxRadius = Int(expectedPixelDiameterRange.upperBound / 2)

        coinDetectionLogger.debug("🔍 Searching for circles with radius: \(estimatedMinRadius)-\(estimatedMaxRadius)px")

        // Step 2: Detect circles using OpenCV
        let detectedCircles = openCVWrapper.detectCircles(
            in: image,
            cannyThreshold1: cannyHighThreshold,
            cannyThreshold2: houghAccumulatorThreshold,
            minRadius: Int32(estimatedMinRadius),
            maxRadius: Int32(estimatedMaxRadius)
        )

        coinDetectionLogger.debug("✅ Detected \(detectedCircles.count) circles total")

        // Step 3: Filter circles to bottom-left quadrant
        let bottomLeftCircles = detectedCircles.filter { circle in
            isInBottomLeftQuadrant(
                center: CGPoint(x: circle.centerX, y: circle.centerY),
                imageSize: imageSize
            )
        }

        coinDetectionLogger.debug("📍 Found \(bottomLeftCircles.count) circles in bottom-left quadrant")

        guard !bottomLeftCircles.isEmpty else {
            return CalibrationResult(
                success: false,
                detectedCircle: nil,
                calibrationFactor: 0,
                confidence: 0,
                errorMessage: CoinDetectionError.noCoinDetected.localizedDescription
            )
        }

        guard bottomLeftCircles.count == 1 else {
            return CalibrationResult(
                success: false,
                detectedCircle: nil,
                calibrationFactor: 0,
                confidence: 0,
                errorMessage: CoinDetectionError.multipleCoinsDetected.localizedDescription
            )
        }

        // Step 4: Validate and calculate calibration
        let circle = bottomLeftCircles[0]
        let radiusPixels = Double(circle.radius)
        let diameterPixels = radiusPixels * 2.0

        coinDetectionLogger.debug("📏 Detected circle: radius=\(String(format: "%.2f", radiusPixels))px, diameter=\(String(format: "%.2f", diameterPixels))px")

        // Validate diameter is reasonable
        guard expectedPixelDiameterRange.contains(diameterPixels) else {
            coinDetectionLogger.warning("⚠️ Diameter \(String(format: "%.2f", diameterPixels))px outside expected range")
            return CalibrationResult(
                success: false,
                detectedCircle: nil,
                calibrationFactor: 0,
                confidence: 0,
                errorMessage: CoinDetectionError.coinTooSmallOrLarge.localizedDescription
            )
        }

        // Calculate calibration factor
        let calibrationFactor = quarterDiameterMicrons / diameterPixels

        coinDetectionLogger.debug("🎯 Calculated calibration: \(String(format: "%.2f", calibrationFactor)) μm/pixel")

        // Validate calibration factor is reasonable
        guard calibrationFactorRange.contains(calibrationFactor) else {
            let errorMsg = "Calculated calibration factor (\(String(format: "%.2f", calibrationFactor)) μm/pixel) is outside expected range."
            coinDetectionLogger.warning("⚠️ \(errorMsg)")
            return CalibrationResult(
                success: false,
                detectedCircle: nil,
                calibrationFactor: 0,
                confidence: 0,
                errorMessage: errorMsg
            )
        }

        // Create successful result
        let detectedCircle = CalibrationResult.DetectedCircle(
            center: CGPoint(x: circle.centerX, y: circle.centerY),
            radiusPixels: radiusPixels,
            diameterMM: quarterDiameterMM,
            inBottomLeft: true
        )

        coinDetectionLogger.info("✅ Quarter detected successfully: radius=\(String(format: "%.2f", radiusPixels))px, calibration=\(String(format: "%.2f", calibrationFactor))μm/pixel")

        return CalibrationResult(
            success: true,
            detectedCircle: detectedCircle,
            calibrationFactor: calibrationFactor,
            confidence: Double(circle.confidence),
            errorMessage: nil
        )
    }

    // MARK: - Helper Functions

    /// Check if a point is in the bottom-left quadrant of the image
    private func isInBottomLeftQuadrant(center: CGPoint, imageSize: CGSize) -> Bool {
        let quarterWidth = imageSize.width / 2
        let quarterHeight = imageSize.height / 2

        let inBottomLeft = center.x < quarterWidth && center.y > quarterHeight

        if inBottomLeft {
            coinDetectionLogger.debug("✓ Circle at (\(Int(center.x)), \(Int(center.y))) is in bottom-left quadrant")
        }

        return inBottomLeft
    }
}
