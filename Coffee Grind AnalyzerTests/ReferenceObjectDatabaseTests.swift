//
//  ReferenceObjectDatabaseTests.swift
//  Coffee Grind AnalyzerTests
//
//  Tests for reference object database (coin specifications)
//

import Testing
import CoreGraphics
@testable import GrindLab

@MainActor
struct ReferenceObjectDatabaseTests {

    let database = ReferenceObjectDatabase.shared

    // MARK: - Coin Specifications Tests

    @Test func testPennySpecification() {
        let spec = database.getSpecification(for: .penny)

        #expect(spec != nil)
        #expect(spec?.diameterMM == 19.05)
        #expect(spec?.diameterInches == 0.750)
        #expect(spec?.diameterMicrons == 19050.0)
        #expect(spec?.type == .penny)
    }

    @Test func testNickelSpecification() {
        let spec = database.getSpecification(for: .nickel)

        #expect(spec != nil)
        #expect(spec?.diameterMM == 21.21)
        #expect(spec?.diameterInches == 0.835)
        #expect(spec?.diameterMicrons == 21210.0)
        #expect(spec?.type == .nickel)
    }

    @Test func testDimeSpecification() {
        let spec = database.getSpecification(for: .dime)

        #expect(spec != nil)
        #expect(spec?.diameterMM == 17.91)
        #expect(spec?.diameterInches == 0.705)
        #expect(spec?.diameterMicrons == 17910.0)
        #expect(spec?.type == .dime)
    }

    @Test func testQuarterSpecification() {
        let spec = database.getSpecification(for: .quarter)

        #expect(spec != nil)
        #expect(spec?.diameterMM == 24.26)
        #expect(spec?.diameterInches == 0.955)
        #expect(spec?.diameterMicrons == 24260.0)
        #expect(spec?.type == .quarter)
    }

    // MARK: - Diameter Lookup Tests

    @Test func testGetDiameterForAllCoins() {
        #expect(database.getDiameter(for: .dime) == 17.91)
        #expect(database.getDiameter(for: .penny) == 19.05)
        #expect(database.getDiameter(for: .nickel) == 21.21)
        #expect(database.getDiameter(for: .quarter) == 24.26)
    }

    @Test func testGetDiameterMicronsForAllCoins() {
        #expect(database.getDiameterMicrons(for: .dime) == 17910.0)
        #expect(database.getDiameterMicrons(for: .penny) == 19050.0)
        #expect(database.getDiameterMicrons(for: .nickel) == 21210.0)
        #expect(database.getDiameterMicrons(for: .quarter) == 24260.0)
    }

    @Test func testCoinsSortedBySize() {
        let sorted = database.coinTypesBySize

        #expect(sorted.count == 4)
        #expect(sorted[0] == .dime)     // Smallest
        #expect(sorted[1] == .penny)
        #expect(sorted[2] == .nickel)
        #expect(sorted[3] == .quarter)  // Largest
    }

    // MARK: - Size-Based Identification Tests

    @Test func testIdentifyQuarterByPixelSize_Typical150Calibration() {
        // At 150 μm/pixel calibration, quarter is ~162 pixels
        let quarterPixels = 24260.0 / 150.0 // = 161.73 pixels
        let imageSize = CGSize(width: 1000, height: 1000)

        let identified = database.identifyByDiameter(quarterPixels, imageSize: imageSize)

        #expect(identified == .quarter)
    }

    @Test func testIdentifyPennyByPixelSize_Typical150Calibration() {
        // At 150 μm/pixel calibration, penny is ~127 pixels
        let pennyPixels = 19050.0 / 150.0 // = 127.0 pixels
        let imageSize = CGSize(width: 1000, height: 1000)

        let identified = database.identifyByDiameter(pennyPixels, imageSize: imageSize)

        #expect(identified == .penny)
    }

    @Test func testIdentifyNickelByPixelSize_Typical150Calibration() {
        // At 150 μm/pixel calibration, nickel is ~141 pixels
        let nickelPixels = 21210.0 / 150.0 // = 141.4 pixels
        let imageSize = CGSize(width: 1000, height: 1000)

        let identified = database.identifyByDiameter(nickelPixels, imageSize: imageSize)

        #expect(identified == .nickel)
    }

    @Test func testIdentifyDimeByPixelSize_Typical150Calibration() {
        // At 150 μm/pixel calibration, dime is ~119 pixels
        let dimePixels = 17910.0 / 150.0 // = 119.4 pixels
        let imageSize = CGSize(width: 1000, height: 1000)

        let identified = database.identifyByDiameter(dimePixels, imageSize: imageSize)

        #expect(identified == .dime)
    }

    @Test func testIdentification_WithinTolerance_Succeeds() {
        // Test with 10% deviation (within 20% default tolerance)
        let quarterPixelsWithDeviation = (24260.0 / 150.0) * 1.10 // +10%
        let imageSize = CGSize(width: 1000, height: 1000)

        let identified = database.identifyByDiameter(quarterPixelsWithDeviation, imageSize: imageSize)

        #expect(identified == .quarter)
    }

    @Test func testIdentification_OutsideTolerance_Fails() {
        // Test with 25% deviation (outside 20% default tolerance)
        let invalidSize = (24260.0 / 150.0) * 1.25 // +25%
        let imageSize = CGSize(width: 1000, height: 1000)

        let identified = database.identifyByDiameter(invalidSize, imageSize: imageSize)

        #expect(identified == nil)
    }

    @Test func testIdentification_CustomTolerance_Works() {
        // Test with custom 30% tolerance
        let sizeWith25PercentDeviation = (24260.0 / 150.0) * 1.25
        let imageSize = CGSize(width: 1000, height: 1000)

        let identified = database.identifyByDiameter(
            sizeWith25PercentDeviation,
            imageSize: imageSize,
            tolerance: 0.30  // 30% tolerance
        )

        #expect(identified == .quarter)
    }

    @Test func testIdentification_VerySmallSize_NoMatch() {
        let tooSmall = 50.0 // pixels
        let imageSize = CGSize(width: 1000, height: 1000)

        let identified = database.identifyByDiameter(tooSmall, imageSize: imageSize)

        #expect(identified == nil)
    }

    @Test func testIdentification_VeryLargeSize_NoMatch() {
        let tooLarge = 500.0 // pixels
        let imageSize = CGSize(width: 1000, height: 1000)

        let identified = database.identifyByDiameter(tooLarge, imageSize: imageSize)

        #expect(identified == nil)
    }

    // MARK: - Relative Size Identification Tests

    @Test func testRelativeSizeIdentification_TwoCoins() {
        // Quarter and penny at 150 μm/pixel calibration
        let quarterPixels = 24260.0 / 150.0  // ~162 pixels
        let pennyPixels = 19050.0 / 150.0     // ~127 pixels

        let detectedSizes = [quarterPixels, pennyPixels]
        let identified = database.identifyByRelativeSizes(detectedSizes)

        #expect(identified.count == 2)
        #expect(identified[quarterPixels] == .quarter)
        #expect(identified[pennyPixels] == .penny)
    }

    @Test func testRelativeSizeIdentification_ThreeCoins() {
        // Quarter, nickel, and dime
        let quarterPixels = 24260.0 / 150.0   // ~162 pixels
        let nickelPixels = 21210.0 / 150.0    // ~141 pixels
        let dimePixels = 17910.0 / 150.0      // ~119 pixels

        let detectedSizes = [quarterPixels, nickelPixels, dimePixels]
        let identified = database.identifyByRelativeSizes(detectedSizes)

        #expect(identified.count == 3)
        #expect(identified[quarterPixels] == .quarter)
        // Nickel and dime should also be identified
        #expect(identified[nickelPixels] != nil)
        #expect(identified[dimePixels] != nil)
    }

    @Test func testRelativeSizeIdentification_SingleCoin_ReturnsEmpty() {
        // Need at least 2 coins for relative sizing
        let singleCoin = [162.0]
        let identified = database.identifyByRelativeSizes(singleCoin)

        #expect(identified.isEmpty)
    }

    // MARK: - Coin Ratios Tests

    @Test func testCoinRatios_QuarterToPenny() {
        let ratios = database.getCoinRatios()

        let quarterToPenny = ratios[.quarter]?[.penny]
        #expect(quarterToPenny != nil)

        // Quarter (24.26mm) / Penny (19.05mm) ≈ 1.27
        let expectedRatio = 24.26 / 19.05
        #expect(abs(quarterToPenny! - expectedRatio) < 0.01)
    }

    @Test func testCoinRatios_DimeToQuarter() {
        let ratios = database.getCoinRatios()

        let dimeToQuarter = ratios[.dime]?[.quarter]
        #expect(dimeToQuarter != nil)

        // Dime (17.91mm) / Quarter (24.26mm) ≈ 0.74
        let expectedRatio = 17.91 / 24.26
        #expect(abs(dimeToQuarter! - expectedRatio) < 0.01)
    }

    @Test func testCoinRatios_SelfRatio_IsOne() {
        let ratios = database.getCoinRatios()

        #expect(ratios[.penny]?[.penny] == 1.0)
        #expect(ratios[.nickel]?[.nickel] == 1.0)
        #expect(ratios[.dime]?[.dime] == 1.0)
        #expect(ratios[.quarter]?[.quarter] == 1.0)
    }

    @Test func testCoinRatios_AllCoinsHaveAllRatios() {
        let ratios = database.getCoinRatios()

        // Each coin should have ratios to all other coins
        for coinType in CoinType.allCases {
            #expect(ratios[coinType] != nil)
            #expect(ratios[coinType]?.count == 4)

            for otherCoin in CoinType.allCases {
                #expect(ratios[coinType]?[otherCoin] != nil)
            }
        }
    }

    // MARK: - Edge Cases and Validation

    @Test func testAllCoinsHavePositiveDimensions() {
        for coinType in CoinType.allCases {
            let diameter = database.getDiameter(for: coinType)
            #expect(diameter > 0)

            let diameterMicrons = database.getDiameterMicrons(for: coinType)
            #expect(diameterMicrons > 0)
            #expect(diameterMicrons == diameter * 1000.0)
        }
    }

    @Test func testCoinType_AllCasesIncluded() {
        // Verify all coin types are in the database
        for coinType in CoinType.allCases {
            let spec = database.getSpecification(for: coinType)
            #expect(spec != nil, "Missing specification for \(coinType.rawValue)")
        }
    }

    @Test func testDifferentCalibrations_ProduceCorrectIdentification() {
        let imageSize = CGSize(width: 1000, height: 1000)

        // Test with different assumed calibrations
        let calibrations = [100.0, 150.0, 200.0] // μm/pixel

        for calibration in calibrations {
            let quarterPixels = 24260.0 / calibration
            let identified = database.identifyByDiameter(
                quarterPixels,
                imageSize: imageSize,
                assumedCalibration: calibration
            )

            #expect(identified == .quarter, "Failed to identify quarter at \(calibration) μm/pixel calibration")
        }
    }
}
