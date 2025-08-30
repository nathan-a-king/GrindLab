//
//  CoffeeCompass.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/29/25.
//

import Foundation
import SwiftUI

class CoffeeCompass {
    
    static func generateRecommendations(
        from analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) -> [BrewingRecommendation] {
        var recommendations: [BrewingRecommendation] = []
        
        // Primary recommendation based on overall taste
        if let primaryRec = generatePrimaryRecommendation(
            analysisResults: analysisResults,
            flavorProfile: flavorProfile
        ) {
            recommendations.append(primaryRec)
        }
        
        // Secondary recommendations based on grind analysis
        let grindRecs = generateGrindBasedRecommendations(
            analysisResults: analysisResults,
            flavorProfile: flavorProfile
        )
        recommendations.append(contentsOf: grindRecs)
        
        // Equipment recommendations if needed
        if let equipmentRec = generateEquipmentRecommendation(
            analysisResults: analysisResults,
            flavorProfile: flavorProfile
        ) {
            recommendations.append(equipmentRec)
        }
        
        // Ensure we always return at least one recommendation
        if recommendations.isEmpty {
            recommendations.append(generateDefaultRecommendation(
                analysisResults: analysisResults,
                flavorProfile: flavorProfile
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Primary Recommendation Logic
    
    private static func generatePrimaryRecommendation(
        analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) -> BrewingRecommendation? {
        
        switch flavorProfile.overallTaste {
        case .underExtracted:
            return generateUnderExtractionRecommendation(
                analysisResults: analysisResults,
                flavorProfile: flavorProfile
            )
        case .overExtracted:
            return generateOverExtractionRecommendation(
                analysisResults: analysisResults,
                flavorProfile: flavorProfile
            )
        case .weak:
            return generateWeakCoffeeRecommendation(
                analysisResults: analysisResults,
                flavorProfile: flavorProfile
            )
        case .harsh:
            return generateHarshCoffeeRecommendation(
                analysisResults: analysisResults,
                flavorProfile: flavorProfile
            )
        case .balanced:
            return nil // No primary recommendation needed for balanced coffee
        }
    }
    
    private static func generateUnderExtractionRecommendation(
        analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) -> BrewingRecommendation {
        let targetRange = analysisResults.grindType.targetSizeMicrons
        let avgSize = analysisResults.averageSize
        let uniformity = analysisResults.uniformityScore
        
        // Coffee Compass: Under-extraction = "Extract More"
        // Primary solutions: Finer grind and/or longer brew time
        let grindAdjustment: BrewingRecommendation.GrindAdjustment
        let primaryAction: BrewingRecommendation.RecommendationAction
        var secondaryActions: [BrewingRecommendation.RecommendationAction] = []
        
        if avgSize > targetRange.upperBound * 1.2 {
            // Significantly too coarse - primary issue
            grindAdjustment = .significantly
            primaryAction = .grindFiner(amount: grindAdjustment)
            secondaryActions = [
                .increaseBrewTime(seconds: 30),
                .increaseWaterTemp(celsius: 3.0)
            ]
        } else if avgSize > targetRange.upperBound {
            // Moderately too coarse
            grindAdjustment = .moderately
            primaryAction = .grindFiner(amount: grindAdjustment)
            secondaryActions = [.increaseBrewTime(seconds: 20)]
        } else {
            // Size is in range - focus on other extraction parameters
            grindAdjustment = .slightly
            primaryAction = .grindFiner(amount: grindAdjustment)
            
            // Coffee Compass: If grind is adequate, increase contact time or temperature
            if analysisResults.grindType == .espresso {
                secondaryActions = [.increaseWaterTemp(celsius: 2.0)]
            } else {
                secondaryActions = [
                    .increaseBrewTime(seconds: 30),
                    .increaseWaterTemp(celsius: 3.0)
                ]
            }
        }
        
        let compassGuidance = "☕️ Coffee Compass: EXTRACT MORE"
        let reasoning = """
        \(compassGuidance)
        Your coffee shows under-extraction with sour, weak, or incomplete flavors. 
        Average grind size: \(String(format: "%.0f", avgSize))μm (target: \(Int(targetRange.lowerBound))-\(Int(targetRange.upperBound))μm).
        
        Following the Coffee Compass: increase extraction through finer grind and/or longer brew time to extract more soluble compounds and achieve better balance.
        """
        
        let expectedImprovement = "Increased sweetness, better balance, fuller body, reduced sourness"
        
        let confidence = calculateConfidence(
            uniformity: uniformity,
            sizeDeviation: abs(avgSize - (targetRange.lowerBound + targetRange.upperBound) / 2),
            flavorIssues: flavorProfile.flavorIssues
        )
        
        return BrewingRecommendation(
            primaryAction: primaryAction,
            secondaryActions: secondaryActions,
            reasoning: reasoning,
            expectedImprovement: expectedImprovement,
            confidence: confidence,
            grindAnalysisFactors: [
                "Average size: \(String(format: "%.0f", avgSize))μm",
                "Uniformity: \(String(format: "%.1f", uniformity))%",
                "Fines: \(String(format: "%.1f", analysisResults.finesPercentage))%"
            ]
        )
    }
    
    private static func generateOverExtractionRecommendation(
        analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) -> BrewingRecommendation {
        let targetRange = analysisResults.grindType.targetSizeMicrons
        let avgSize = analysisResults.averageSize
        let uniformity = analysisResults.uniformityScore
        let finesPercentage = analysisResults.finesPercentage
        
        // Coffee Compass: Over-extraction = "Extract Less"
        // Primary solutions: Coarser grind and/or shorter brew time
        let grindAdjustment: BrewingRecommendation.GrindAdjustment
        let primaryAction: BrewingRecommendation.RecommendationAction
        var secondaryActions: [BrewingRecommendation.RecommendationAction] = []
        
        if avgSize < targetRange.lowerBound * 0.8 {
            // Significantly too fine - major contributor to over-extraction
            grindAdjustment = .significantly
            primaryAction = .grindCoarser(amount: grindAdjustment)
            secondaryActions = [
                .decreaseBrewTime(seconds: 30),
                .decreaseWaterTemp(celsius: 4.0)
            ]
        } else if avgSize < targetRange.lowerBound {
            // Moderately too fine
            grindAdjustment = .moderately
            primaryAction = .grindCoarser(amount: grindAdjustment)
            secondaryActions = [.decreaseBrewTime(seconds: 20)]
        } else if finesPercentage > analysisResults.grindType.idealFinesPercentage.upperBound * 1.5 {
            // Excessive fines causing over-extraction despite good average size
            grindAdjustment = .moderately
            primaryAction = .grindCoarser(amount: grindAdjustment)
            secondaryActions = [.decreaseWaterTemp(celsius: 4.0)]
        } else {
            // Size looks good - focus on reducing extraction through other parameters
            grindAdjustment = .slightly
            primaryAction = .grindCoarser(amount: grindAdjustment)
            
            // Coffee Compass: Reduce extraction through shorter contact time or lower temperature
            if analysisResults.grindType == .espresso {
                secondaryActions = [.decreaseWaterTemp(celsius: 3.0)]
            } else {
                secondaryActions = [
                    .decreaseBrewTime(seconds: 30),
                    .decreaseWaterTemp(celsius: 3.0)
                ]
            }
        }
        
        let compassGuidance = "☕️ Coffee Compass: EXTRACT LESS"
        let reasoning = """
        \(compassGuidance)
        Your coffee shows over-extraction with bitter, astringent, or harsh flavors. 
        Average grind size: \(String(format: "%.0f", avgSize))μm, Fines: \(String(format: "%.1f", finesPercentage))%.
        
        Following the Coffee Compass: reduce extraction through coarser grind and/or shorter brew time to prevent extracting undesirable bitter compounds.
        """
        
        let expectedImprovement = "Reduced bitterness, smoother taste, better balance, cleaner finish"
        
        let confidence = calculateConfidence(
            uniformity: uniformity,
            sizeDeviation: abs(avgSize - (targetRange.lowerBound + targetRange.upperBound) / 2),
            flavorIssues: flavorProfile.flavorIssues
        )
        
        return BrewingRecommendation(
            primaryAction: primaryAction,
            secondaryActions: secondaryActions,
            reasoning: reasoning,
            expectedImprovement: expectedImprovement,
            confidence: confidence,
            grindAnalysisFactors: [
                "Average size: \(String(format: "%.0f", avgSize))μm",
                "Uniformity: \(String(format: "%.1f", uniformity))%",
                "Fines: \(String(format: "%.1f", finesPercentage))%"
            ]
        )
    }
    
    private static func generateWeakCoffeeRecommendation(
        analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) -> BrewingRecommendation {
        let avgSize = analysisResults.averageSize
        let uniformity = analysisResults.uniformityScore
        let targetRange = analysisResults.grindType.targetSizeMicrons
        
        // Coffee Compass: Weak coffee = "More Coffee" (increase brew ratio)
        // Primary solution: Increase coffee dose or decrease water amount
        let primaryAction: BrewingRecommendation.RecommendationAction = .increaseDose(grams: 3.0)
        var secondaryActions: [BrewingRecommendation.RecommendationAction] = []
        
        // Additional extraction improvements if grind allows
        if avgSize > targetRange.upperBound {
            // Grind is also too coarse - can help with both strength and extraction
            secondaryActions = [
                .grindFiner(amount: .moderately),
                .increaseBrewTime(seconds: 15)
            ]
        } else {
            // Grind size is reasonable - focus on ratio and minor extraction tweaks
            secondaryActions = [
                .grindFiner(amount: .slightly),
                .increaseBrewTime(seconds: 20)
            ]
        }
        
        let compassGuidance = "☕️ Coffee Compass: MORE COFFEE"
        let reasoning = """
        \(compassGuidance)
        Your coffee lacks strength and body, indicating insufficient coffee-to-water ratio. 
        Average grind size: \(String(format: "%.0f", avgSize))μm (target: \(Int(targetRange.lowerBound))-\(Int(targetRange.upperBound))μm).
        
        Following the Coffee Compass: increase brew ratio by using more coffee or less water to achieve proper strength and body.
        """
        
        let expectedImprovement = "Fuller body, stronger flavors, better intensity, improved mouthfeel"
        
        let confidence = calculateConfidence(
            uniformity: uniformity,
            sizeDeviation: 0, // Not primarily a size-related issue
            flavorIssues: flavorProfile.flavorIssues
        )
        
        return BrewingRecommendation(
            primaryAction: primaryAction,
            secondaryActions: secondaryActions,
            reasoning: reasoning,
            expectedImprovement: expectedImprovement,
            confidence: confidence,
            grindAnalysisFactors: [
                "Average size: \(String(format: "%.0f", avgSize))μm",
                "Uniformity: \(String(format: "%.1f", uniformity))%"
            ]
        )
    }
    
    private static func generateHarshCoffeeRecommendation(
        analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) -> BrewingRecommendation {
        let uniformity = analysisResults.uniformityScore
        let finesPercentage = analysisResults.finesPercentage
        let avgSize = analysisResults.averageSize
        let targetRange = analysisResults.grindType.targetSizeMicrons
        
        // Coffee Compass: Harsh coffee = "Less Coffee" (decrease brew ratio)
        // But also consider grind uniformity and other extraction factors
        let primaryAction: BrewingRecommendation.RecommendationAction
        var secondaryActions: [BrewingRecommendation.RecommendationAction] = []
        
        if uniformity < 45 {
            // Poor grind uniformity is the primary cause of harshness
            primaryAction = .improveGrinderUniformity
            secondaryActions = [
                .grindCoarser(amount: .slightly),
                .decreaseWaterTemp(celsius: 4.0),
                .decreaseDose(grams: 2.0)
            ]
        } else if finesPercentage > analysisResults.grindType.idealFinesPercentage.upperBound * 1.5 {
            // Excessive fines causing harsh over-extraction
            primaryAction = .grindCoarser(amount: .moderately)
            secondaryActions = [
                .decreaseWaterTemp(celsius: 3.0),
                .decreaseDose(grams: 1.5)
            ]
        } else if avgSize < targetRange.lowerBound {
            // Grind too fine contributing to harshness
            primaryAction = .grindCoarser(amount: .moderately)
            secondaryActions = [
                .decreaseWaterTemp(celsius: 3.0),
                .decreaseDose(grams: 1.0)
            ]
        } else {
            // Coffee Compass: Reduce brew ratio as primary solution
            primaryAction = .decreaseDose(grams: 2.5)
            secondaryActions = [
                .decreaseWaterTemp(celsius: 4.0),
                .checkWaterQuality,
                .useFresherBeans
            ]
        }
        
        let compassGuidance = "☕️ Coffee Compass: LESS COFFEE"
        let reasoning = """
        \(compassGuidance)
        Your coffee tastes harsh, astringent, or unpleasantly sharp. 
        Grind uniformity: \(String(format: "%.1f", uniformity))%, Fines: \(String(format: "%.1f", finesPercentage))%.
        
        Following the Coffee Compass: harsh flavors often result from too strong a brew ratio combined with uneven extraction. Reduce coffee dose and address grind uniformity for smoother results.
        """
        
        let expectedImprovement = "Smoother taste, reduced harshness, better clarity, more balanced flavors"
        
        let confidence = calculateConfidence(
            uniformity: uniformity,
            sizeDeviation: abs(avgSize - (targetRange.lowerBound + targetRange.upperBound) / 2),
            flavorIssues: flavorProfile.flavorIssues
        )
        
        return BrewingRecommendation(
            primaryAction: primaryAction,
            secondaryActions: secondaryActions,
            reasoning: reasoning,
            expectedImprovement: expectedImprovement,
            confidence: confidence,
            grindAnalysisFactors: [
                "Average size: \(String(format: "%.0f", avgSize))μm",
                "Uniformity: \(String(format: "%.1f", uniformity))%",
                "Fines: \(String(format: "%.1f", finesPercentage))%"
            ]
        )
    }
    
    // MARK: - Secondary Recommendations
    
    private static func generateGrindBasedRecommendations(
        analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) -> [BrewingRecommendation] {
        var recommendations: [BrewingRecommendation] = []
        
        // Check if grind size is significantly off target
        let targetRange = analysisResults.grindType.targetSizeMicrons
        let avgSize = analysisResults.averageSize
        let targetCenter = (targetRange.lowerBound + targetRange.upperBound) / 2
        let sizeDeviation = abs(avgSize - targetCenter) / targetCenter
        
        if sizeDeviation > 0.3 && flavorProfile.overallTaste == .balanced {
            // Size is significantly off but taste is balanced - suggest optimization
            let action: BrewingRecommendation.RecommendationAction = avgSize > targetCenter ?
                .grindFiner(amount: .moderately) : .grindCoarser(amount: .moderately)
            
            let rec = BrewingRecommendation(
                primaryAction: action,
                secondaryActions: [],
                reasoning: "Your grind size (\(String(format: "%.0f", avgSize))μm) is outside the optimal range for \(analysisResults.grindType.displayName). Adjusting closer to the target range may improve extraction consistency.",
                expectedImprovement: "More consistent extraction, potential flavor improvement",
                confidence: 70,
                grindAnalysisFactors: ["Size deviation: \(String(format: "%.1f", sizeDeviation * 100))%"]
            )
            
            recommendations.append(rec)
        }
        
        return recommendations
    }
    
    private static func generateEquipmentRecommendation(
        analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) -> BrewingRecommendation? {
        let uniformity = analysisResults.uniformityScore
        
        // Recommend grinder upgrade if uniformity is poor
        if uniformity < 45 {
            return BrewingRecommendation(
                primaryAction: .improveGrinderUniformity,
                secondaryActions: [],
                reasoning: "Your grind uniformity score is \(String(format: "%.1f", uniformity))%, which indicates inconsistent particle sizes. This can lead to uneven extraction where some particles are over-extracted while others are under-extracted.",
                expectedImprovement: "More even extraction, better flavor balance, reduced bitterness and sourness",
                confidence: 90,
                grindAnalysisFactors: [
                    "Uniformity: \(String(format: "%.1f", uniformity))%",
                    "Standard deviation: \(String(format: "%.1f", analysisResults.standardDeviation))μm"
                ]
            )
        }
        
        return nil
    }
    
    // MARK: - Default Recommendation
    
    private static func generateDefaultRecommendation(
        analysisResults: CoffeeAnalysisResults,
        flavorProfile: FlavorProfile
    ) -> BrewingRecommendation {
        // Provide a general recommendation based on grind analysis alone
        let targetRange = analysisResults.grindType.targetSizeMicrons
        let avgSize = analysisResults.averageSize
        let uniformity = analysisResults.uniformityScore
        
        var primaryAction: BrewingRecommendation.RecommendationAction
        var reasoning: String
        
        if !targetRange.contains(avgSize) {
            // Size is off target
            if avgSize < targetRange.lowerBound {
                primaryAction = .grindCoarser(amount: .moderately)
                reasoning = "Your grind is finer than the target range for \(analysisResults.grindType.displayName). Grinding coarser will help achieve the optimal extraction."
            } else {
                primaryAction = .grindFiner(amount: .moderately)
                reasoning = "Your grind is coarser than the target range for \(analysisResults.grindType.displayName). Grinding finer will improve extraction."
            }
        } else if uniformity < 50 {
            // Poor uniformity
            primaryAction = .improveGrinderUniformity
            reasoning = "Your grind uniformity is low, which can lead to uneven extraction. Consider upgrading your grinder for better consistency."
        } else {
            // Everything looks good
            primaryAction = .grindFiner(amount: .slightly)
            reasoning = "Your grind looks good for \(analysisResults.grindType.displayName). Minor adjustments can be made based on taste preference."
        }
        
        return BrewingRecommendation(
            primaryAction: primaryAction,
            secondaryActions: [],
            reasoning: reasoning,
            expectedImprovement: "Better extraction and flavor balance",
            confidence: 75,
            grindAnalysisFactors: [
                "Average size: \(String(format: "%.0f", avgSize))μm",
                "Uniformity: \(String(format: "%.1f", uniformity))%"
            ]
        )
    }
    
    // MARK: - Helper Methods
    
    private static func calculateConfidence(
        uniformity: Double,
        sizeDeviation: Double,
        flavorIssues: [FlavorProfile.FlavorIssue]
    ) -> Double {
        var confidence: Double = 80 // Base confidence
        
        // Higher uniformity increases confidence
        if uniformity > 70 {
            confidence += 10
        } else if uniformity < 50 {
            confidence -= 15
        }
        
        // Clear extraction-related issues increase confidence
        let extractionIssues = flavorIssues.filter { $0.isExtractionRelated }
        if extractionIssues.count >= 2 {
            confidence += 10
        }
        
        // Large size deviations increase confidence in size-based recommendations
        if sizeDeviation > 200 { // 200+ micron deviation
            confidence += 5
        }
        
        return min(max(confidence, 60), 95) // Clamp between 60-95%
    }
}

// MARK: - Convenience Extensions

extension CoffeeAnalysisResults {
    func generateImprovementRecommendations(flavorProfile: FlavorProfile) -> [BrewingRecommendation] {
        return CoffeeCompass.generateRecommendations(from: self, flavorProfile: flavorProfile)
    }
}