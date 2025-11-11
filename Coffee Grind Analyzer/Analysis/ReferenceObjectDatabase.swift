//
//  ReferenceObjectDatabase.swift
//  Coffee Grind Analyzer
//
//  Database of known reference objects for calibration
//

import Foundation
import CoreGraphics

// MARK: - Coin Specification

/// Specification for a coin type with physical dimensions
struct CoinSpecification {
    let type: CoinType
    let diameterMM: Double
    let diameterInches: Double
    let thicknessMM: Double
    let colorProfile: CoinColorProfile

    /// Diameter in microns
    var diameterMicrons: Double {
        return diameterMM * 1000.0
    }
}

// MARK: - Color Profile

/// Color profile for coin identification (future enhancement)
struct CoinColorProfile {
    let hueRange: ClosedRange<Double>
    let saturationRange: ClosedRange<Double>
    let lightnessRange: ClosedRange<Double>
}

// MARK: - Reference Object Database

/// Database of known reference objects with their specifications
class ReferenceObjectDatabase {

    // MARK: - Singleton

    static let shared = ReferenceObjectDatabase()

    private init() {
        // Private initialization for singleton
    }

    // MARK: - Coin Database

    /// All supported US coins with their official specifications
    private let coins: [CoinType: CoinSpecification] = [
        .penny: CoinSpecification(
            type: .penny,
            diameterMM: 19.05,
            diameterInches: 0.750,
            thicknessMM: 1.52,
            colorProfile: CoinColorProfile(
                hueRange: 15...30,      // Copper/bronze hue
                saturationRange: 0.4...0.8,
                lightnessRange: 0.3...0.6
            )
        ),
        .nickel: CoinSpecification(
            type: .nickel,
            diameterMM: 21.21,
            diameterInches: 0.835,
            thicknessMM: 1.95,
            colorProfile: CoinColorProfile(
                hueRange: 0...360,      // Silver/gray (desaturated)
                saturationRange: 0.0...0.2,
                lightnessRange: 0.5...0.8
            )
        ),
        .dime: CoinSpecification(
            type: .dime,
            diameterMM: 17.91,
            diameterInches: 0.705,
            thicknessMM: 1.35,
            colorProfile: CoinColorProfile(
                hueRange: 0...360,      // Silver/gray
                saturationRange: 0.0...0.2,
                lightnessRange: 0.5...0.8
            )
        ),
        .quarter: CoinSpecification(
            type: .quarter,
            diameterMM: 24.26,
            diameterInches: 0.955,
            thicknessMM: 1.75,
            colorProfile: CoinColorProfile(
                hueRange: 0...360,      // Silver/gray
                saturationRange: 0.0...0.2,
                lightnessRange: 0.5...0.8
            )
        )
    ]

    // MARK: - Public API

    /// Get coin specification by type
    /// - Parameter coinType: The type of coin
    /// - Returns: Specification for the coin, or nil if not found
    func getSpecification(for coinType: CoinType) -> CoinSpecification? {
        return coins[coinType]
    }

    /// Get diameter in millimeters
    /// - Parameter coinType: The type of coin
    /// - Returns: Diameter in millimeters
    func getDiameter(for coinType: CoinType) -> Double {
        return coins[coinType]?.diameterMM ?? 0.0
    }

    /// Get diameter in microns
    /// - Parameter coinType: The type of coin
    /// - Returns: Diameter in microns
    func getDiameterMicrons(for coinType: CoinType) -> Double {
        return coins[coinType]?.diameterMicrons ?? 0.0
    }

    /// Identify coin type by measured diameter in pixels
    /// Uses an assumed calibration factor to match pixel measurements to known coin sizes
    /// - Parameters:
    ///   - pixelDiameter: Measured diameter in pixels
    ///   - imageSize: Size of the image for context
    ///   - assumedCalibration: Assumed calibration factor in μm/pixel (default: 150)
    ///   - tolerance: Tolerance percentage for matching (default: 0.20 = 20%)
    /// - Returns: Most likely coin type, or nil if no match
    func identifyByDiameter(
        _ pixelDiameter: Double,
        imageSize: CGSize,
        assumedCalibration: Double = 150.0,
        tolerance: Double = 0.20
    ) -> CoinType? {
        // Calculate expected pixel diameter for each coin type
        var matches: [(coin: CoinType, difference: Double)] = []

        for (coinType, spec) in coins {
            let expectedPixels = spec.diameterMicrons / assumedCalibration
            let difference = abs(pixelDiameter - expectedPixels) / expectedPixels

            if difference <= tolerance {
                matches.append((coin: coinType, difference: difference))
            }
        }

        // Return closest match
        return matches.min(by: { $0.difference < $1.difference })?.coin
    }

    /// Identify coins by relative sizes (when multiple coins present)
    /// More accurate than absolute size matching as it doesn't depend on calibration
    /// - Parameter detectedSizes: Array of detected circle diameters in pixels
    /// - Returns: Dictionary mapping pixel diameter to coin type
    func identifyByRelativeSizes(_ detectedSizes: [Double]) -> [Double: CoinType] {
        guard detectedSizes.count >= 2 else {
            // Need at least 2 coins for relative sizing
            return [:]
        }

        // Sort sizes largest to smallest
        let sortedSizes = detectedSizes.sorted(by: >)

        // Try to identify using relative ratios
        var results: [Double: CoinType] = [:]

        // Simple heuristic: assume largest is quarter (most commonly used)
        // and identify others based on their ratio to the largest
        if let largest = sortedSizes.first {
            results[largest] = .quarter

            // Identify others based on ratio to quarter
            for size in sortedSizes.dropFirst() {
                let ratio = size / largest
                if let coinType = identifyCoinByRatioToQuarter(ratio) {
                    results[size] = coinType
                }
            }
        }

        return results
    }

    /// Get all coin types sorted by size (smallest to largest)
    var coinTypesBySize: [CoinType] {
        return CoinType.allCases.sorted { coinType1, coinType2 in
            getDiameter(for: coinType1) < getDiameter(for: coinType2)
        }
    }

    /// Get size ratios between all coin pairs
    /// Useful for relative size identification
    func getCoinRatios() -> [CoinType: [CoinType: Double]] {
        var ratios: [CoinType: [CoinType: Double]] = [:]

        for coinType in CoinType.allCases {
            ratios[coinType] = [:]
            let diameter = getDiameter(for: coinType)

            for otherCoin in CoinType.allCases {
                let otherDiameter = getDiameter(for: otherCoin)
                ratios[coinType]?[otherCoin] = diameter / otherDiameter
            }
        }

        return ratios
    }

    // MARK: - Private Helper Methods

    /// Identify a coin by its size ratio compared to a quarter
    /// - Parameter ratio: Size ratio (detected coin diameter / quarter diameter)
    /// - Returns: Most likely coin type
    private func identifyCoinByRatioToQuarter(_ ratio: Double) -> CoinType? {
        let quarterDiameter = getDiameter(for: .quarter)

        // Calculate expected ratios for each coin type
        let expectedRatios: [(type: CoinType, ratio: Double)] = [
            (.dime, getDiameter(for: .dime) / quarterDiameter),      // ~0.74
            (.penny, getDiameter(for: .penny) / quarterDiameter),     // ~0.79
            (.nickel, getDiameter(for: .nickel) / quarterDiameter)    // ~0.87
        ]

        // Find closest match with 5% tolerance
        let tolerance = 0.05
        let matches = expectedRatios.filter { abs($0.ratio - ratio) / $0.ratio <= tolerance }

        return matches.min(by: { abs($0.ratio - ratio) < abs($1.ratio - ratio) })?.type
    }
}
