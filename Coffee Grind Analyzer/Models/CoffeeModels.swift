//
//  CoffeeModels.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI
import Foundation

// MARK: - Coffee Grind Types

enum CoffeeGrindType: CaseIterable, Codable {
    case filter
    case espresso
    case frenchPress
    case coldBrew
    
    var displayName: String {
        switch self {
        case .filter:
            return "Filter/Pour-Over"
        case .espresso:
            return "Espresso"
        case .frenchPress:
            return "French Press"
        case .coldBrew:
            return "Cold Brew"
        }
    }
    
    var targetSizeRange: String {
        switch self {
        case .filter:
            return "600-900μm"
        case .espresso:
            return "200-400μm"
        case .frenchPress:
            return "750-1000μm"
        case .coldBrew:
            return "1000-1200μm"
        }
    }
    
    var targetSizeMicrons: ClosedRange<Double> {
        switch self {
        case .filter:
            return 600...900
        case .espresso:
            return 200...400
        case .frenchPress:
            return 750...1000
        case .coldBrew:
            return 1000...1200
        }
    }
    
    var idealFinesPercentage: ClosedRange<Double> {
        switch self {
        case .filter:
            return 10...25  // Increased to reflect real-world burr grinder performance
        case .espresso:
            return 20...35  // Espresso naturally has more fines for extraction
        case .frenchPress:
            return 5...15   // French press tolerates some fines 
        case .coldBrew:
            return 3...12   // Cold brew more forgiving of fines
        }
    }
    
    var distributionCategories: [(range: Range<Double>, label: String)] {
        switch self {
        case .espresso:
            return [
                (0..<150, "Extra Fine (<150μm)"),
                (150..<250, "Fine (150-250μm)"),
                (250..<350, "Target (250-350μm)"),
                (350..<450, "Medium (350-450μm)"),
                (450..<Double.infinity, "Coarse (>450μm)")
            ]
        case .filter:
            return [
                (0..<400, "Fine (<400μm)"),
                (400..<600, "Medium-Fine (400-600μm)"),
                (600..<900, "Target (600-900μm)"),
                (900..<1200, "Coarse (900-1200μm)"),
                (1200..<Double.infinity, "Extra Coarse (>1200μm)")
            ]
        case .frenchPress:
            return [
                (0..<500, "Fine (<500μm)"),
                (500..<750, "Medium (500-750μm)"),
                (750..<1000, "Target (750-1000μm)"),
                (1000..<1300, "Coarse (1000-1300μm)"),
                (1300..<Double.infinity, "Extra Coarse (>1300μm)")
            ]
        case .coldBrew:
            return [
                (0..<700, "Fine (<700μm)"),
                (700..<1000, "Medium (700-1000μm)"),
                (1000..<1200, "Target (1000-1200μm)"),
                (1200..<1500, "Coarse (1200-1500μm)"),
                (1500..<Double.infinity, "Extra Coarse (>1500μm)")
            ]
        }
    }
}

// MARK: - Particle Data

struct CoffeeParticle {
    let id = UUID()
    let size: Double // in microns
    let area: Double // in pixels
    let circularity: Double // 0.0 to 1.0
    let position: CGPoint
    let brightness: Double
}

// MARK: - Tasting Notes

struct TastingNotes: Equatable, Codable {
    let brewMethod: BrewMethod
    let overallRating: Int // 1-5 stars
    let tastingTags: [String] // ["Balanced", "Fruity", "Bright"]
    let extractionNotes: String?
    let extractionTime: TimeInterval? // For espresso shots
    let waterTemp: Double? // Brewing temperature in celsius
    let doseIn: Double? // Coffee dose in grams
    let yieldOut: Double? // Output weight in grams
    
    enum BrewMethod: String, CaseIterable, Codable {
        case espresso = "Espresso"
        case pourOver = "Pour Over"
        case frenchPress = "French Press"
        case aeropress = "Aeropress"
        case moka = "Moka Pot"
        case coldBrew = "Cold Brew"
        case drip = "Drip Coffee"
        
        var icon: String {
            switch self {
            case .espresso: return "cup.and.saucer.fill"
            case .pourOver: return "drop.circle"
            case .frenchPress: return "cylinder.fill"
            case .aeropress: return "circle.and.line.horizontal"
            case .moka: return "triangle.fill"
            case .coldBrew: return "snowflake.circle"
            case .drip: return "drop.fill"
            }
        }
    }
    
    static let availableTags = [
        // Positive
        "Balanced", "Sweet", "Smooth", "Bright", "Clean", "Complex",
        "Fruity", "Floral", "Nutty", "Chocolatey", "Caramel", "Vanilla",
        
        // Neutral/Descriptive
        "Full Body", "Light Body", "Medium Body", "Acidic", "Low Acid",
        "Earthy", "Spicy", "Herbal", "Wine-like", "Tea-like",
        
        // Issues
        "Bitter", "Sour", "Astringent", "Muddy", "Weak", "Over-extracted",
        "Under-extracted", "Chalky", "Harsh", "Flat"
    ]
}

// MARK: - Calibration Info

struct CalibrationInfo {
    let source: CalibrationSource
    let factor: Double // microns per pixel
    let coinType: String? // e.g., "US Quarter"
    let confidence: Double? // for auto-detected coins
    
    enum CalibrationSource {
        case automatic(coinDetected: Bool)
        case manual
        case defaultValue
    }
    
    var description: String {
        switch source {
        case .automatic(let coinDetected):
            if coinDetected, let coin = coinType {
                return "Auto-calibrated using \(coin)"
            } else {
                return "Default calibration (no reference object found)"
            }
        case .manual:
            return "Manual calibration"
        case .defaultValue:
            return "Default calibration"
        }
    }
    
    // Helper for sample/preview data
    static let defaultPreview = CalibrationInfo(
        source: .defaultValue,
        factor: 150.0,
        coinType: nil,
        confidence: nil
    )
}

// MARK: - Analysis Results

struct CoffeeAnalysisResults {
    let uniformityScore: Double
    let averageSize: Double // in microns
    let medianSize: Double // in microns
    let standardDeviation: Double
    let finesPercentage: Double
    let bouldersPercentage: Double
    let particleCount: Int
    let particles: [CoffeeParticle]
    let confidence: Double
    let image: UIImage?
    let processedImage: UIImage?
    let grindType: CoffeeGrindType
    let timestamp: Date
    let tastingNotes: TastingNotes? // Add tasting notes
    let calibrationInfo: CalibrationInfo // Calibration details
    
    // Store size distribution as computed property with backing storage
    let sizeDistribution: [String: Double]
    
    // Standard initializer (from fresh analysis)
    init(uniformityScore: Double, averageSize: Double, medianSize: Double, standardDeviation: Double,
         finesPercentage: Double, bouldersPercentage: Double, particleCount: Int, particles: [CoffeeParticle],
         confidence: Double, image: UIImage?, processedImage: UIImage?, grindType: CoffeeGrindType,
         timestamp: Date, calibrationInfo: CalibrationInfo, tastingNotes: TastingNotes? = nil) {
        self.uniformityScore = uniformityScore
        self.averageSize = averageSize
        self.medianSize = medianSize
        self.standardDeviation = standardDeviation
        self.finesPercentage = finesPercentage
        self.bouldersPercentage = bouldersPercentage
        self.particleCount = particleCount
        self.particles = particles
        self.confidence = confidence
        self.image = image
        self.processedImage = processedImage
        self.grindType = grindType
        self.timestamp = timestamp
        self.calibrationInfo = calibrationInfo
        self.tastingNotes = tastingNotes
        
        // Compute distribution from particles immediately
        self.sizeDistribution = Self.computeSizeDistribution(from: particles, grindType: grindType, particleCount: particleCount, finesPercentage: finesPercentage, bouldersPercentage: bouldersPercentage)
    }
    
    // Initializer for loaded results (with pre-computed distribution)
    init(uniformityScore: Double, averageSize: Double, medianSize: Double, standardDeviation: Double,
         finesPercentage: Double, bouldersPercentage: Double, particleCount: Int, particles: [CoffeeParticle],
         confidence: Double, image: UIImage?, processedImage: UIImage?, grindType: CoffeeGrindType,
         timestamp: Date, sizeDistribution: [String: Double], calibrationInfo: CalibrationInfo, tastingNotes: TastingNotes? = nil) {
        self.uniformityScore = uniformityScore
        self.averageSize = averageSize
        self.medianSize = medianSize
        self.standardDeviation = standardDeviation
        self.finesPercentage = finesPercentage
        self.bouldersPercentage = bouldersPercentage
        self.particleCount = particleCount
        self.particles = particles
        self.confidence = confidence
        self.image = image
        self.processedImage = processedImage
        self.grindType = grindType
        self.timestamp = timestamp
        self.sizeDistribution = sizeDistribution
        self.calibrationInfo = calibrationInfo
        self.tastingNotes = tastingNotes
    }
    
    var uniformityColor: Color {
        switch uniformityScore {
        case 70...: return .green           // Lowered from 85 - green for good performance
        case 55..<70: return .yellow        // Lowered from 70 - yellow for acceptable
        case 40..<55: return .orange        // Lowered from 50 - orange for needs improvement
        default: return .red                // Red for poor performance
        }
    }
    
    var uniformityGrade: String {
        switch uniformityScore {
        case 75...: return "Excellent"      // Lowered from 90 - even great grinders have variation
        case 65..<75: return "Very Good"    // Lowered from 80 - good burr grinder performance
        case 55..<65: return "Good"         // Lowered from 70 - acceptable for most brewing
        case 45..<55: return "Fair"         // Lowered from 60 - needs improvement
        case 35..<45: return "Poor"         // Lowered from 50 - blade grinder territory
        default: return "Very Poor"         // Below 35 - very inconsistent grinding
        }
    }
    
    var recommendations: [String] {
        var recs: [String] = []
        
        // Uniformity recommendations  
        if uniformityScore < 45 {
            recs.append("Consider upgrading to a burr grinder for better uniformity")
        } else if uniformityScore < 60 {
            recs.append("Grind consistency could be improved - check burr alignment or wear")
        }
        
        // Fines recommendations
        if finesPercentage > grindType.idealFinesPercentage.upperBound {
            recs.append("Reduce grinder speed or use a coarser setting to minimize fines")
        } else if finesPercentage < grindType.idealFinesPercentage.lowerBound {
            recs.append("Slightly finer grind may improve extraction")
        }
        
        // Size recommendations
        let targetRange = grindType.targetSizeMicrons
        if averageSize < targetRange.lowerBound {
            recs.append("Grind is too fine for \(grindType.displayName) - adjust to coarser setting")
        } else if averageSize > targetRange.upperBound {
            recs.append("Grind is too coarse for \(grindType.displayName) - adjust to finer setting")
        } else {
            recs.append("Grind size is well-suited for \(grindType.displayName)")
        }
        
        // Boulder recommendations
        if bouldersPercentage > 10 {
            recs.append("High percentage of boulders detected - check grinder burrs for wear")
        }
        
        if recs.isEmpty {
            recs.append("Excellent grind quality - no adjustments needed")
        }
        
        return recs
    }
    
    // Static method to compute size distribution
    private static func computeSizeDistribution(from particles: [CoffeeParticle], grindType: CoffeeGrindType, particleCount: Int, finesPercentage: Double, bouldersPercentage: Double) -> [String: Double] {
        let categories = grindType.distributionCategories
        
        // If we have particles, compute from them
        if !particles.isEmpty {
            let totalParticles = Double(particles.count)
            var distribution: [String: Int] = [:]
            
            // Initialize all categories
            for category in categories {
                distribution[category.label] = 0
            }
            
            // Count particles in each category
            for particle in particles {
                for category in categories {
                    if category.range.contains(particle.size) {
                        distribution[category.label]! += 1
                        break
                    }
                }
            }
            
            return distribution.mapValues { Double($0) / totalParticles * 100 }
        }
        
        // Otherwise, generate reasonable distribution from known percentages
        // This is a fallback when we don't have particle data
        var distribution: [String: Double] = [:]
        let categoryCount = Double(categories.count)
        
        // Simple distribution based on available data
        // Put more weight in the middle categories
        for (index, category) in categories.enumerated() {
            switch index {
            case 0:
                // First category gets most of the fines
                distribution[category.label] = finesPercentage * 0.8
            case categories.count - 1:
                // Last category gets most of the boulders
                distribution[category.label] = bouldersPercentage * 0.8
            default:
                // Middle categories share the remaining percentage
                let remaining = max(0, 100 - finesPercentage - bouldersPercentage)
                distribution[category.label] = remaining / (categoryCount - 2)
            }
        }
        
        return distribution
    }
}

// MARK: - Analysis Errors

enum CoffeeAnalysisError: Error, LocalizedError {
    case imageProcessingFailed
    case noParticlesDetected
    case insufficientContrast
    case analysisError(String)
    case cameraError(String)
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the image. Please try again with better lighting."
        case .noParticlesDetected:
            return "No coffee particles detected. Ensure the coffee is well-lit against a contrasting background."
        case .insufficientContrast:
            return "Insufficient contrast between coffee and background. Try using a white surface."
        case .analysisError(let message):
            return "Analysis error: \(message)"
        case .cameraError(let message):
            return "Camera error: \(message)"
        }
    }
}

// MARK: - Settings Model

struct AnalysisSettings: Equatable {
    var analysisMode: AnalysisMode = .standard
    var contrastThreshold: Double = 0.3
    var minParticleSize: Int = 5 // diameter in pixels - minimum particle diameter
    var maxParticleSize: Int = 500 // diameter in pixels - maximum particle diameter  
    var enableAdvancedFiltering: Bool = true // enabled by default for better quality
    var calibrationFactor: Double = 150.0 // improved default microns per pixel
    var adaptiveThresholdWindow: Int = 15 // window size for adaptive thresholding
    var morphologyKernelSize: Int = 3 // kernel size for noise reduction
    var minCircularity: Double = 0.1 // minimum circularity for valid particles (lower for more tolerance)
    var maxAspectRatio: Double = 5.0 // maximum aspect ratio for valid particles (higher for elongated shapes)
    var minSolidity: Double = 0.3 // minimum solidity (filled-ness) for valid particles (lower for more tolerance)
    
    enum AnalysisMode: Int, CaseIterable, Equatable {
        case basic = 0
        case standard = 1
        case advanced = 2
        
        var displayName: String {
            switch self {
            case .basic: return "Basic"
            case .standard: return "Standard"
            case .advanced: return "Advanced"
            }
        }
    }
}
