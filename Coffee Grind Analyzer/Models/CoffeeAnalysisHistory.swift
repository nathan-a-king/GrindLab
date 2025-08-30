//
//  CoffeeAnalysisHistory.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import Foundation
import UIKit
import Combine

// MARK: - Saved Analysis Model

struct SavedCoffeeAnalysis: Identifiable {
    let id = UUID()
    let name: String
    let results: CoffeeAnalysisResults
    let savedDate: Date
    let notes: String?
    let originalImagePath: String?
    let processedImagePath: String?
}

// MARK: - History Manager

class CoffeeAnalysisHistoryManager: ObservableObject {
    @Published var savedAnalyses: [SavedCoffeeAnalysis] = []
    
    private let userDefaults = UserDefaults.standard
    private let savedAnalysesKey = "SavedCoffeeAnalyses"
    private let maxStoredResults = 50 // Limit to prevent storage bloat
    
    // Image storage
    private var imagesDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("AnalysisImages")
    }
    
    init() {
        createImagesDirectoryIfNeeded()
        loadSavedAnalyses()
    }
    
    // MARK: - Image Persistence
    
    private func createImagesDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }
    
    private func saveImage(_ image: UIImage, with identifier: String, suffix: String) -> String? {
        guard let compressedData = compressImage(image) else { return nil }
        
        let filename = "\(identifier)_\(suffix).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        do {
            try compressedData.write(to: fileURL)
            return filename
        } catch {
            print("❌ Failed to save image: \(error)")
            return nil
        }
    }
    
    private func compressImage(_ image: UIImage) -> Data? {
        // Resize to max 800px width for low-res storage
        let maxWidth: CGFloat = 800
        let scale = min(maxWidth / image.size.width, maxWidth / image.size.height)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Compress to JPEG with 70% quality for good balance of size/quality
        return resizedImage?.jpegData(compressionQuality: 0.7)
    }
    
    func loadImage(from path: String) -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(path)
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    private func deleteImage(at path: String?) {
        guard let path = path else { return }
        let fileURL = imagesDirectory.appendingPathComponent(path)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Save Analysis
    
    func saveAnalysis(_ results: CoffeeAnalysisResults, name: String? = nil, notes: String? = nil) {
        let analysisName = name ?? generateDefaultName(for: results)
        let identifier = UUID().uuidString
        
        // Save images to disk
        let originalImagePath = results.image.flatMap { saveImage($0, with: identifier, suffix: "original") }
        let processedImagePath = results.processedImage.flatMap { saveImage($0, with: identifier, suffix: "processed") }
        
        let savedAnalysis = SavedCoffeeAnalysis(
            name: analysisName,
            results: results,
            savedDate: Date(),
            notes: notes,
            originalImagePath: originalImagePath,
            processedImagePath: processedImagePath
        )
        
        // Add to beginning of array (most recent first)
        savedAnalyses.insert(savedAnalysis, at: 0)
        
        // Limit storage to prevent bloat
        if savedAnalyses.count > maxStoredResults {
            savedAnalyses = Array(savedAnalyses.prefix(maxStoredResults))
        }
        
        persistAnalyses()
    }
    
    // MARK: - Update Existing Analysis
    
    func updateAnalysisTastingNotes(analysisId: UUID, tastingNotes: TastingNotes?) {
        guard let index = savedAnalyses.firstIndex(where: { $0.id == analysisId }) else { return }
        
        // Create updated results with new tasting notes
        let oldResults = savedAnalyses[index].results
        let updatedResults = CoffeeAnalysisResults(
            uniformityScore: oldResults.uniformityScore,
            averageSize: oldResults.averageSize,
            medianSize: oldResults.medianSize,
            standardDeviation: oldResults.standardDeviation,
            finesPercentage: oldResults.finesPercentage,
            bouldersPercentage: oldResults.bouldersPercentage,
            particleCount: oldResults.particleCount,
            particles: oldResults.particles,
            confidence: oldResults.confidence,
            image: oldResults.image,
            processedImage: oldResults.processedImage,
            grindType: oldResults.grindType,
            timestamp: oldResults.timestamp,
            sizeDistribution: oldResults.sizeDistribution,
            calibrationFactor: oldResults.calibrationFactor,
            tastingNotes: tastingNotes,
            storedMinParticleSize: oldResults.minParticleSize,
            storedMaxParticleSize: oldResults.maxParticleSize,
            granularDistribution: oldResults.granularDistribution,
            chartDataPoints: oldResults.chartDataPoints
        )
        
        // Create updated saved analysis
        let updatedAnalysis = SavedCoffeeAnalysis(
            name: savedAnalyses[index].name,
            results: updatedResults,
            savedDate: savedAnalyses[index].savedDate,
            notes: savedAnalyses[index].notes,
            originalImagePath: savedAnalyses[index].originalImagePath,
            processedImagePath: savedAnalyses[index].processedImagePath
        )
        
        // Update the array
        savedAnalyses[index] = updatedAnalysis
        
        // Persist changes
        persistAnalyses()
        
        print("✅ Updated tasting notes for analysis: \(updatedAnalysis.name)")
    }
    
    // MARK: - Delete Analysis
    
    func deleteAnalysis(at index: Int) {
        guard index < savedAnalyses.count else { return }
        let analysis = savedAnalyses[index]
        
        // Clean up image files
        deleteImage(at: analysis.originalImagePath)
        deleteImage(at: analysis.processedImagePath)
        
        savedAnalyses.remove(at: index)
        persistAnalyses()
    }
    
    func deleteAnalysis(withId id: UUID) {
        // Find and clean up images before removing
        if let analysis = savedAnalyses.first(where: { $0.id == id }) {
            deleteImage(at: analysis.originalImagePath)
            deleteImage(at: analysis.processedImagePath)
        }
        
        savedAnalyses.removeAll { $0.id == id }
        persistAnalyses()
    }
    
    // MARK: - Clear All
    
    func clearAllAnalyses() {
        // Clean up all image files
        for analysis in savedAnalyses {
            deleteImage(at: analysis.originalImagePath)
            deleteImage(at: analysis.processedImagePath)
        }
        
        savedAnalyses.removeAll()
        persistAnalyses()
    }
    
    // MARK: - Search and Filter
    
    func analysesForGrindType(_ grindType: CoffeeGrindType) -> [SavedCoffeeAnalysis] {
        return savedAnalyses.filter { $0.results.grindType == grindType }
    }
    
    func recentAnalyses(limit: Int = 5) -> [SavedCoffeeAnalysis] {
        return Array(savedAnalyses.prefix(limit))
    }
    
    // MARK: - Statistics
    
    var totalAnalyses: Int {
        return savedAnalyses.count
    }
    
    var averageUniformityScore: Double {
        guard !savedAnalyses.isEmpty else { return 0 }
        let total = savedAnalyses.reduce(0) { $0 + $1.results.uniformityScore }
        return total / Double(savedAnalyses.count)
    }
    
    var bestResult: SavedCoffeeAnalysis? {
        return savedAnalyses.max { $0.results.uniformityScore < $1.results.uniformityScore }
    }
    
    // MARK: - Private Methods
    
    private func generateDefaultName(for results: CoffeeAnalysisResults) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let dateString = formatter.string(from: results.timestamp)
        
        let score = Int(results.uniformityScore)
        return "\(results.grindType.displayName) - \(score)% (\(dateString))"
    }
    
    private func persistAnalyses() {
        do {
            // Convert to data that can be stored
            let analysesToStore = savedAnalyses.map { analysis in
                print("📝 Saving analysis: \(analysis.name)")
                print("📝 Has tasting notes: \(analysis.results.tastingNotes != nil)")
                
                // Calculate min/max particle sizes for chart domain calculation
                let minSize = analysis.results.particles.isEmpty ? nil : analysis.results.particles.map { $0.size }.min()
                let maxSize = analysis.results.particles.isEmpty ? nil : analysis.results.particles.map { $0.size }.max()
                
                // DEBUG: Log what we're about to save
                print("🟢 DEBUG: Saving analysis '\(analysis.name)'")
                print("🟢 DEBUG: Has particles: \(!analysis.results.particles.isEmpty) (\(analysis.results.particles.count))")
                print("🟢 DEBUG: Has chartDataPoints: \(analysis.results.chartDataPoints != nil) (\(analysis.results.chartDataPoints?.count ?? 0))")
                if let chartPoints = analysis.results.chartDataPoints {
                    let nonZero = chartPoints.filter { $0.percentage > 0 }
                    print("🟢 DEBUG: Non-zero chart points: \(nonZero.count)")
                    for point in nonZero.prefix(3) {
                        print("🟢 DEBUG: Saving point - \(point.label): \(String(format: "%.1f", point.percentage))%")
                    }
                }
                
                return StorableAnalysis(
                    id: analysis.id,
                    name: analysis.name,
                    grindType: analysis.results.grindType,
                    uniformityScore: analysis.results.uniformityScore,
                    averageSize: analysis.results.averageSize,
                    medianSize: analysis.results.medianSize,
                    standardDeviation: analysis.results.standardDeviation,
                    finesPercentage: analysis.results.finesPercentage,
                    bouldersPercentage: analysis.results.bouldersPercentage,
                    particleCount: analysis.results.particleCount,
                    confidence: analysis.results.confidence,
                    timestamp: analysis.results.timestamp,
                    savedDate: analysis.savedDate,
                    notes: analysis.notes,
                    sizeDistribution: analysis.results.sizeDistribution,
                    tastingNotes: analysis.results.tastingNotes,
                    originalImagePath: analysis.originalImagePath,
                    processedImagePath: analysis.processedImagePath,
                    minParticleSize: minSize,
                    maxParticleSize: maxSize,
                    granularDistribution: analysis.results.granularDistribution,
                    chartDataPoints: analysis.results.chartDataPoints
                )
            }
            
            let data = try JSONEncoder().encode(analysesToStore)
            userDefaults.set(data, forKey: savedAnalysesKey)
            
            print("✅ Saved \(savedAnalyses.count) analyses to storage")
            
        } catch {
            print("❌ Error saving analyses: \(error)")
        }
    }
    
    private func loadSavedAnalyses() {
        guard let data = userDefaults.data(forKey: savedAnalysesKey) else {
            print("🔭 No saved analyses found")
            return
        }
        
        do {
            let storableAnalyses = try JSONDecoder().decode([StorableAnalysis].self, from: data)
            
            // Convert back to full analysis objects
            print("🟡 DEBUG: Loading \(storableAnalyses.count) analyses from storage")
            
            savedAnalyses = storableAnalyses.compactMap { storable in
                print("🟡 DEBUG: Loading analysis '\(storable.name)'")
                print("🟡 DEBUG: Has chartDataPoints: \(storable.chartDataPoints != nil) (\(storable.chartDataPoints?.count ?? 0))")
                if let chartPoints = storable.chartDataPoints {
                    let nonZero = chartPoints.filter { $0.percentage > 0 }
                    print("🟡 DEBUG: Loaded non-zero chart points: \(nonZero.count)")
                    for point in nonZero.prefix(3) {
                        print("🟡 DEBUG: Loaded point - \(point.label): \(String(format: "%.1f", point.percentage))%")
                    }
                }
                // Check if distribution needs to be regenerated for new category system
                // Old system had fixed categories like "Fines (<400μm)", new system is dynamic
                let needsNewDistribution = storable.sizeDistribution.isEmpty ||
                    storable.sizeDistribution.keys.contains("Fines (<400μm)") // Old format detection
                
                let distribution: [String: Double]
                if needsNewDistribution {
                    // Generate distribution using new grind-specific categories
                    distribution = generateGrindSpecificDistribution(
                        grindType: storable.grindType,
                        finesPercentage: storable.finesPercentage,
                        bouldersPercentage: storable.bouldersPercentage
                    )
                } else {
                    distribution = storable.sizeDistribution
                }
                
                print("📊 Loading analysis '\(storable.name)': distribution has \(distribution.count) categories")
                
                // Load images from disk if available
                let originalImage = storable.originalImagePath.flatMap { loadImage(from: $0) }
                let processedImage = storable.processedImagePath.flatMap { loadImage(from: $0) }
                
                let results = CoffeeAnalysisResults(
                    uniformityScore: storable.uniformityScore,
                    averageSize: storable.averageSize,
                    medianSize: storable.medianSize,
                    standardDeviation: storable.standardDeviation,
                    finesPercentage: storable.finesPercentage,
                    bouldersPercentage: storable.bouldersPercentage,
                    particleCount: storable.particleCount,
                    particles: [], // Don't store individual particles for space
                    confidence: storable.confidence,
                    image: originalImage, // Load from disk
                    processedImage: processedImage, // Load from disk
                    grindType: storable.grindType,
                    timestamp: storable.timestamp,
                    sizeDistribution: distribution, // Use validated distribution
                    calibrationFactor: 150.0, // Default calibration factor for older saved data
                    tastingNotes: storable.tastingNotes,
                    storedMinParticleSize: storable.minParticleSize, // Pass stored min/max for chart domain
                    storedMaxParticleSize: storable.maxParticleSize,
                    granularDistribution: storable.granularDistribution, // Pass stored granular distribution for chart
                    chartDataPoints: storable.chartDataPoints // Pass exact chart data points
                )
                
                return SavedCoffeeAnalysis(
                    name: storable.name,
                    results: results,
                    savedDate: storable.savedDate,
                    notes: storable.notes,
                    originalImagePath: storable.originalImagePath,
                    processedImagePath: storable.processedImagePath
                )
            }
            
            print("✅ Loaded \(savedAnalyses.count) analyses from storage")
            
        } catch {
            print("❌ Error loading analyses: \(error)")
            // If loading fails, try to load legacy format or clear corrupted data
            userDefaults.removeObject(forKey: savedAnalysesKey)
        }
    }
    
    // Generate a reasonable size distribution using grind-specific categories
    private func generateGrindSpecificDistribution(grindType: CoffeeGrindType, finesPercentage: Double, bouldersPercentage: Double) -> [String: Double] {
        let categories = grindType.distributionCategories
        var distribution: [String: Double] = [:]
        
        let middlePercentage = max(0, 100 - finesPercentage - bouldersPercentage)
        
        // Distribute across categories
        for (index, category) in categories.enumerated() {
            switch index {
            case 0:
                // First category gets most of the fines
                distribution[category.label] = finesPercentage * 0.8
            case categories.count - 1:
                // Last category gets most of the boulders
                distribution[category.label] = bouldersPercentage * 0.8
            case 2:
                // Middle/target category gets the most
                distribution[category.label] = middlePercentage * 0.5
            default:
                // Other categories share the rest
                distribution[category.label] = middlePercentage * 0.25
            }
        }
        
        return distribution
    }
}

// MARK: - Storable Analysis (for UserDefaults)

private struct StorableAnalysis: Codable {
    let id: UUID
    let name: String
    let grindType: CoffeeGrindType
    let uniformityScore: Double
    let averageSize: Double
    let medianSize: Double
    let standardDeviation: Double
    let finesPercentage: Double
    let bouldersPercentage: Double
    let particleCount: Int
    let confidence: Double
    let timestamp: Date
    let savedDate: Date
    let notes: String?
    let sizeDistribution: [String: Double]
    let tastingNotes: TastingNotes?
    let originalImagePath: String?
    let processedImagePath: String?
    let minParticleSize: Double?  // For chart domain calculation
    let maxParticleSize: Double?  // For chart domain calculation
    let granularDistribution: [String: Double]?  // For accurate chart reconstruction
    let chartDataPoints: [CoffeeAnalysisResults.ChartDataPoint]?  // Exact chart data for perfect reconstruction
    
    // Custom decoder to handle legacy data without sizeDistribution or tastingNotes
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        grindType = try container.decode(CoffeeGrindType.self, forKey: .grindType)
        uniformityScore = try container.decode(Double.self, forKey: .uniformityScore)
        averageSize = try container.decode(Double.self, forKey: .averageSize)
        medianSize = try container.decode(Double.self, forKey: .medianSize)
        standardDeviation = try container.decode(Double.self, forKey: .standardDeviation)
        finesPercentage = try container.decode(Double.self, forKey: .finesPercentage)
        bouldersPercentage = try container.decode(Double.self, forKey: .bouldersPercentage)
        particleCount = try container.decode(Int.self, forKey: .particleCount)
        confidence = try container.decode(Double.self, forKey: .confidence)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        savedDate = try container.decode(Date.self, forKey: .savedDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        // Try to decode sizeDistribution, fallback to empty if not present (legacy data)
        sizeDistribution = try container.decodeIfPresent([String: Double].self, forKey: .sizeDistribution) ?? [:]
        
        // Try to decode tastingNotes, fallback to nil if not present (legacy data)
        tastingNotes = try container.decodeIfPresent(TastingNotes.self, forKey: .tastingNotes)
        
        // Try to decode image paths, fallback to nil if not present (legacy data)
        originalImagePath = try container.decodeIfPresent(String.self, forKey: .originalImagePath)
        processedImagePath = try container.decodeIfPresent(String.self, forKey: .processedImagePath)
        
        // Try to decode particle size range, fallback to nil if not present (legacy data)
        minParticleSize = try container.decodeIfPresent(Double.self, forKey: .minParticleSize)
        maxParticleSize = try container.decodeIfPresent(Double.self, forKey: .maxParticleSize)
        
        // Try to decode granular distribution, fallback to nil if not present (legacy data)
        granularDistribution = try container.decodeIfPresent([String: Double].self, forKey: .granularDistribution)
        
        // Try to decode chart data points, fallback to nil if not present (legacy data)
        chartDataPoints = try container.decodeIfPresent([CoffeeAnalysisResults.ChartDataPoint].self, forKey: .chartDataPoints)
    }
    
    // Standard initializer for encoding
    init(id: UUID, name: String, grindType: CoffeeGrindType, uniformityScore: Double, averageSize: Double,
         medianSize: Double, standardDeviation: Double, finesPercentage: Double, bouldersPercentage: Double,
         particleCount: Int, confidence: Double, timestamp: Date, savedDate: Date, notes: String?,
         sizeDistribution: [String: Double], tastingNotes: TastingNotes?, originalImagePath: String?, processedImagePath: String?,
         minParticleSize: Double?, maxParticleSize: Double?, granularDistribution: [String: Double]?, 
         chartDataPoints: [CoffeeAnalysisResults.ChartDataPoint]?) {
        self.id = id
        self.name = name
        self.grindType = grindType
        self.uniformityScore = uniformityScore
        self.averageSize = averageSize
        self.medianSize = medianSize
        self.standardDeviation = standardDeviation
        self.finesPercentage = finesPercentage
        self.bouldersPercentage = bouldersPercentage
        self.particleCount = particleCount
        self.confidence = confidence
        self.timestamp = timestamp
        self.savedDate = savedDate
        self.notes = notes
        self.sizeDistribution = sizeDistribution
        self.tastingNotes = tastingNotes
        self.originalImagePath = originalImagePath
        self.processedImagePath = processedImagePath
        self.minParticleSize = minParticleSize
        self.maxParticleSize = maxParticleSize
        self.granularDistribution = granularDistribution
        self.chartDataPoints = chartDataPoints
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, grindType, uniformityScore, averageSize, medianSize, standardDeviation
        case finesPercentage, bouldersPercentage, particleCount, confidence, timestamp, savedDate, notes, sizeDistribution, tastingNotes
        case originalImagePath, processedImagePath, minParticleSize, maxParticleSize, granularDistribution, chartDataPoints
    }
}
