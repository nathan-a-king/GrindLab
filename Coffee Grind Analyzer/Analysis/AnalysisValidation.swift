//
//  AnalysisValidation.swift
//  Coffee Grind Analyzer
//
//  Validation utilities for testing the analysis engine
//

import UIKit
import Foundation
import OSLog

private enum ValidationLog {
    static let logger = Logger(subsystem: "com.nateking.GrindLab", category: "AnalysisValidation")

    static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func report(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }
}

class AnalysisValidation {
    
    // MARK: - Test Image Generation
    
    /// Creates a test image with known circular particles
    static func createTestImage(
        width: Int = 1000,
        height: Int = 1000,
        particleCount: Int = 20,
        particleSizeRange: ClosedRange<Int> = 20...100,
        testCalibrationFactor: Double = 5.0 // 5 microns per pixel for synthetic test images
    ) -> (image: UIImage, expectedParticles: [TestParticle]) {
        
        var expectedParticles: [TestParticle] = []
        
        // Create renderer with explicit scale of 1.0 to ensure 1:1 pixel mapping
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Draw known particles
            UIColor.black.setFill()
            
            for i in 0..<particleCount {
                // Random position and size
                let radius = Int.random(in: particleSizeRange)
                let x = Int.random(in: radius...(width - radius))
                let y = Int.random(in: radius...(height - radius))
                
                // Draw circle
                let rect = CGRect(
                    x: x - radius,
                    y: y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.cgContext.fillEllipse(in: rect)
                
                // Record expected particle
                let particle = TestParticle(
                    center: CGPoint(x: x, y: y),
                    radius: Double(radius),
                    area: Double.pi * Double(radius * radius)
                )
                expectedParticles.append(particle)
                
                // Add particle number for debugging
                if particleCount <= 30 {
                    UIColor.white.set()
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: CGFloat(radius / 2)),
                        .foregroundColor: UIColor.white
                    ]
                    let text = "\(i + 1)"
                    let textSize = text.size(withAttributes: attributes)
                    let textRect = CGRect(
                        x: x - Int(textSize.width / 2),
                        y: y - Int(textSize.height / 2),
                        width: Int(textSize.width),
                        height: Int(textSize.height)
                    )
                    text.draw(in: textRect, withAttributes: attributes)
                    UIColor.black.setFill()
                }
            }
        }
        
        ValidationLog.debug("🧪 Created test image: \(width)x\(height) with \(particleCount) particles")
        ValidationLog.debug("🎯 Particle sizes: \(particleSizeRange) pixel radius")
        
        return (image, expectedParticles)
    }
    
    /// Creates a grid pattern test image
    static func createGridTestImage(
        width: Int = 1000,
        height: Int = 1000,
        rows: Int = 5,
        cols: Int = 5,
        particleRadius: Int = 30,
        testCalibrationFactor: Double = 5.0 // 5 microns per pixel for synthetic test images
    ) -> (image: UIImage, expectedParticles: [TestParticle]) {
        
        var expectedParticles: [TestParticle] = []
        
        let cellWidth = width / cols
        let cellHeight = height / rows
        
        // Create renderer with explicit scale of 1.0 to ensure 1:1 pixel mapping
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            
            // Draw grid of particles
            UIColor.black.setFill()
            
            var particleNumber = 1
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = col * cellWidth + cellWidth / 2
                    let y = row * cellHeight + cellHeight / 2
                    
                    // Draw circle
                    let rect = CGRect(
                        x: x - particleRadius,
                        y: y - particleRadius,
                        width: particleRadius * 2,
                        height: particleRadius * 2
                    )
                    context.cgContext.fillEllipse(in: rect)
                    
                    // Record expected particle
                    let particle = TestParticle(
                        center: CGPoint(x: x, y: y),
                        radius: Double(particleRadius),
                        area: Double.pi * Double(particleRadius * particleRadius)
                    )
                    expectedParticles.append(particle)
                    
                    // Add particle number
                    UIColor.white.set()
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: CGFloat(particleRadius / 2)),
                        .foregroundColor: UIColor.white
                    ]
                    let text = "\(particleNumber)"
                    let textSize = text.size(withAttributes: attributes)
                    let textRect = CGRect(
                        x: x - Int(textSize.width / 2),
                        y: y - Int(textSize.height / 2),
                        width: Int(textSize.width),
                        height: Int(textSize.height)
                    )
                    text.draw(in: textRect, withAttributes: attributes)
                    UIColor.black.setFill()
                    
                    particleNumber += 1
                }
            }
        }
        
        ValidationLog.debug("🧪 Created grid test image: \(rows)x\(cols) grid, \(particleRadius)px radius particles")
        
        return (image, expectedParticles)
    }
    
    /// Runs analysis with test-appropriate settings
    static func runTestAnalysis(
        image: UIImage,
        grindType: CoffeeGrindType = .filter,
        calibrationFactor: Double = 5.0
    ) throws -> CoffeeAnalysisResults {
        // Create test settings with appropriate calibration
        var testSettings = AnalysisSettings()
        testSettings.calibrationFactor = calibrationFactor
        testSettings.minParticleSize = 10 // smaller for test images
        testSettings.maxParticleSize = 1000 // larger for test images
        
        let engine = CoffeeAnalysisEngine(settings: testSettings)
        
        // Since analyzeGrind is async, we need to make it synchronous for testing
        let semaphore = DispatchSemaphore(value: 0)
        var analysisResult: Result<CoffeeAnalysisResults, CoffeeAnalysisError>?
        
        engine.analyzeGrind(image: image, grindType: grindType) { result in
            analysisResult = result
            semaphore.signal()
        }
        
        semaphore.wait()
        
        switch analysisResult! {
        case .success(let results):
            return results
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validates detected particles against expected particles
    static func validateResults(
        detected: [CoffeeParticle],
        expected: [TestParticle],
        tolerance: Double = 5.0 // pixels
    ) -> ValidationReport {
        
        var matchedParticles: [(detected: CoffeeParticle, expected: TestParticle)] = []
        var unmatchedDetected: [CoffeeParticle] = []
        var unmatchedExpected: [TestParticle] = []
        
        var usedExpected = Set<Int>()
        
        // Try to match each detected particle with an expected one
        for detectedParticle in detected {
            var bestMatch: (index: Int, distance: Double)?
            
            for (index, expectedParticle) in expected.enumerated() {
                guard !usedExpected.contains(index) else { continue }
                
                let distance = sqrt(
                    pow(Double(detectedParticle.position.x - expectedParticle.center.x), 2) +
                    pow(Double(detectedParticle.position.y - expectedParticle.center.y), 2)
                )
                
                if distance <= tolerance {
                    if bestMatch == nil || distance < bestMatch!.distance {
                        bestMatch = (index: index, distance: distance)
                    }
                }
            }
            
            if let match = bestMatch {
                matchedParticles.append((detectedParticle, expected[match.index]))
                usedExpected.insert(match.index)
            } else {
                unmatchedDetected.append(detectedParticle)
            }
        }
        
        // Find unmatched expected particles
        for (index, expectedParticle) in expected.enumerated() {
            if !usedExpected.contains(index) {
                unmatchedExpected.append(expectedParticle)
            }
        }
        
        // Calculate metrics
        let precision = Double(matchedParticles.count) / Double(max(detected.count, 1))
        let recall = Double(matchedParticles.count) / Double(max(expected.count, 1))
        let f1Score = (precision + recall) > 0 ? 2 * (precision * recall) / (precision + recall) : 0
        
        // Calculate position accuracy for matched particles
        var positionErrors: [Double] = []
        var sizeErrors: [Double] = []
        
        for (detected, expected) in matchedParticles {
            let posError = sqrt(
                pow(Double(detected.position.x - expected.center.x), 2) +
                pow(Double(detected.position.y - expected.center.y), 2)
            )
            positionErrors.append(posError)
            
            let detectedRadius = sqrt(detected.area / .pi)
            let sizeError = abs(detectedRadius - expected.radius)
            sizeErrors.append(sizeError)
        }
        
        let avgPositionError = positionErrors.isEmpty ? 0 : positionErrors.reduce(0, +) / Double(positionErrors.count)
        let avgSizeError = sizeErrors.isEmpty ? 0 : sizeErrors.reduce(0, +) / Double(sizeErrors.count)
        
        return ValidationReport(
            totalExpected: expected.count,
            totalDetected: detected.count,
            correctlyDetected: matchedParticles.count,
            falsePositives: unmatchedDetected.count,
            falseNegatives: unmatchedExpected.count,
            precision: precision,
            recall: recall,
            f1Score: f1Score,
            avgPositionError: avgPositionError,
            avgSizeError: avgSizeError,
            matchedParticles: matchedParticles,
            unmatchedDetected: unmatchedDetected,
            unmatchedExpected: unmatchedExpected
        )
    }
    
    /// Creates a debug overlay showing validation results
    static func createDebugOverlay(
        originalImage: UIImage,
        report: ValidationReport
    ) -> UIImage {
        
        // Create renderer with same scale as original image
        let format = UIGraphicsImageRendererFormat()
        format.scale = originalImage.scale
        let renderer = UIGraphicsImageRenderer(size: originalImage.size, format: format)
        
        return renderer.image { context in
            // Draw original image
            originalImage.draw(at: .zero)
            
            context.cgContext.setLineWidth(2.0)
            
            // Draw matched particles in green
            UIColor.green.withAlphaComponent(0.7).setStroke()
            for (detected, _) in report.matchedParticles {
                let radius = sqrt(detected.area / .pi)
                let rect = CGRect(
                    x: detected.position.x - radius,
                    y: detected.position.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.cgContext.strokeEllipse(in: rect)
            }
            
            // Draw false positives in red
            UIColor.red.withAlphaComponent(0.7).setStroke()
            for detected in report.unmatchedDetected {
                let radius = sqrt(detected.area / .pi)
                let rect = CGRect(
                    x: detected.position.x - radius,
                    y: detected.position.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.cgContext.strokeEllipse(in: rect)
            }
            
            // Draw missed particles (false negatives) in yellow
            UIColor.yellow.withAlphaComponent(0.7).setStroke()
            for expected in report.unmatchedExpected {
                let rect = CGRect(
                    x: expected.center.x - expected.radius,
                    y: expected.center.y - expected.radius,
                    width: expected.radius * 2,
                    height: expected.radius * 2
                )
                context.cgContext.strokeEllipse(in: rect)
                
                // Draw X to indicate missed
                context.cgContext.move(to: CGPoint(x: rect.minX, y: rect.minY))
                context.cgContext.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                context.cgContext.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                context.cgContext.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                context.cgContext.strokePath()
            }
            
            // Add legend
            let legendHeight: CGFloat = 100
            let legendY = originalImage.size.height - legendHeight
            
            UIColor.white.withAlphaComponent(0.9).setFill()
            context.fill(CGRect(x: 0, y: legendY, width: originalImage.size.width, height: legendHeight))
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            
            let legend = """
            🟢 Correct: \(report.correctlyDetected)  🔴 False Positives: \(report.falsePositives)  🟡 Missed: \(report.falseNegatives)
            Precision: \(String(format: "%.1f%%", report.precision * 100))  Recall: \(String(format: "%.1f%%", report.recall * 100))  F1: \(String(format: "%.2f", report.f1Score))
            Avg Position Error: \(String(format: "%.1f", report.avgPositionError))px  Avg Size Error: \(String(format: "%.1f", report.avgSizeError))px
            """
            
            legend.draw(in: CGRect(x: 10, y: legendY + 10, width: originalImage.size.width - 20, height: legendHeight - 20), withAttributes: attributes)
        }
    }
}

// MARK: - Supporting Types

struct TestParticle {
    let center: CGPoint
    let radius: Double
    let area: Double
}

struct ValidationReport {
    let totalExpected: Int
    let totalDetected: Int
    let correctlyDetected: Int
    let falsePositives: Int
    let falseNegatives: Int
    let precision: Double
    let recall: Double
    let f1Score: Double
    let avgPositionError: Double
    let avgSizeError: Double
    let matchedParticles: [(detected: CoffeeParticle, expected: TestParticle)]
    let unmatchedDetected: [CoffeeParticle]
    let unmatchedExpected: [TestParticle]
    
    func printReport() {
        ValidationLog.report("\n" + String(repeating: "=", count: 60))
        ValidationLog.report("📊 VALIDATION REPORT")
        ValidationLog.report(String(repeating: "=", count: 60))
        ValidationLog.report("Expected Particles: \(totalExpected)")
        ValidationLog.report("Detected Particles: \(totalDetected)")
        ValidationLog.report("✅ Correctly Detected: \(correctlyDetected)")
        ValidationLog.report("❌ False Positives: \(falsePositives)")
        ValidationLog.report("⚠️  Missed Particles: \(falseNegatives)")
        ValidationLog.report(String(repeating: "-", count: 60))
        ValidationLog.report("📈 Metrics:")
        ValidationLog.report("   Precision: \(String(format: "%.1f%%", precision * 100))")
        ValidationLog.report("   Recall: \(String(format: "%.1f%%", recall * 100))")
        ValidationLog.report("   F1 Score: \(String(format: "%.3f", f1Score))")
        ValidationLog.report("   Avg Position Error: \(String(format: "%.2f", avgPositionError)) pixels")
        ValidationLog.report("   Avg Size Error: \(String(format: "%.2f", avgSizeError)) pixels")
        ValidationLog.report(String(repeating: "=", count: 60))
        
        if !unmatchedExpected.isEmpty {
            ValidationLog.report("\n⚠️  Missed Particles (positions):")
            for particle in unmatchedExpected {
                ValidationLog.report("   - Position: (\(Int(particle.center.x)), \(Int(particle.center.y))), Radius: \(Int(particle.radius))")
            }
        }
        
        if !unmatchedDetected.isEmpty {
            ValidationLog.report("\n❌ False Positives (positions):")
            for particle in unmatchedDetected {
                ValidationLog.report("   - Position: (\(Int(particle.position.x)), \(Int(particle.position.y))), Area: \(Int(particle.area))")
            }
        }
    }
}
