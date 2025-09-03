//
//  AdvancedStatistics.swift
//  Coffee Grind Analyzer
//
//  Advanced statistical calculations with weighted metrics
//

import Foundation

class AdvancedStatistics {
    
    // Coffee cell size estimate in microns (from Python)
    private let coffeeCellSize: Double = 20.0
    
    // Extraction parameters
    private let depthLimit: Double = 100.0 // microns (0.1mm)
    private let extractionLimit: Double = 0.3
    private let kReference: Double = 0.25014
    
    // MARK: - Weighted Statistics
    
    func calculateWeightedMean(
        values: [Double],
        weights: [Double]
    ) -> Double {
        guard values.count == weights.count, !values.isEmpty else { return 0 }
        
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return 0 }
        
        var weightedSum = 0.0
        for i in 0..<values.count {
            weightedSum += values[i] * weights[i]
        }
        
        return weightedSum / totalWeight
    }
    
    func calculateWeightedStandardDeviation(
        values: [Double],
        weights: [Double],
        unbiased: Bool = true
    ) -> Double {
        guard values.count == weights.count, values.count > 1 else { return 0 }
        
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return 0 }
        
        // Calculate bias correction estimator
        let biasEstimator: Double
        if unbiased {
            let sumWeightsSquared = weights.map { $0 * $0 }.reduce(0, +)
            biasEstimator = 1.0 - (sumWeightsSquared / (totalWeight * totalWeight))
        } else {
            biasEstimator = 1.0
        }
        
        // Normalize weights
        let normalizedWeights = weights.map { $0 / totalWeight }
        
        // Calculate weighted mean
        let weightedMean = calculateWeightedMean(values: values, weights: weights)
        
        // Calculate weighted variance
        var weightedVariance = 0.0
        for i in 0..<values.count {
            let deviation = values[i] - weightedMean
            weightedVariance += normalizedWeights[i] * deviation * deviation
        }
        
        // Apply bias correction
        if biasEstimator > 0 {
            weightedVariance /= biasEstimator
        }
        
        return sqrt(weightedVariance)
    }
    
    // MARK: - Mass and Extraction Calculations
    
    func calculateAttainableMass(volumes: [Double]) -> [Double] {
        // Simulates extraction depth limitation
        return volumes.map { volume in
            let radius = pow(3.0 * volume / (4.0 * Double.pi), 1.0/3.0)
            
            if radius <= depthLimit {
                // Small particles are fully accessible
                return volume
            } else {
                // Large particles have unreachable cores
                let unreachableRadius = radius - depthLimit
                let unreachableVolume = (4.0/3.0) * Double.pi * pow(unreachableRadius, 3)
                return volume - unreachableVolume
            }
        }
    }
    
    func calculateExtractionYield(surfaces: [Double]) -> [Double] {
        // Simulates extraction yield based on surface area
        return surfaces.map { surface in
            let extractionSpeed = 1.0 / surface
            let extraction = extractionSpeed / (kReference + extractionSpeed) * extractionLimit
            return extraction * 100 // Convert to percentage
        }
    }
    
    // MARK: - Distribution Analysis
    
    struct ParticleDistribution {
        let d10: Double  // 10th percentile
        let d50: Double  // Median
        let d90: Double  // 90th percentile
        let span: Double // (d90 - d10) / d50
        let uniformity: Double
        let skewness: Double
        let kurtosis: Double
    }
    
    func analyzeDistribution(sizes: [Double]) -> ParticleDistribution {
        let sorted = sizes.sorted()
        let count = sorted.count
        
        guard count > 0 else {
            return ParticleDistribution(
                d10: 0, d50: 0, d90: 0, span: 0,
                uniformity: 0, skewness: 0, kurtosis: 0
            )
        }
        
        // Calculate percentiles
        let d10 = percentile(sorted, p: 0.1)
        let d50 = percentile(sorted, p: 0.5)
        let d90 = percentile(sorted, p: 0.9)
        
        // Calculate span (measure of distribution width)
        let span = d50 > 0 ? (d90 - d10) / d50 : 0
        
        // Calculate uniformity (inverse of coefficient of variation)
        let mean = sorted.reduce(0, +) / Double(count)
        let variance = sorted.map { pow($0 - mean, 2) }.reduce(0, +) / Double(count)
        let stdDev = sqrt(variance)
        let cv = mean > 0 ? stdDev / mean : 0
        let uniformity = max(0, 1.0 - cv)
        
        // Calculate skewness (asymmetry)
        let skewness = calculateSkewness(values: sorted, mean: mean, stdDev: stdDev)
        
        // Calculate kurtosis (tail heaviness)
        let kurtosis = calculateKurtosis(values: sorted, mean: mean, stdDev: stdDev)
        
        return ParticleDistribution(
            d10: d10, d50: d50, d90: d90, span: span,
            uniformity: uniformity, skewness: skewness, kurtosis: kurtosis
        )
    }
    
    private func percentile(_ sorted: [Double], p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        
        let index = p * Double(sorted.count - 1)
        let lower = Int(floor(index))
        let upper = Int(ceil(index))
        let weight = index - Double(lower)
        
        if lower == upper {
            return sorted[lower]
        } else {
            return sorted[lower] * (1 - weight) + sorted[upper] * weight
        }
    }
    
    private func calculateSkewness(values: [Double], mean: Double, stdDev: Double) -> Double {
        guard stdDev > 0, values.count > 2 else { return 0 }
        
        let n = Double(values.count)
        var sum = 0.0
        
        for value in values {
            sum += pow((value - mean) / stdDev, 3)
        }
        
        return (n / ((n - 1) * (n - 2))) * sum
    }
    
    private func calculateKurtosis(values: [Double], mean: Double, stdDev: Double) -> Double {
        guard stdDev > 0, values.count > 3 else { return 0 }
        
        let n = Double(values.count)
        var sum = 0.0
        
        for value in values {
            sum += pow((value - mean) / stdDev, 4)
        }
        
        let factor1 = (n * (n + 1)) / ((n - 1) * (n - 2) * (n - 3))
        let factor2 = (3 * pow(n - 1, 2)) / ((n - 2) * (n - 3))
        
        return factor1 * sum - factor2
    }
    
    // MARK: - Quality Metrics
    
    func calculateQualityScore(
        surface: Double,
        surfaceStdDev: Double
    ) -> Double {
        // Quality as defined in Python: surface / surface_stddev
        guard surfaceStdDev > 0 else { return 0 }
        return surface / surfaceStdDev
    }
    
    func calculateEfficiency(attainableMasses: [Double], volumes: [Double]) -> Double {
        guard volumes.count == attainableMasses.count, !volumes.isEmpty else { return 0 }
        
        let totalVolume = volumes.reduce(0, +)
        let totalAttainable = attainableMasses.reduce(0, +)
        
        guard totalVolume > 0 else { return 0 }
        return (totalAttainable / totalVolume) * 100
    }
    
    // MARK: - Histogram Binning
    
    struct HistogramBins {
        let edges: [Double]
        let counts: [Int]
        let normalizedCounts: [Double]
    }
    
    func createHistogram(
        values: [Double],
        weights: [Double]? = nil,
        binCount: Int? = nil,
        logScale: Bool = false
    ) -> HistogramBins {
        guard !values.isEmpty else {
            return HistogramBins(edges: [], counts: [], normalizedCounts: [])
        }
        
        let min = values.min() ?? 0
        let max = values.max() ?? 1
        
        // Calculate bin count if not provided
        let bins: Int
        if let binCount = binCount {
            bins = binCount
        } else {
            // Use Sturges' rule as default
            bins = Int(ceil(log2(Double(values.count)) + 1))
        }
        
        // Create bin edges
        let edges: [Double]
        if logScale && min > 0 {
            let logMin = log10(min)
            let logMax = log10(max)
            let step = (logMax - logMin) / Double(bins)
            edges = (0...bins).map { i in
                pow(10, logMin + Double(i) * step)
            }
        } else {
            let step = (max - min) / Double(bins)
            edges = (0...bins).map { i in
                min + Double(i) * step
            }
        }
        
        // Count values in each bin
        var counts = [Int](repeating: 0, count: bins)
        var weightedCounts = [Double](repeating: 0, count: bins)
        
        for (index, value) in values.enumerated() {
            for i in 0..<bins {
                if value >= edges[i] && value < edges[i + 1] {
                    counts[i] += 1
                    if let weights = weights {
                        weightedCounts[i] += weights[index]
                    } else {
                        weightedCounts[i] += 1.0
                    }
                    break
                }
            }
        }
        
        // Normalize counts
        let total = weightedCounts.reduce(0, +)
        let normalized = total > 0 ? weightedCounts.map { $0 / total } : weightedCounts
        
        return HistogramBins(edges: edges, counts: counts, normalizedCounts: normalized)
    }
    
    // MARK: - Poisson Error Bars
    
    func calculatePoissonErrorBars(counts: [Int]) -> (lower: [Double], upper: [Double]) {
        var lower = [Double]()
        var upper = [Double]()
        
        for count in counts {
            let n = Double(count)
            // Asymmetric Poisson confidence intervals (68% CI)
            let lowerBound = max(0, -0.5 + sqrt(n + 0.25))
            let upperBound = 0.5 + sqrt(n + 0.25)
            
            lower.append(lowerBound)
            upper.append(upperBound)
        }
        
        return (lower, upper)
    }
}