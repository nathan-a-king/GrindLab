//
//  CoinDetectionResult.swift
//  Coffee Grind Analyzer
//
//  Models for coin detection and automatic calibration
//

import Foundation
import CoreGraphics

// MARK: - Coin Type

/// Types of coins supported for reference calibration
enum CoinType: String, Codable, CaseIterable {
    case penny = "Penny"
    case nickel = "Nickel"
    case dime = "Dime"
    case quarter = "Quarter"

    var displayName: String {
        return rawValue
    }

    var symbol: String {
        switch self {
        case .penny: return "¢1"
        case .nickel: return "¢5"
        case .dime: return "¢10"
        case .quarter: return "¢25"
        }
    }
}

// MARK: - Detected Coin

/// Result of coin detection in an image
struct DetectedCoin: Codable {
    /// Type of coin identified
    let coinType: CoinType

    /// Measured diameter in pixels
    let diameterInPixels: Double

    /// Center point of the coin in image coordinates
    let centerPoint: CGPoint

    /// Detection confidence (0.0 to 1.0)
    let confidence: Double

    /// Circularity score (0.0 to 1.0, 1.0 = perfect circle)
    let circularity: Double

    /// Calculated calibration factor from this coin
    var calibrationFactor: Double {
        let knownDiameterMicrons = ReferenceObjectDatabase.shared.getDiameterMicrons(for: coinType)
        return knownDiameterMicrons / diameterInPixels
    }

    /// Bounding rectangle for visualization
    var boundingRect: CGRect {
        let radius = diameterInPixels / 2
        return CGRect(
            x: centerPoint.x - radius,
            y: centerPoint.y - radius,
            width: diameterInPixels,
            height: diameterInPixels
        )
    }

    /// Human-readable description of the detection
    var description: String {
        return "\(coinType.displayName) (confidence: \(String(format: "%.0f%%", confidence * 100)))"
    }

    /// Quality rating based on confidence
    var qualityRating: QualityRating {
        switch confidence {
        case 0.9...1.0:
            return .excellent
        case 0.8..<0.9:
            return .good
        case 0.75..<0.8:
            return .acceptable
        default:
            return .poor
        }
    }

    enum QualityRating {
        case excellent
        case good
        case acceptable
        case poor

        var displayName: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .acceptable: return "Acceptable"
            case .poor: return "Poor"
            }
        }

        var colorName: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .acceptable: return "yellow"
            case .poor: return "red"
            }
        }
    }
}

// MARK: - Calibration Method

/// Method used for calibration
enum CalibrationMethod: String, Codable {
    case manual = "Manual"
    case automatic = "Automatic"
    case automaticWithWarning = "Automatic (Low Confidence)"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .manual:
            return "ruler"
        case .automatic:
            return "camera.metering.matrix"
        case .automaticWithWarning:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Reference Object Info

/// Information about detected reference object used for calibration
struct ReferenceObjectInfo: Codable {
    /// Type of reference used
    let referenceType: ReferenceType

    /// Detected coin (if type is coin)
    let detectedCoin: DetectedCoin?

    /// Calibration factor calculated from reference
    let calculatedCalibration: Double

    /// Confidence in the detection (0.0 to 1.0)
    let confidence: Double

    enum ReferenceType: String, Codable {
        case coin = "Coin"
        case creditCard = "Credit Card"
        case airtag = "AirTag"
        case calibrationPattern = "Calibration Pattern"
    }
}

// MARK: - Detection Error

/// Errors that can occur during reference object detection
enum DetectionError: LocalizedError {
    case invalidImage
    case preprocessingFailed
    case visionRequestFailed
    case noCoinsDetected
    case lowConfidence

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image is invalid or cannot be processed"
        case .preprocessingFailed:
            return "Failed to preprocess image for detection"
        case .visionRequestFailed:
            return "Vision framework request failed"
        case .noCoinsDetected:
            return "No coins detected in the image"
        case .lowConfidence:
            return "Coin detection confidence is too low"
        }
    }
}
