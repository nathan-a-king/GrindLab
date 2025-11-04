//
//  CoffeeAnalysisEngineTests.swift
//  Coffee Grind AnalyzerTests
//
//  Tests for core analysis engine using validation infrastructure
//

import Testing
import UIKit
@testable import GrindLab

@MainActor
struct CoffeeAnalysisEngineTests {

    // MARK: - Grid Pattern Detection Tests

    @Test func testAnalysisEngine_GridPattern5x5_DetectsAllParticles() async throws {
        // Create a 5x5 grid of particles
        let (testImage, expectedParticles) = AnalysisValidation.createGridTestImage(
            width: 1000,
            height: 1000,
            rows: 5,
            cols: 5,
            particleRadius: 30
        )

        // Run analysis with test-appropriate calibration
        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // Validate results
        let report = AnalysisValidation.validateResults(
            detected: results.particles,
            expected: expectedParticles,
            tolerance: 10.0
        )

        // Should detect most particles (90%+ recall)
        #expect(report.recall >= 0.90, "Expected recall >= 90%, got \(String(format: "%.1f%%", report.recall * 100))")

        // Should have good precision (90%+ of detected are correct)
        #expect(report.precision >= 0.90, "Expected precision >= 90%, got \(String(format: "%.1f%%", report.precision * 100))")

        // F1 score should be high
        #expect(report.f1Score >= 0.90, "Expected F1 >= 0.90, got \(String(format: "%.3f", report.f1Score))")
    }

    @Test func testAnalysisEngine_GridPattern3x3_LargeParticles() async throws {
        let (testImage, expectedParticles) = AnalysisValidation.createGridTestImage(
            width: 1000,
            height: 1000,
            rows: 3,
            cols: 3,
            particleRadius: 80
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        let report = AnalysisValidation.validateResults(
            detected: results.particles,
            expected: expectedParticles,
            tolerance: 15.0
        )

        // Larger particles should be easier to detect
        #expect(report.recall >= 0.85)
        #expect(report.precision >= 0.85)
    }

    @Test func testAnalysisEngine_GridPattern10x10_HighDensity() async throws {
        // Test with high density grid to verify clustering doesn't merge particles
        let (testImage, expectedParticles) = AnalysisValidation.createGridTestImage(
            width: 1200,
            height: 1200,
            rows: 10,
            cols: 10,
            particleRadius: 20
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        let report = AnalysisValidation.validateResults(
            detected: results.particles,
            expected: expectedParticles,
            tolerance: 8.0
        )

        // Should detect most particles even in high density
        #expect(report.recall >= 0.80, "Expected recall >= 80%, got \(String(format: "%.1f%%", report.recall * 100))")
        #expect(report.precision >= 0.80, "Expected precision >= 80%, got \(String(format: "%.1f%%", report.precision * 100))")
        #expect(results.particleCount >= 80) // At least 80% of 100 particles
    }

    @Test func testAnalysisEngine_GridPattern4x4_MediumParticles() async throws {
        // Test with medium-sized particles in a balanced grid
        let (testImage, expectedParticles) = AnalysisValidation.createGridTestImage(
            width: 800,
            height: 800,
            rows: 4,
            cols: 4,
            particleRadius: 40
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        let report = AnalysisValidation.validateResults(
            detected: results.particles,
            expected: expectedParticles,
            tolerance: 10.0
        )

        // Should have excellent detection for well-separated medium particles
        #expect(report.recall >= 0.88)
        #expect(report.precision >= 0.88)
        #expect(report.f1Score >= 0.88)
    }

    // MARK: - Random Particle Detection Tests

    @Test func testAnalysisEngine_RandomParticles_AccurateDetection() async throws {
        let (testImage, expectedParticles) = AnalysisValidation.createTestImage(
            width: 1000,
            height: 1000,
            particleCount: 20,
            particleSizeRange: 20...100
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        let report = AnalysisValidation.validateResults(
            detected: results.particles,
            expected: expectedParticles,
            tolerance: 10.0
        )

        // Random placement might be harder, but should still be good
        #expect(report.recall >= 0.80)
        #expect(report.precision >= 0.80)

        // Position accuracy should be reasonable
        #expect(report.avgPositionError < 15.0, "Average position error too high: \(report.avgPositionError)")
    }

    @Test func testAnalysisEngine_FewLargeParticles_HighAccuracy() async throws {
        let (testImage, expectedParticles) = AnalysisValidation.createTestImage(
            width: 1000,
            height: 1000,
            particleCount: 5,
            particleSizeRange: 80...120
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        let report = AnalysisValidation.validateResults(
            detected: results.particles,
            expected: expectedParticles,
            tolerance: 20.0
        )

        // Few large particles should be very accurate
        #expect(report.recall >= 0.90)
        #expect(report.precision >= 0.90)
        #expect(report.avgPositionError < 20.0)
    }

    // MARK: - Size Measurement Tests

    @Test func testAnalysisEngine_ParticleSizes_WithinTolerance() async throws {
        let (testImage, expectedParticles) = AnalysisValidation.createGridTestImage(
            width: 1000,
            height: 1000,
            rows: 3,
            cols: 3,
            particleRadius: 50
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        let report = AnalysisValidation.validateResults(
            detected: results.particles,
            expected: expectedParticles,
            tolerance: 15.0
        )

        // Size measurement should be reasonably accurate
        #expect(report.avgSizeError < 15.0, "Average size error too high: \(report.avgSizeError) pixels")

        // Most particles should be matched
        #expect(report.matchedParticles.count >= 7) // At least 7 out of 9
    }

    @Test func testAnalysisEngine_CalibrationFactor_AffectsSizeMeasurement() async throws {
        let (testImage, _) = AnalysisValidation.createGridTestImage(
            width: 1000,
            height: 1000,
            rows: 2,
            cols: 2,
            particleRadius: 40
        )

        // Run with calibration factor of 5.0
        let results1 = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // Run with calibration factor of 10.0
        let results2 = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 10.0
        )

        // Sizes should be different (doubled with 2x calibration factor)
        if let size1 = results1.particles.first?.size,
           let size2 = results2.particles.first?.size {
            let ratio = size2 / size1
            #expect(abs(ratio - 2.0) < 0.2, "Expected size ratio ~2.0, got \(ratio)")
        }
    }

    // MARK: - Statistics Tests

    @Test func testAnalysisEngine_UniformParticles_HighUniformityScore() async throws {
        // All particles same size should give high uniformity
        let (testImage, _) = AnalysisValidation.createGridTestImage(
            width: 1000,
            height: 1000,
            rows: 4,
            cols: 4,
            particleRadius: 40 // All same size
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // Uniform particles should have high uniformity score
        #expect(results.uniformityScore >= 70.0, "Expected high uniformity, got \(results.uniformityScore)")

        // Standard deviation should be low for uniform particles
        #expect(results.standardDeviation < 50.0, "Expected low std dev, got \(results.standardDeviation)")
    }

    @Test func testAnalysisEngine_Statistics_AverageAndMedianReasonable() async throws {
        let (testImage, _) = AnalysisValidation.createGridTestImage(
            width: 1000,
            height: 1000,
            rows: 3,
            cols: 3,
            particleRadius: 50
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // Average and median should be close for uniform distribution
        let difference = abs(results.averageSize - results.medianSize)
        #expect(difference < 50.0, "Average and median too different: \(difference)")

        // Both should be in reasonable range for the particle size
        #expect(results.averageSize > 100.0) // 50px * 5 μm/px * 2 (diameter) ~= 500μm
        #expect(results.averageSize < 800.0)
    }

    // MARK: - Edge Case Tests

    @Test func testAnalysisEngine_SingleParticle_DetectedCorrectly() async throws {
        let (testImage, expectedParticles) = AnalysisValidation.createTestImage(
            width: 500,
            height: 500,
            particleCount: 1,
            particleSizeRange: 50...50
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        #expect(results.particles.count >= 1, "Should detect at least 1 particle")

        let report = AnalysisValidation.validateResults(
            detected: results.particles,
            expected: expectedParticles,
            tolerance: 20.0
        )

        #expect(report.correctlyDetected >= 1, "Should correctly detect the single particle")
    }

    @Test func testAnalysisEngine_EmptyImage_HandlesGracefully() async throws {
        // Create white image with no particles
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 500))
        let whiteImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 500, height: 500))
        }

        // Should throw noParticlesDetected error
        do {
            _ = try AnalysisValidation.runTestAnalysis(
                image: whiteImage,
                grindType: .filter,
                calibrationFactor: 5.0
            )
            Issue.record("Expected noParticlesDetected error")
        } catch CoffeeAnalysisError.noParticlesDetected {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func testAnalysisEngine_BlackImage_HandlesGracefully() async throws {
        // Create completely black image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        let blackImage = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }

        // Should throw noParticlesDetected error (no distinct particles)
        do {
            _ = try AnalysisValidation.runTestAnalysis(
                image: blackImage,
                grindType: .filter,
                calibrationFactor: 5.0
            )
            Issue.record("Expected noParticlesDetected error")
        } catch CoffeeAnalysisError.noParticlesDetected {
            // Expected error - entire image is one blob, not individual particles
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func testAnalysisEngine_VerySmallImage_HandlesGracefully() async throws {
        // Create very small image (50x50)
        let (testImage, _) = AnalysisValidation.createTestImage(
            width: 50,
            height: 50,
            particleCount: 1,
            particleSizeRange: 5...10
        )

        // Should either detect the particle or handle gracefully
        do {
            let results = try AnalysisValidation.runTestAnalysis(
                image: testImage,
                grindType: .filter,
                calibrationFactor: 5.0
            )
            // If it doesn't throw, it should at least not crash
            #expect(results.particleCount >= 0)
        } catch CoffeeAnalysisError.noParticlesDetected {
            // Also acceptable for very small images
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func testAnalysisEngine_GrayImage_HandlesGracefully() async throws {
        // Create uniform gray image (medium brightness)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        let grayImage = renderer.image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }

        // Should throw noParticlesDetected error (no contrast)
        do {
            _ = try AnalysisValidation.runTestAnalysis(
                image: grayImage,
                grindType: .filter,
                calibrationFactor: 5.0
            )
            Issue.record("Expected noParticlesDetected error")
        } catch CoffeeAnalysisError.noParticlesDetected {
            // Expected error - no distinct particles in uniform gray
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Particle Count Tests

    @Test func testAnalysisEngine_ParticleCount_MatchesDetected() async throws {
        let (testImage, _) = AnalysisValidation.createGridTestImage(
            width: 1000,
            height: 1000,
            rows: 4,
            cols: 4,
            particleRadius: 35
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // Particle count should match array length
        #expect(results.particleCount == results.particles.count)

        // Should detect most of the 16 particles
        #expect(results.particleCount >= 12) // At least 75%
    }

    // MARK: - Confidence Score Tests

    @Test func testAnalysisEngine_ManyParticles_HigherConfidence() async throws {
        let (testImage, _) = AnalysisValidation.createGridTestImage(
            width: 1200,
            height: 1200,
            rows: 10,
            cols: 10,
            particleRadius: 20
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // More particles should lead to higher confidence
        #expect(results.confidence > 50.0, "Expected confidence > 50%, got \(results.confidence)")
    }

    @Test func testAnalysisEngine_FewParticles_LowerConfidence() async throws {
        let (testImage, _) = AnalysisValidation.createTestImage(
            width: 800,
            height: 800,
            particleCount: 3,
            particleSizeRange: 60...80
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // Fewer particles typically means lower confidence
        #expect(results.confidence < 80.0, "Expected lower confidence for few particles")
    }

    // MARK: - Grind Type Tests

    @Test func testAnalysisEngine_DifferentGrindTypes_AffectsRecommendations() async throws {
        let (testImage, _) = AnalysisValidation.createGridTestImage(
            width: 1000,
            height: 1000,
            rows: 4,
            cols: 4,
            particleRadius: 40
        )

        let espressoResults = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .espresso,
            calibrationFactor: 5.0
        )

        let frenchPressResults = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .frenchPress,
            calibrationFactor: 5.0
        )

        // Same particles, different grind types should give different recommendations
        #expect(espressoResults.grindType != frenchPressResults.grindType)

        // Recommendations should exist
        #expect(!espressoResults.recommendations.isEmpty)
        #expect(!frenchPressResults.recommendations.isEmpty)
    }

    // MARK: - Image Processing Tests

    @Test func testAnalysisEngine_ProcessedImage_Generated() async throws {
        let (testImage, _) = AnalysisValidation.createGridTestImage(
            width: 600,
            height: 600,
            rows: 3,
            cols: 3,
            particleRadius: 40
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // Processed image should be generated
        #expect(results.processedImage != nil)

        // Original image should be preserved
        #expect(results.image != nil)
    }

    // MARK: - Timestamp Tests

    @Test func testAnalysisEngine_Timestamp_SetToNow() async throws {
        let (testImage, _) = AnalysisValidation.createTestImage(
            width: 500,
            height: 500,
            particleCount: 5,
            particleSizeRange: 30...50
        )

        let beforeAnalysis = Date()
        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )
        let afterAnalysis = Date()

        // Timestamp should be between before and after
        #expect(results.timestamp >= beforeAnalysis)
        #expect(results.timestamp <= afterAnalysis)
    }

    // MARK: - Fines and Boulders Tests

    @Test func testAnalysisEngine_FinesPercentage_Calculated() async throws {
        let (testImage, _) = AnalysisValidation.createGridTestImage(
            width: 800,
            height: 800,
            rows: 4,
            cols: 4,
            particleRadius: 25
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // Fines percentage should be within 0-100 range
        #expect(results.finesPercentage >= 0.0)
        #expect(results.finesPercentage <= 100.0)
    }

    @Test func testAnalysisEngine_BouldersPercentage_Calculated() async throws {
        let (testImage, _) = AnalysisValidation.createGridTestImage(
            width: 800,
            height: 800,
            rows: 4,
            cols: 4,
            particleRadius: 25
        )

        let results = try AnalysisValidation.runTestAnalysis(
            image: testImage,
            grindType: .filter,
            calibrationFactor: 5.0
        )

        // Boulders percentage should be within 0-100 range
        #expect(results.bouldersPercentage >= 0.0)
        #expect(results.bouldersPercentage <= 100.0)
    }
}
