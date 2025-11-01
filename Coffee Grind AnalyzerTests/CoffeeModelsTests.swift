//
//  CoffeeModelsTests.swift
//  Coffee Grind AnalyzerTests
//
//  Tests for business logic in models
//

import Testing
import SwiftUI
@testable import GrindLab

@MainActor
struct CoffeeModelsTests {

    // MARK: - CoffeeGrindType Tests

    @Test func testGrindType_Espresso_CorrectTargetRange() {
        let grindType = CoffeeGrindType.espresso

        #expect(grindType.targetSizeRange == "170-300μm")
        #expect(grindType.targetSizeMicrons == 170...300)
        #expect(grindType.displayName == "Espresso")
    }

    @Test func testGrindType_Filter_CorrectTargetRange() {
        let grindType = CoffeeGrindType.filter

        #expect(grindType.targetSizeRange == "400-800μm")
        #expect(grindType.targetSizeMicrons == 400...800)
        #expect(grindType.displayName == "Filter/Pour-Over")
    }

    @Test func testGrindType_FrenchPress_CorrectTargetRange() {
        let grindType = CoffeeGrindType.frenchPress

        #expect(grindType.targetSizeRange == "750-1000μm")
        #expect(grindType.targetSizeMicrons == 750...1000)
        #expect(grindType.displayName == "French Press")
    }

    @Test func testGrindType_ColdBrew_CorrectTargetRange() {
        let grindType = CoffeeGrindType.coldBrew

        #expect(grindType.targetSizeRange == "800-1200μm")
        #expect(grindType.targetSizeMicrons == 800...1200)
        #expect(grindType.displayName == "Cold Brew")
    }

    @Test func testGrindType_AllTypes_HaveConsistentTargetRanges() {
        // Verify all grind types have properly defined target ranges
        for grindType in CoffeeGrindType.allCases {
            // Target range string should match the numeric range
            let numericRange = grindType.targetSizeMicrons
            let stringRange = grindType.targetSizeRange

            // Verify numeric range is valid
            #expect(numericRange.lowerBound > 0)
            #expect(numericRange.upperBound > numericRange.lowerBound)

            // Verify string representation contains both bounds
            #expect(stringRange.contains("\(Int(numericRange.lowerBound))"))
            #expect(stringRange.contains("\(Int(numericRange.upperBound))"))
            #expect(stringRange.contains("μm"))
        }
    }

    @Test func testGrindType_TargetRanges_AreOrdered() {
        // Verify grind types progress from fine to coarse
        let espresso = CoffeeGrindType.espresso.targetSizeMicrons
        let filter = CoffeeGrindType.filter.targetSizeMicrons
        let frenchPress = CoffeeGrindType.frenchPress.targetSizeMicrons
        let coldBrew = CoffeeGrindType.coldBrew.targetSizeMicrons

        // Espresso should be finest
        #expect(espresso.lowerBound < filter.lowerBound)
        #expect(espresso.upperBound < filter.upperBound)

        // Filter should be medium
        #expect(filter.lowerBound < frenchPress.lowerBound)

        // French press and cold brew should be coarsest
        #expect(frenchPress.lowerBound > filter.upperBound)
        #expect(coldBrew.lowerBound > filter.upperBound)
    }

    @Test func testGrindType_TargetRanges_MapToCorrectSizes() {
        // Verify the target ranges map to scientifically accurate size ranges
        #expect(CoffeeGrindType.espresso.targetSizeMicrons.contains(250.0))
        #expect(CoffeeGrindType.filter.targetSizeMicrons.contains(600.0))
        #expect(CoffeeGrindType.frenchPress.targetSizeMicrons.contains(850.0))
        #expect(CoffeeGrindType.coldBrew.targetSizeMicrons.contains(1000.0))

        // Verify ranges don't overlap inappropriately
        #expect(!CoffeeGrindType.espresso.targetSizeMicrons.contains(600.0))
        #expect(!CoffeeGrindType.frenchPress.targetSizeMicrons.contains(250.0))
    }

    @Test func testGrindType_IdealFinesPercentage_ReasonableRanges() {
        // Espresso should tolerate more fines
        #expect(CoffeeGrindType.espresso.idealFinesPercentage.upperBound > 30)

        // French press should have lower fines tolerance
        #expect(CoffeeGrindType.frenchPress.idealFinesPercentage.upperBound < 20)

        // All should have positive ranges
        for grindType in CoffeeGrindType.allCases {
            #expect(grindType.idealFinesPercentage.lowerBound >= 0)
            #expect(grindType.idealFinesPercentage.upperBound <= 100)
            #expect(grindType.idealFinesPercentage.lowerBound < grindType.idealFinesPercentage.upperBound)
        }
    }

    @Test func testGrindType_DistributionCategories_HasExpectedCount() {
        for grindType in CoffeeGrindType.allCases {
            let categories = grindType.distributionCategories

            // Should have 5 categories
            #expect(categories.count == 5)

            // Categories should cover increasing ranges
            for i in 0..<(categories.count - 1) {
                #expect(categories[i].range.lowerBound < categories[i + 1].range.lowerBound)
            }
        }
    }

    @Test func testGrindType_ParticleColor_ReturnsValidColors() {
        let grindType = CoffeeGrindType.filter

        // Test sizes across the range
        let testSizes = [100.0, 300.0, 500.0, 700.0, 900.0, 1200.0]

        for size in testSizes {
            let (color, alpha) = grindType.particleColor(for: size)

            // Should return valid color names
            #expect(["red", "orange", "yellow", "green", "blue", "purple"].contains(color))

            // Alpha should be reasonable
            #expect(alpha > 0.0)
            #expect(alpha <= 1.0)
        }
    }

    @Test func testGrindType_ImageLegendItems_ReturnsExpectedCount() {
        for grindType in CoffeeGrindType.allCases {
            let legendItems = grindType.imageLegendItems

            // Should have 5 legend items (one per category)
            #expect(legendItems.count == 5)

            // Each should have a label and color
            for item in legendItems {
                #expect(!item.label.isEmpty)
                #expect(!item.color.isEmpty)
            }
        }
    }

    // MARK: - CoffeeAnalysisResults Tests

    @Test func testAnalysisResults_UniformityColor_CorrectMapping() {
        // Create test results with different uniformity scores
        let highUniformity = createTestResults(uniformityScore: 80.0)
        let mediumUniformity = createTestResults(uniformityScore: 60.0)
        let lowUniformity = createTestResults(uniformityScore: 30.0)

        #expect(highUniformity.uniformityColor == .green)
        #expect(mediumUniformity.uniformityColor == .yellow)
        #expect(lowUniformity.uniformityColor == .red)
    }

    @Test func testAnalysisResults_UniformityGrade_CorrectLabels() {
        let excellent = createTestResults(uniformityScore: 85.0)
        let veryGood = createTestResults(uniformityScore: 70.0)
        let good = createTestResults(uniformityScore: 60.0)
        let fair = createTestResults(uniformityScore: 50.0)
        let poor = createTestResults(uniformityScore: 40.0)
        let veryPoor = createTestResults(uniformityScore: 20.0)

        #expect(excellent.uniformityGrade == "Excellent")
        #expect(veryGood.uniformityGrade == "Very Good")
        #expect(good.uniformityGrade == "Good")
        #expect(fair.uniformityGrade == "Fair")
        #expect(poor.uniformityGrade == "Poor")
        #expect(veryPoor.uniformityGrade == "Very Poor")
    }

    @Test func testAnalysisResults_Recommendations_TooFine() {
        // Grind too fine for filter (target: 400-800, actual: 300)
        let results = createTestResults(
            uniformityScore: 70.0,
            averageSize: 300.0,
            grindType: .filter
        )

        let recommendations = results.recommendations

        #expect(!recommendations.isEmpty)
        #expect(recommendations.contains { $0.contains("coarser") })
    }

    @Test func testAnalysisResults_Recommendations_TooCoarse() {
        // Grind too coarse for espresso (target: 170-300, actual: 500)
        let results = createTestResults(
            uniformityScore: 70.0,
            averageSize: 500.0,
            grindType: .espresso
        )

        let recommendations = results.recommendations

        #expect(!recommendations.isEmpty)
        #expect(recommendations.contains { $0.contains("finer") })
    }

    @Test func testAnalysisResults_Recommendations_WellSuited() {
        // Grind well-suited for filter (target: 400-800, actual: 600)
        let results = createTestResults(
            uniformityScore: 75.0,
            averageSize: 600.0,
            finesPercentage: 15.0,
            grindType: .filter
        )

        let recommendations = results.recommendations

        #expect(recommendations.contains { $0.contains("well-suited") })
    }

    @Test func testAnalysisResults_Recommendations_HighFines() {
        // High fines for filter (ideal: 10-25%, actual: 40%)
        let results = createTestResults(
            uniformityScore: 70.0,
            averageSize: 600.0,
            finesPercentage: 40.0,
            grindType: .filter
        )

        let recommendations = results.recommendations

        #expect(recommendations.contains { $0.contains("fines") || $0.contains("coarser") })
    }

    @Test func testAnalysisResults_Recommendations_LowUniformity() {
        let results = createTestResults(
            uniformityScore: 40.0
        )

        let recommendations = results.recommendations

        #expect(recommendations.contains { $0.contains("burr grinder") || $0.contains("uniformity") })
    }

    @Test func testAnalysisResults_Recommendations_HighBoulders() {
        let results = createTestResults(
            bouldersPercentage: 15.0
        )

        let recommendations = results.recommendations

        #expect(recommendations.contains { $0.contains("boulders") || $0.contains("burrs") })
    }

    // MARK: - TastingNotes Tests

    @Test func testTastingNotes_BrewMethods_AllHaveIcons() {
        for method in TastingNotes.BrewMethod.allCases {
            #expect(!method.icon.isEmpty)
            #expect(!method.rawValue.isEmpty)
        }
    }

    @Test func testTastingNotes_OverallTaste_HasDescriptions() {
        for taste in FlavorProfile.OverallTaste.allCases {
            #expect(!taste.description.isEmpty)
        }
    }

    @Test func testTastingNotes_FlavorIssue_ExtractionRelated() {
        // Under-extraction indicators
        #expect(FlavorProfile.FlavorIssue.sour.isExtractionRelated)
        #expect(FlavorProfile.FlavorIssue.weak.isExtractionRelated)
        #expect(FlavorProfile.FlavorIssue.acidic.isExtractionRelated)

        // Over-extraction indicators
        #expect(FlavorProfile.FlavorIssue.bitter.isExtractionRelated)
        #expect(FlavorProfile.FlavorIssue.astringent.isExtractionRelated)

        // Equipment-related (not extraction)
        #expect(!FlavorProfile.FlavorIssue.muddy.isExtractionRelated)
        #expect(!FlavorProfile.FlavorIssue.flat.isExtractionRelated)
    }

    @Test func testTastingNotes_Codable_RoundTrip() throws {
        let originalNotes = TastingNotes(
            brewMethod: .espresso,
            overallRating: 4,
            tastingTags: ["Balanced", "Fruity", "Bright"],
            extractionNotes: "Good extraction, slightly fast",
            extractionTime: 28.5,
            waterTemp: 93.0,
            doseIn: 18.0,
            yieldOut: 36.0
        )

        let encoded = try JSONEncoder().encode(originalNotes)
        let decoded = try JSONDecoder().decode(TastingNotes.self, from: encoded)

        #expect(decoded.brewMethod == originalNotes.brewMethod)
        #expect(decoded.overallRating == originalNotes.overallRating)
        #expect(decoded.tastingTags == originalNotes.tastingTags)
        #expect(decoded.extractionNotes == originalNotes.extractionNotes)
        #expect(decoded.extractionTime == originalNotes.extractionTime)
        #expect(decoded.waterTemp == originalNotes.waterTemp)
        #expect(decoded.doseIn == originalNotes.doseIn)
        #expect(decoded.yieldOut == originalNotes.yieldOut)
    }

    // MARK: - BrewingRecommendation Tests

    @Test func testBrewingRecommendation_GrindAdjustment_DisplayText() {
        let slightly = BrewingRecommendation.RecommendationAction.grindFiner(amount: .slightly)
        let moderately = BrewingRecommendation.RecommendationAction.grindCoarser(amount: .moderately)
        let significantly = BrewingRecommendation.RecommendationAction.grindFiner(amount: .significantly)

        #expect(slightly.displayText.contains("slightly"))
        #expect(moderately.displayText.contains("moderately"))
        #expect(significantly.displayText.contains("significantly"))
    }

    @Test func testBrewingRecommendation_Actions_HaveIcons() {
        let actions: [BrewingRecommendation.RecommendationAction] = [
            .grindFiner(amount: .slightly),
            .grindCoarser(amount: .slightly),
            .increaseDose(grams: nil),
            .decreaseDose(grams: nil),
            .increaseBrewTime(seconds: nil),
            .decreaseBrewTime(seconds: nil),
            .increaseWaterTemp(celsius: nil),
            .decreaseWaterTemp(celsius: nil),
            .improveGrinderUniformity,
            .checkWaterQuality,
            .useFresherBeans,
            .maintainCurrentSettings
        ]

        for action in actions {
            #expect(!action.icon.isEmpty)
            #expect(!action.displayText.isEmpty)
        }
    }

    @Test func testBrewingRecommendation_Codable_RoundTrip() throws {
        let originalRec = BrewingRecommendation(
            primaryAction: .grindFiner(amount: .slightly),
            secondaryActions: [
                .increaseBrewTime(seconds: 10),
                .increaseWaterTemp(celsius: 92)
            ],
            reasoning: "Under-extracted based on taste profile",
            expectedImprovement: "Should increase sweetness and body",
            confidence: 85.0,
            grindAnalysisFactors: ["High uniformity", "Target size range"]
        )

        let encoded = try JSONEncoder().encode(originalRec)
        let decoded = try JSONDecoder().decode(BrewingRecommendation.self, from: encoded)

        #expect(decoded.primaryAction == originalRec.primaryAction)
        #expect(decoded.secondaryActions.count == originalRec.secondaryActions.count)
        #expect(decoded.reasoning == originalRec.reasoning)
        #expect(decoded.confidence == originalRec.confidence)
    }

    // MARK: - AnalysisSettings Tests

    @Test func testAnalysisSettings_Defaults_ReasonableValues() {
        let settings = AnalysisSettings()

        #expect(settings.analysisMode == .standard)
        #expect(settings.contrastThreshold > 0 && settings.contrastThreshold < 1)
        #expect(settings.minParticleSize > 0)
        #expect(settings.maxParticleSize > settings.minParticleSize)
        #expect(settings.calibrationFactor > 0)
        #expect(settings.minCircularity >= 0 && settings.minCircularity <= 1)
    }

    @Test func testAnalysisSettings_AnalysisMode_AllCasesHaveNames() {
        for mode in AnalysisSettings.AnalysisMode.allCases {
            #expect(!mode.displayName.isEmpty)
        }
    }

    // MARK: - Helper Methods

    private func createTestResults(
        uniformityScore: Double = 70.0,
        averageSize: Double = 500.0,
        medianSize: Double = 500.0,
        standardDeviation: Double = 100.0,
        finesPercentage: Double = 15.0,
        bouldersPercentage: Double = 5.0,
        grindType: CoffeeGrindType = .filter
    ) -> CoffeeAnalysisResults {
        return CoffeeAnalysisResults(
            uniformityScore: uniformityScore,
            averageSize: averageSize,
            medianSize: medianSize,
            standardDeviation: standardDeviation,
            finesPercentage: finesPercentage,
            bouldersPercentage: bouldersPercentage,
            particleCount: 100,
            particles: [],
            confidence: 80.0,
            image: nil,
            processedImage: nil,
            grindType: grindType,
            timestamp: Date(),
            calibrationFactor: 150.0
        )
    }
}
