//
//  ParticleSeparationEngine.swift
//  Coffee Grind Analyzer
//
//  Advanced particle separation algorithms from Python implementation
//

import Foundation
import UIKit
import Accelerate

class ParticleSeparationEngine {
    
    // MARK: - Advanced Particle Separation with Cost Function
    
    struct AdvancedCluster {
        let pixels: [(x: Int, y: Int, brightness: UInt8)]
        let startPixel: (x: Int, y: Int, brightness: UInt8)
        let surface: Double
        let centroidX: Double
        let centroidY: Double
        let longAxis: Double
        let shortAxis: Double
        let roundness: Double
        let volume: Double
        let subPixelSurface: Double // Surface adjusted for sub-pixel accuracy
    }
    
    // Python-equivalent parameters
    private let referenceThreshold: Double = 0.4
    private let maxCost: Double = 0.35
    private let smoothingWindow: Int = 3
    private let minSurface: Double = 5.0
    private let maxClusterAxis: Double = 100.0
    
    // MARK: - Cluster Separation with Path-based Cost Function
    
    func separateTouchingParticles(
        clusterPixels: [(x: Int, y: Int, brightness: UInt8)],
        imageData: [UInt8],
        backgroundMedian: Double,
        width: Int,
        startPixel: (x: Int, y: Int, brightness: UInt8)
    ) -> [(x: Int, y: Int, brightness: UInt8)] {
        
        // Sort pixels by distance from starting pixel (darkest)
        let sortedPixels = clusterPixels.sorted { p1, p2 in
            let dist1 = pow(Double(p1.x - startPixel.x), 2) + pow(Double(p1.y - startPixel.y), 2)
            let dist2 = pow(Double(p2.x - startPixel.x), 2) + pow(Double(p2.y - startPixel.y), 2)
            return dist1 < dist2
        }
        
        var filteredPixels: [(x: Int, y: Int, brightness: UInt8)] = [startPixel]
        
        for pixel in sortedPixels {
            if pixel.x == startPixel.x && pixel.y == startPixel.y { continue }
            
            // Find reference dark pixel (within threshold of start pixel brightness)
            let darkThreshold = Double(startPixel.brightness) + 
                               (backgroundMedian - Double(startPixel.brightness)) * referenceThreshold
            
            let darkPixels = filteredPixels.filter { p in
                Double(p.brightness) <= darkThreshold
            }
            
            guard !darkPixels.isEmpty else { continue }
            
            // Find nearest dark pixel
            let nearestDark = darkPixels.min { p1, p2 in
                let dist1 = pow(Double(p1.x - pixel.x), 2) + pow(Double(p1.y - pixel.y), 2)
                let dist2 = pow(Double(p2.x - pixel.x), 2) + pow(Double(p2.y - pixel.y), 2)
                return dist1 < dist2
            }!
            
            // Calculate path cost from pixel to reference dark pixel
            let pathCost = calculatePathCost(
                from: pixel,
                to: nearestDark,
                pixels: clusterPixels,
                imageData: imageData,
                backgroundMedian: backgroundMedian,
                width: width
            )
            
            // Accept pixel if path cost is below threshold
            if pathCost < maxCost {
                filteredPixels.append(pixel)
            }
        }
        
        return filteredPixels
    }
    
    private func calculatePathCost(
        from start: (x: Int, y: Int, brightness: UInt8),
        to end: (x: Int, y: Int, brightness: UInt8),
        pixels: [(x: Int, y: Int, brightness: UInt8)],
        imageData: [UInt8],
        backgroundMedian: Double,
        width: Int
    ) -> Double {
        
        // Build path using Bresenham's line algorithm
        let path = bresenhamLine(x0: start.x, y0: start.y, x1: end.x, y1: end.y)
        
        // Calculate costs along path
        var costs: [Double] = []
        for point in path {
            let index = point.y * width + point.x
            if index >= 0 && index < imageData.count {
                let brightness = Double(imageData[index])
                let cost = pow(brightness - Double(start.brightness), 2) / pow(backgroundMedian, 2)
                costs.append(max(cost, 0))
            }
        }
        
        // Smooth costs with moving average
        let smoothedCosts = smooth(costs, windowSize: smoothingWindow)
        
        // Return maximum cost along path
        return smoothedCosts.max() ?? Double.infinity
    }
    
    private func bresenhamLine(x0: Int, y0: Int, x1: Int, y1: Int) -> [(x: Int, y: Int)] {
        var points: [(x: Int, y: Int)] = []
        
        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx - dy
        var x = x0
        var y = y0
        
        while true {
            points.append((x: x, y: y))
            
            if x == x1 && y == y1 { break }
            
            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                x += sx
            }
            if e2 < dx {
                err += dx
                y += sy
            }
        }
        
        return points
    }
    
    private func smooth(_ data: [Double], windowSize: Int) -> [Double] {
        guard data.count > windowSize else { return data }
        
        var smoothed = [Double]()
        let halfWindow = windowSize / 2
        
        for i in 0..<data.count {
            let start = max(0, i - halfWindow)
            let end = min(data.count - 1, i + halfWindow)
            let window = Array(data[start...end])
            let sum = window.reduce(0, +)
            smoothed.append(sum / Double(window.count))
        }
        
        return smoothed
    }
    
    // MARK: - Sub-pixel Accuracy
    
    func calculateSubPixelSurface(
        pixels: [(x: Int, y: Int, brightness: UInt8)],
        backgroundMedian: Double
    ) -> Double {
        guard !pixels.isEmpty else { return 0 }
        
        // Find darkest pixel
        let darkest = pixels.min { $0.brightness < $1.brightness }!
        
        // Calculate surface multiplier for sub-pixel particles
        let multiplier = (backgroundMedian - Double(darkest.brightness)) / backgroundMedian
        let adjustedMultiplier = max(multiplier, 1.0)
        
        // Return surface with sub-pixel adjustment
        return Double(pixels.count) * adjustedMultiplier
    }
    
    // MARK: - Polygon-based Region Selection
    
    func filterPixelsInPolygon(
        pixels: [(x: Int, y: Int)],
        polygon: [CGPoint]
    ) -> [(x: Int, y: Int)] {
        guard polygon.count >= 3 else { return pixels }
        
        return pixels.filter { pixel in
            isPointInPolygon(
                point: CGPoint(x: pixel.x, y: pixel.y),
                polygon: polygon
            )
        }
    }
    
    private func isPointInPolygon(point: CGPoint, polygon: [CGPoint]) -> Bool {
        var inside = false
        var p1 = polygon.last!
        
        for p2 in polygon {
            if (p2.y > point.y) != (p1.y > point.y) {
                let slope = (point.x - p1.x) * (p2.y - p1.y) - 
                           (p2.x - p1.x) * (point.y - p1.y)
                if (p2.y > p1.y && slope < 0) || (p2.y < p1.y && slope > 0) {
                    inside = !inside
                }
            }
            p1 = p2
        }
        
        return inside
    }
    
    func findEdgePixels(
        thresholdPixels: [(x: Int, y: Int)],
        polygon: [CGPoint]
    ) -> Set<String> {
        var edgePixels = Set<String>()
        
        for i in 0..<polygon.count {
            let p1 = polygon[i]
            let p2 = polygon[(i + 1) % polygon.count]
            
            // Find pixels near this edge
            for pixel in thresholdPixels {
                let distance = pointToLineDistance(
                    point: CGPoint(x: pixel.x, y: pixel.y),
                    lineStart: p1,
                    lineEnd: p2
                )
                
                if distance <= sqrt(2.0) {
                    edgePixels.insert("\(pixel.x),\(pixel.y)")
                }
            }
        }
        
        return edgePixels
    }
    
    private func pointToLineDistance(
        point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> Double {
        let numerator = abs(
            (lineEnd.y - lineStart.y) * point.x -
            (lineEnd.x - lineStart.x) * point.y +
            lineEnd.x * lineStart.y -
            lineEnd.y * lineStart.x
        )
        
        let denominator = sqrt(
            pow(lineEnd.y - lineStart.y, 2) +
            pow(lineEnd.x - lineStart.x, 2)
        )
        
        return denominator > 0 ? Double(numerator / denominator) : 0
    }
}