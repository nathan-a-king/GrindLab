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
            return 5...15
        case .espresso:
            return 15...25
        case .frenchPress:
            return 0...8
        case .coldBrew:
            return 0...5
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
    
    // Store size distribution as computed property with backing storage
    let sizeDistribution: [String: Double]
    
    // Standard initializer (from fresh analysis)
    init(uniformityScore: Double, averageSize: Double, medianSize: Double, standardDeviation: Double,
         finesPercentage: Double, bouldersPercentage: Double, particleCount: Int, particles: [CoffeeParticle],
         confidence: Double, image: UIImage?, processedImage: UIImage?, grindType: CoffeeGrindType,
         timestamp: Date, tastingNotes: TastingNotes? = nil) {
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
        self.tastingNotes = tastingNotes
        
        // Compute distribution from particles immediately
        self.sizeDistribution = Self.computeSizeDistribution(from: particles, particleCount: particleCount, finesPercentage: finesPercentage, bouldersPercentage: bouldersPercentage)
    }
    
    // Initializer for loaded results (with pre-computed distribution)
    init(uniformityScore: Double, averageSize: Double, medianSize: Double, standardDeviation: Double,
         finesPercentage: Double, bouldersPercentage: Double, particleCount: Int, particles: [CoffeeParticle],
         confidence: Double, image: UIImage?, processedImage: UIImage?, grindType: CoffeeGrindType,
         timestamp: Date, sizeDistribution: [String: Double], tastingNotes: TastingNotes? = nil) {
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
        self.tastingNotes = tastingNotes
    }
    
    var uniformityColor: Color {
        switch uniformityScore {
        case 85...: return .green
        case 70..<85: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }
    
    var uniformityGrade: String {
        switch uniformityScore {
        case 90...: return "Excellent"
        case 80..<90: return "Very Good"
        case 70..<80: return "Good"
        case 60..<70: return "Fair"
        case 50..<60: return "Poor"
        default: return "Very Poor"
        }
    }
    
    var recommendations: [String] {
        var recs: [String] = []
        
        // Uniformity recommendations
        if uniformityScore < 70 {
            recs.append("Consider upgrading to a burr grinder for better uniformity")
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
    private static func computeSizeDistribution(from particles: [CoffeeParticle], particleCount: Int, finesPercentage: Double, bouldersPercentage: Double) -> [String: Double] {
        // If we have particles, compute from them
        if !particles.isEmpty {
            let totalParticles = Double(particles.count)
            var distribution: [String: Int] = [
                "Fines (<400μm)": 0,
                "Fine (400-600μm)": 0,
                "Medium (600-1000μm)": 0,
                "Coarse (1000-1400μm)": 0,
                "Boulders (>1400μm)": 0
            ]
            
            for particle in particles {
                switch particle.size {
                case 0..<400:
                    distribution["Fines (<400μm)"]! += 1
                case 400..<600:
                    distribution["Fine (400-600μm)"]! += 1
                case 600..<1000:
                    distribution["Medium (600-1000μm)"]! += 1
                case 1000..<1400:
                    distribution["Coarse (1000-1400μm)"]! += 1
                default:
                    distribution["Boulders (>1400μm)"]! += 1
                }
            }
            
            return distribution.mapValues { Double($0) / totalParticles * 100 }
        }
        
        // Otherwise, generate reasonable distribution from known percentages
        let mediumPercentage = max(0, 100 - finesPercentage - bouldersPercentage)
        let finePercentage = mediumPercentage * 0.3 // 30% of remaining
        let adjustedMedium = mediumPercentage * 0.5 // 50% of remaining
        let coarsePercentage = mediumPercentage * 0.2 // 20% of remaining
        
        return [
            "Fines (<400μm)": finesPercentage,
            "Fine (400-600μm)": finePercentage,
            "Medium (600-1000μm)": adjustedMedium,
            "Coarse (1000-1400μm)": coarsePercentage,
            "Boulders (>1400μm)": bouldersPercentage
        ]
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
    var minParticleSize: Int = 10 // pixels
    var maxParticleSize: Int = 1000 // pixels
    var enableAdvancedFiltering: Bool = false
    var calibrationFactor: Double = 1.0 // microns per pixel
    
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
