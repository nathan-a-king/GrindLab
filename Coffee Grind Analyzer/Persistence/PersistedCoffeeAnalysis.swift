import Foundation
import UIKit
import OSLog

struct PersistedCoffeeAnalysis: Codable, Identifiable {
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
    let originalImageFilename: String?
    let processedImageFilename: String?
    let minParticleSize: Double?
    let maxParticleSize: Double?
    let granularDistribution: [String: Double]?
    let chartDataPoints: [CoffeeAnalysisResults.ChartDataPoint]?

    init(savedAnalysis: SavedCoffeeAnalysis) {
        id = savedAnalysis.id
        name = savedAnalysis.name
        grindType = savedAnalysis.results.grindType
        uniformityScore = savedAnalysis.results.uniformityScore
        averageSize = savedAnalysis.results.averageSize
        medianSize = savedAnalysis.results.medianSize
        standardDeviation = savedAnalysis.results.standardDeviation
        finesPercentage = savedAnalysis.results.finesPercentage
        bouldersPercentage = savedAnalysis.results.bouldersPercentage
        particleCount = savedAnalysis.results.particleCount
        confidence = savedAnalysis.results.confidence
        timestamp = savedAnalysis.results.timestamp
        savedDate = savedAnalysis.savedDate
        notes = savedAnalysis.notes
        sizeDistribution = savedAnalysis.results.sizeDistribution
        tastingNotes = savedAnalysis.results.tastingNotes
        originalImageFilename = savedAnalysis.originalImagePath
        processedImageFilename = savedAnalysis.processedImagePath
        minParticleSize = savedAnalysis.results.minParticleSize
        maxParticleSize = savedAnalysis.results.maxParticleSize
        granularDistribution = savedAnalysis.results.granularDistribution
        chartDataPoints = savedAnalysis.results.chartDataPoints
    }

    init(id: UUID,
         name: String,
         grindType: CoffeeGrindType,
         uniformityScore: Double,
         averageSize: Double,
         medianSize: Double,
         standardDeviation: Double,
         finesPercentage: Double,
         bouldersPercentage: Double,
         particleCount: Int,
         confidence: Double,
         timestamp: Date,
         savedDate: Date,
         notes: String?,
         sizeDistribution: [String: Double],
         tastingNotes: TastingNotes?,
         originalImageFilename: String?,
         processedImageFilename: String?,
         minParticleSize: Double?,
         maxParticleSize: Double?,
         granularDistribution: [String: Double]?,
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
        self.originalImageFilename = originalImageFilename
        self.processedImageFilename = processedImageFilename
        self.minParticleSize = minParticleSize
        self.maxParticleSize = maxParticleSize
        self.granularDistribution = granularDistribution
        self.chartDataPoints = chartDataPoints
    }

    func makeSavedAnalysis(imageLoader: (String) -> UIImage?) -> SavedCoffeeAnalysis {
        let originalImage = originalImageFilename.flatMap(imageLoader)
        let processedImage = processedImageFilename.flatMap(imageLoader)

        let results = CoffeeAnalysisResults(
            uniformityScore: uniformityScore,
            averageSize: averageSize,
            medianSize: medianSize,
            standardDeviation: standardDeviation,
            finesPercentage: finesPercentage,
            bouldersPercentage: bouldersPercentage,
            particleCount: particleCount,
            particles: [],
            confidence: confidence,
            image: originalImage,
            processedImage: processedImage,
            grindType: grindType,
            timestamp: timestamp,
            sizeDistribution: normalizedDistribution(),
            calibrationFactor: 150.0,
            tastingNotes: tastingNotes,
            storedMinParticleSize: minParticleSize,
            storedMaxParticleSize: maxParticleSize,
            granularDistribution: granularDistribution,
            chartDataPoints: chartDataPoints
        )

        return SavedCoffeeAnalysis(
            id: id,
            name: name,
            results: results,
            savedDate: savedDate,
            notes: notes,
            originalImagePath: originalImageFilename,
            processedImagePath: processedImageFilename
        )
    }

    var imageFilenames: [String] {
        [originalImageFilename, processedImageFilename].compactMap { $0 }
    }

    private func normalizedDistribution() -> [String: Double] {
        if sizeDistribution.isEmpty || sizeDistribution.keys.contains("Fines (<400μm)") {
            let distribution = grindType.distributionCategories
            let middlePercentage = max(0, 100 - finesPercentage - bouldersPercentage)

            var generated: [String: Double] = [:]
            for (index, category) in distribution.enumerated() {
                switch index {
                case 0:
                    generated[category.label] = finesPercentage * 0.8
                case distribution.count - 1:
                    generated[category.label] = bouldersPercentage * 0.8
                case 2:
                    generated[category.label] = middlePercentage * 0.5
                default:
                    generated[category.label] = middlePercentage * 0.25
                }
            }
            return generated
        }

        return sizeDistribution
    }
}

struct LegacyPersistedCoffeeAnalysis: Codable {
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
    let minParticleSize: Double?
    let maxParticleSize: Double?
    let granularDistribution: [String: Double]?
    let chartDataPoints: [CoffeeAnalysisResults.ChartDataPoint]?

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
        sizeDistribution = try container.decodeIfPresent([String: Double].self, forKey: .sizeDistribution) ?? [:]
        tastingNotes = try container.decodeIfPresent(TastingNotes.self, forKey: .tastingNotes)
        originalImagePath = try container.decodeIfPresent(String.self, forKey: .originalImagePath)
        processedImagePath = try container.decodeIfPresent(String.self, forKey: .processedImagePath)
        minParticleSize = try container.decodeIfPresent(Double.self, forKey: .minParticleSize)
        maxParticleSize = try container.decodeIfPresent(Double.self, forKey: .maxParticleSize)
        granularDistribution = try container.decodeIfPresent([String: Double].self, forKey: .granularDistribution)
        chartDataPoints = try container.decodeIfPresent([CoffeeAnalysisResults.ChartDataPoint].self, forKey: .chartDataPoints)
    }

    func toPersisted(withImageMapper mapper: (String) -> String?) -> PersistedCoffeeAnalysis {
        let mappedOriginal = originalImagePath.flatMap(mapper)
        let mappedProcessed = processedImagePath.flatMap(mapper)

        return PersistedCoffeeAnalysis(
            id: id,
            name: name,
            grindType: grindType,
            uniformityScore: uniformityScore,
            averageSize: averageSize,
            medianSize: medianSize,
            standardDeviation: standardDeviation,
            finesPercentage: finesPercentage,
            bouldersPercentage: bouldersPercentage,
            particleCount: particleCount,
            confidence: confidence,
            timestamp: timestamp,
            savedDate: savedDate,
            notes: notes,
            sizeDistribution: sizeDistribution,
            tastingNotes: tastingNotes,
            originalImageFilename: mappedOriginal,
            processedImageFilename: mappedProcessed,
            minParticleSize: minParticleSize,
            maxParticleSize: maxParticleSize,
            granularDistribution: granularDistribution,
            chartDataPoints: chartDataPoints
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, grindType, uniformityScore, averageSize, medianSize, standardDeviation
        case finesPercentage, bouldersPercentage, particleCount, confidence, timestamp, savedDate, notes, sizeDistribution
        case tastingNotes, originalImagePath, processedImagePath, minParticleSize, maxParticleSize, granularDistribution, chartDataPoints
    }
}
