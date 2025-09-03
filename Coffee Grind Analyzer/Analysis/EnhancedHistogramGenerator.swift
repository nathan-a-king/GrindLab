//
//  EnhancedHistogramGenerator.swift
//  Coffee Grind Analyzer
//
//  Multiple histogram types matching Python implementation
//

import UIKit
import SwiftUI

// Charts framework is only available in iOS 16+
#if canImport(Charts)
import Charts
#endif

enum HistogramType: String, CaseIterable {
    case numberVsDiameter = "Number vs Diameter"
    case numberVsSurface = "Number vs Surface"
    case numberVsVolume = "Number vs Volume"
    case massVsDiameter = "Mass vs Diameter"
    case massVsSurface = "Mass vs Surface"
    case massVsVolume = "Mass vs Volume"
    case availableMassVsDiameter = "Available Mass vs Diameter"
    case availableMassVsSurface = "Available Mass vs Surface"
    case availableMassVsVolume = "Available Mass vs Volume"
    case surfaceVsDiameter = "Surface vs Diameter"
    case surfaceVsSurface = "Surface vs Surface"
    case surfaceVsVolume = "Surface vs Volume"
    
    var xAxisLabel: String {
        switch self {
        case .numberVsDiameter, .massVsDiameter, .availableMassVsDiameter, .surfaceVsDiameter:
            return "Particle Diameter (mm)"
        case .numberVsSurface, .massVsSurface, .availableMassVsSurface, .surfaceVsSurface:
            return "Particle Surface (mm²)"
        case .numberVsVolume, .massVsVolume, .availableMassVsVolume, .surfaceVsVolume:
            return "Particle Volume (mm³)"
        }
    }
    
    var yAxisLabel: String {
        switch self {
        case .numberVsDiameter, .numberVsSurface, .numberVsVolume:
            return "Fraction of Particles"
        case .massVsDiameter, .massVsSurface, .massVsVolume:
            return "Fraction of Total Mass"
        case .availableMassVsDiameter, .availableMassVsSurface, .availableMassVsVolume:
            return "Fraction of Available Mass"
        case .surfaceVsDiameter, .surfaceVsSurface, .surfaceVsVolume:
            return "Fraction of Total Surface"
        }
    }
}

class EnhancedHistogramGenerator {
    
    private let statistics = AdvancedStatistics()
    
    struct HistogramData {
        let values: [Double]       // X-axis values
        let weights: [Double]      // Y-axis weights
        let bins: [Double]         // Bin edges
        let counts: [Double]       // Normalized counts per bin
        let average: Double        // Weighted average
        let errorBars: (lower: [Double], upper: [Double])
        let xAxisLabel: String
        let yAxisLabel: String
    }
    
    func generateHistogram(
        particles: [CoffeeParticle],
        type: HistogramType,
        pixelScale: Double,
        logScale: Bool = true,
        binCount: Int? = nil
    ) -> HistogramData {
        
        // Calculate particle properties
        let diameters = particles.map { 2 * sqrt($0.size / pixelScale) }
        let surfaces = particles.map { $0.area / (pixelScale * pixelScale) }
        let volumes = calculateVolumes(particles: particles, pixelScale: pixelScale)
        
        // Get X-axis data based on type
        let xData: [Double]
        switch type {
        case .numberVsDiameter, .massVsDiameter, .availableMassVsDiameter, .surfaceVsDiameter:
            xData = diameters
        case .numberVsSurface, .massVsSurface, .availableMassVsSurface, .surfaceVsSurface:
            xData = surfaces
        case .numberVsVolume, .massVsVolume, .availableMassVsVolume, .surfaceVsVolume:
            xData = volumes
        }
        
        // Get weights based on type
        let weights: [Double]
        switch type {
        case .numberVsDiameter, .numberVsSurface, .numberVsVolume:
            weights = [Double](repeating: 1.0, count: particles.count)
        case .massVsDiameter, .massVsSurface, .massVsVolume:
            weights = volumes // Mass proportional to volume
        case .availableMassVsDiameter, .availableMassVsSurface, .availableMassVsVolume:
            weights = statistics.calculateAttainableMass(volumes: volumes)
        case .surfaceVsDiameter, .surfaceVsSurface, .surfaceVsVolume:
            weights = surfaces
        }
        
        // Create histogram bins
        let histogram = statistics.createHistogram(
            values: xData,
            weights: weights,
            binCount: binCount,
            logScale: logScale
        )
        
        // Calculate weighted average
        let average = statistics.calculateWeightedMean(
            values: xData,
            weights: weights
        )
        
        // Calculate error bars
        let intCounts = histogram.counts
        let errorBars = statistics.calculatePoissonErrorBars(counts: intCounts)
        
        return HistogramData(
            values: xData,
            weights: weights,
            bins: histogram.edges,
            counts: histogram.normalizedCounts,
            average: average,
            errorBars: errorBars,
            xAxisLabel: type.xAxisLabel,
            yAxisLabel: type.yAxisLabel
        )
    }
    
    private func calculateVolumes(particles: [CoffeeParticle], pixelScale: Double) -> [Double] {
        return particles.map { particle in
            // Estimate volume from area assuming ellipsoidal particles
            let radius = sqrt(particle.area / Double.pi) / pixelScale
            let volume = (4.0 / 3.0) * Double.pi * pow(radius, 3)
            return volume
        }
    }
    
    // MARK: - Chart Creation with SwiftUI
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
        let label: String
    }
    
    func createChartData(from data: HistogramData) -> [ChartDataPoint] {
        var points: [ChartDataPoint] = []
        for i in 0..<data.counts.count {
            let xValue = (data.bins[i] + data.bins[i + 1]) / 2.0
            let yValue = data.counts[i]
            let label = String(format: "%.1f", xValue)
            points.append(ChartDataPoint(x: xValue, y: yValue, label: label))
        }
        return points
    }
    
    // Create a simple data structure for chart visualization
    struct SimpleChartData {
        let points: [ChartDataPoint]
        let average: Double
        let xAxisLabel: String
        let yAxisLabel: String
        let title: String
    }
    
    func createSimpleChart(from data: HistogramData, title: String) -> SimpleChartData {
        return SimpleChartData(
            points: createChartData(from: data),
            average: data.average,
            xAxisLabel: data.xAxisLabel,
            yAxisLabel: data.yAxisLabel,
            title: title
        )
    }
    
    // MARK: - Comparison Support
    
    struct ComparisonChartData {
        let primaryPoints: [ChartDataPoint]
        let comparisonPoints: [ChartDataPoint]
        let primaryLabel: String
        let comparisonLabel: String
        let xAxisLabel: String
        let yAxisLabel: String
    }
    
    func createComparisonChart(
        primary: HistogramData,
        comparison: HistogramData,
        primaryLabel: String,
        comparisonLabel: String
    ) -> ComparisonChartData {
        return ComparisonChartData(
            primaryPoints: createChartData(from: primary),
            comparisonPoints: createChartData(from: comparison),
            primaryLabel: primaryLabel,
            comparisonLabel: comparisonLabel,
            xAxisLabel: primary.xAxisLabel,
            yAxisLabel: primary.yAxisLabel
        )
    }
}