//
//  AdvancedStatisticsTests.swift
//  Coffee Grind AnalyzerTests
//
//  Tests for statistical calculations
//

import Testing
import Foundation
@testable import GrindLab

struct AdvancedStatisticsTests {

    let stats = AdvancedStatistics()

    // MARK: - Weighted Mean Tests

    @Test func testWeightedMean_EqualWeights_MatchesSimpleMean() {
        let values = [10.0, 20.0, 30.0, 40.0]
        let weights = [1.0, 1.0, 1.0, 1.0]

        let result = stats.calculateWeightedMean(values: values, weights: weights)
        let expected = 25.0 // (10+20+30+40)/4

        #expect(abs(result - expected) < 0.001)
    }

    @Test func testWeightedMean_DifferentWeights_CorrectCalculation() {
        let values = [10.0, 20.0, 30.0]
        let weights = [1.0, 2.0, 1.0] // 20 weighted more heavily

        let result = stats.calculateWeightedMean(values: values, weights: weights)
        let expected = (10.0*1.0 + 20.0*2.0 + 30.0*1.0) / 4.0 // = 80/4 = 20

        #expect(abs(result - expected) < 0.001)
    }

    @Test func testWeightedMean_EmptyArray_ReturnsZero() {
        let result = stats.calculateWeightedMean(values: [], weights: [])
        #expect(result == 0.0)
    }

    @Test func testWeightedMean_ZeroTotalWeight_ReturnsZero() {
        let values = [10.0, 20.0]
        let weights = [0.0, 0.0]

        let result = stats.calculateWeightedMean(values: values, weights: weights)
        #expect(result == 0.0)
    }

    // MARK: - Weighted Standard Deviation Tests

    @Test func testWeightedStdDev_UniformData_ReturnsZero() {
        let values = [5.0, 5.0, 5.0, 5.0]
        let weights = [1.0, 1.0, 1.0, 1.0]

        let result = stats.calculateWeightedStandardDeviation(values: values, weights: weights)
        #expect(abs(result) < 0.001)
    }

    @Test func testWeightedStdDev_KnownValues_CorrectCalculation() {
        let values = [10.0, 20.0, 30.0]
        let weights = [1.0, 1.0, 1.0]

        let result = stats.calculateWeightedStandardDeviation(values: values, weights: weights, unbiased: false)

        // Mean = 20, variance = ((10-20)^2 + (20-20)^2 + (30-20)^2)/3 = 200/3
        let expectedStdDev = sqrt(200.0 / 3.0)

        #expect(abs(result - expectedStdDev) < 0.001)
    }

    @Test func testWeightedStdDev_SingleValue_ReturnsZero() {
        let values = [42.0]
        let weights = [1.0]

        let result = stats.calculateWeightedStandardDeviation(values: values, weights: weights)
        #expect(result == 0.0)
    }

    // MARK: - Percentile Tests (CRITICAL)

    @Test func testPercentile_OddArray_ReturnsMiddleValue() {
        let sorted = [1.0, 2.0, 3.0, 4.0, 5.0]
        let median = stats.percentile(sorted, p: 0.5)

        #expect(median == 3.0)
    }

    @Test func testPercentile_EvenArray_ReturnsInterpolated() {
        let sorted = [1.0, 2.0, 3.0, 4.0]
        let median = stats.percentile(sorted, p: 0.5)

        // Should interpolate between 2.0 and 3.0
        #expect(median == 2.5)
    }

    @Test func testPercentile_MinValue_ReturnsFirst() {
        let sorted = [10.0, 20.0, 30.0, 40.0]
        let min = stats.percentile(sorted, p: 0.0)

        #expect(min == 10.0)
    }

    @Test func testPercentile_MaxValue_ReturnsLast() {
        let sorted = [10.0, 20.0, 30.0, 40.0]
        let max = stats.percentile(sorted, p: 1.0)

        #expect(max == 40.0)
    }

    @Test func testPercentile_QuartileValues_CorrectCalculation() {
        let sorted = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]

        let q1 = stats.percentile(sorted, p: 0.25)
        let q2 = stats.percentile(sorted, p: 0.5)
        let q3 = stats.percentile(sorted, p: 0.75)

        // Q1 should be around 3.25 (interpolated)
        // Q2 should be 5.5 (median)
        // Q3 should be around 7.75 (interpolated)

        #expect(abs(q1 - 3.25) < 0.1)
        #expect(abs(q2 - 5.5) < 0.1)
        #expect(abs(q3 - 7.75) < 0.1)
    }

    @Test func testPercentile_EmptyArray_ReturnsZero() {
        let result = stats.percentile([], p: 0.5)
        #expect(result == 0.0)
    }

    @Test func testPercentile_SingleValue_ReturnsThatValue() {
        let sorted = [42.0]
        let result = stats.percentile(sorted, p: 0.5)

        #expect(result == 42.0)
    }

    // MARK: - Distribution Analysis Tests

    @Test func testAnalyzeDistribution_UniformData_LowSpan() {
        let sizes = Array(repeating: 500.0, count: 100)

        let distribution = stats.analyzeDistribution(sizes: sizes)

        #expect(distribution.d10 == 500.0)
        #expect(distribution.d50 == 500.0)
        #expect(distribution.d90 == 500.0)
        #expect(distribution.span == 0.0)
        #expect(distribution.uniformity > 0.99) // Very uniform
    }

    @Test func testAnalyzeDistribution_WideRange_HighSpan() {
        // Create distribution from 100 to 1000
        let sizes = stride(from: 100.0, through: 1000.0, by: 10.0).map { $0 }

        let distribution = stats.analyzeDistribution(sizes: sizes)

        // D50 should be around 550 (middle)
        #expect(abs(distribution.d50 - 550.0) < 50.0)

        // Span should be significant
        #expect(distribution.span > 1.0)
    }

    @Test func testAnalyzeDistribution_EmptyArray_ReturnsZeros() {
        let distribution = stats.analyzeDistribution(sizes: [])

        #expect(distribution.d10 == 0.0)
        #expect(distribution.d50 == 0.0)
        #expect(distribution.d90 == 0.0)
        #expect(distribution.span == 0.0)
    }

    @Test func testAnalyzeDistribution_NormalDistribution_ReasonableMetrics() {
        // Simulate normal distribution centered at 500 with stddev ~50
        var sizes: [Double] = []
        for i in 0..<100 {
            let value = 500.0 + Double(i % 20 - 10) * 5.0 // Creates variation
            sizes.append(value)
        }

        let distribution = stats.analyzeDistribution(sizes: sizes.sorted())

        // D50 should be near center
        #expect(abs(distribution.d50 - 500.0) < 100.0)

        // Should have reasonable uniformity
        #expect(distribution.uniformity > 0.5)
    }

    // MARK: - Histogram Binning Tests

    @Test func testCreateHistogram_UniformData_SingleBin() {
        let values = Array(repeating: 50.0, count: 100)

        let histogram = stats.createHistogram(values: values, binCount: 10)

        // All values should fall in one bin
        let maxCount = histogram.counts.max() ?? 0
        #expect(maxCount == 100)

        // Sum of normalized counts should be ~1
        let sum = histogram.normalizedCounts.reduce(0, +)
        #expect(abs(sum - 1.0) < 0.01)
    }

    @Test func testCreateHistogram_LinearRange_DistributedEvenly() {
        let values = stride(from: 0.0, through: 100.0, by: 1.0).map { $0 }

        let histogram = stats.createHistogram(values: values, binCount: 10)

        #expect(histogram.edges.count == 11) // n bins = n+1 edges
        #expect(histogram.counts.count == 10)

        // First edge should be 0, last should be 100
        #expect(histogram.edges.first == 0.0)
        #expect(histogram.edges.last == 100.0)
    }

    @Test func testCreateHistogram_EmptyArray_ReturnsEmpty() {
        let histogram = stats.createHistogram(values: [])

        #expect(histogram.edges.isEmpty)
        #expect(histogram.counts.isEmpty)
        #expect(histogram.normalizedCounts.isEmpty)
    }

    @Test func testCreateHistogram_WeightedValues_ReflectsWeights() {
        let values = [1.0, 2.0, 3.0, 4.0]
        let weights = [1.0, 10.0, 1.0, 1.0] // Second value weighted heavily

        let histogram = stats.createHistogram(values: values, weights: weights, binCount: 4)

        // The bin containing 2.0 should have highest normalized count
        let maxNormalized = histogram.normalizedCounts.max() ?? 0
        #expect(maxNormalized > 0.5) // Should be heavily weighted toward bin with value 2
    }

    // MARK: - Mass and Extraction Tests

    @Test func testCalculateAttainableMass_SmallParticles_FullyAccessible() {
        // Small particles (radius < depthLimit) should be fully accessible
        let smallVolume = (4.0/3.0) * Double.pi * pow(50.0, 3) // radius = 50μm
        let volumes = [smallVolume]

        let attainableMasses = stats.calculateAttainableMass(volumes: volumes)

        // Should be equal to original volume
        #expect(abs(attainableMasses[0] - smallVolume) < 0.001)
    }

    @Test func testCalculateAttainableMass_LargeParticles_ReducedAccess() {
        // Large particles (radius > depthLimit) should have unreachable core
        let largeRadius = 200.0 // > depthLimit (100μm)
        let largeVolume = (4.0/3.0) * Double.pi * pow(largeRadius, 3)
        let volumes = [largeVolume]

        let attainableMasses = stats.calculateAttainableMass(volumes: volumes)

        // Should be less than original volume
        #expect(attainableMasses[0] < largeVolume)
    }

    @Test func testCalculateExtractionYield_SmallSurface_HigherYield() {
        // Smaller surface area should lead to faster extraction
        let surfaces = [100.0, 1000.0]

        let yields = stats.calculateExtractionYield(surfaces: surfaces)

        // Smaller surface should have higher extraction speed
        #expect(yields[0] > yields[1])
    }

    @Test func testCalculateExtractionYield_AllPositive() {
        let surfaces = [100.0, 500.0, 1000.0]

        let yields = stats.calculateExtractionYield(surfaces: surfaces)

        // All yields should be positive and within reasonable range
        for yield in yields {
            #expect(yield > 0)
            #expect(yield <= 100) // Percentage should not exceed 100
        }
    }

    // MARK: - Quality Metrics Tests

    @Test func testCalculateQualityScore_HighUniformity_HighScore() {
        let surface = 1000.0
        let lowStdDev = 10.0

        let score = stats.calculateQualityScore(surface: surface, surfaceStdDev: lowStdDev)

        #expect(score == 100.0) // 1000/10 = 100
    }

    @Test func testCalculateQualityScore_ZeroStdDev_ReturnsZero() {
        let score = stats.calculateQualityScore(surface: 1000.0, surfaceStdDev: 0.0)
        #expect(score == 0.0)
    }

    @Test func testCalculateEfficiency_FullAccess_Returns100Percent() {
        let volumes = [100.0, 200.0, 300.0]
        let attainableMasses = volumes // All accessible

        let efficiency = stats.calculateEfficiency(attainableMasses: attainableMasses, volumes: volumes)

        #expect(abs(efficiency - 100.0) < 0.001)
    }

    @Test func testCalculateEfficiency_PartialAccess_ReturnsLessThan100() {
        let volumes = [100.0, 200.0, 300.0]
        let attainableMasses = [50.0, 100.0, 150.0] // 50% accessible

        let efficiency = stats.calculateEfficiency(attainableMasses: attainableMasses, volumes: volumes)

        #expect(abs(efficiency - 50.0) < 0.001)
    }

    // MARK: - Poisson Error Bars Tests

    @Test func testPoissonErrorBars_ZeroCount_ReturnsZero() {
        let errorBars = stats.calculatePoissonErrorBars(counts: [0])

        #expect(errorBars.lower[0] == 0.0)
        #expect(errorBars.upper[0] > 0.0) // Upper should still be positive
    }

    @Test func testPoissonErrorBars_HighCounts_NarrowInterval() {
        let errorBars = stats.calculatePoissonErrorBars(counts: [100])

        let intervalWidth = errorBars.upper[0] - errorBars.lower[0]

        // For high counts, interval should be relatively narrow (< 30% of count)
        #expect(intervalWidth < 30.0)
    }

    @Test func testPoissonErrorBars_LowCounts_WideInterval() {
        let errorBars = stats.calculatePoissonErrorBars(counts: [5])

        let intervalWidth = errorBars.upper[0] - errorBars.lower[0]

        // For low counts, interval should be relatively wide
        #expect(intervalWidth > 3.0)
    }

    @Test func testPoissonErrorBars_MultipleCounts_CorrectLength() {
        let counts = [10, 20, 30, 40, 50]
        let errorBars = stats.calculatePoissonErrorBars(counts: counts)

        #expect(errorBars.lower.count == counts.count)
        #expect(errorBars.upper.count == counts.count)
    }
}
