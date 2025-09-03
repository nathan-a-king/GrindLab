//
//  CoffeeCompassView.swift
//  Coffee Grind Analyzer
//
//  Created by Claude on 8/30/25.
//

import SwiftUI

struct CoffeeCompassView: View {
    let flavorProfile: FlavorProfile?
    let currentPosition: CoffeeCompassPosition
    
    private let compassSize: CGFloat = 320
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Smart Suggestions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            ZStack {
                // Outer ring with gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.brown.opacity(0.2), Color.brown.opacity(0.5)],
                            center: .center,
                            startRadius: 100,
                            endRadius: compassSize/2
                        )
                    )
                    .frame(width: compassSize, height: compassSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    )
                
                // Inner compass circle with subtle shadow
                Circle()
                    .fill(Color.brown.opacity(0.1))
                    .frame(width: compassSize - 20, height: compassSize - 20)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Compass quadrants with gradients
                compassQuadrants
                
                // Crosshair lines
                crosshairLines
                
                // Center target (balanced coffee) with glow effect
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .blur(radius: 8)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.green.opacity(0.9), Color.green.opacity(0.7)],
                                center: .center,
                                startRadius: 5,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                        .overlay(
                            Text("SWEET")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                
                // Current position indicator with animation
                if let position = currentPosition.coordinates {
                    currentPositionIndicator(at: position)
                }
                
                // Quadrant labels with better styling
                compassLabels
            }
            .frame(width: compassSize, height: compassSize)
            
            // Enhanced legend
            compassLegend
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.brown.opacity(0.3), Color.brown.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
        )
    }
    
    private var compassQuadrants: some View {
        ZStack {
            let radius = (compassSize - 20) / 2
            let center = CGPoint(x: compassSize/2, y: compassSize/2)
            
            // Create a subtle, elegant gradient across the entire compass
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.brown.opacity(0.15),  // Starting point
                            Color.yellow.opacity(0.12), // Under-extracted area
                            Color.brown.opacity(0.15),
                            Color.red.opacity(0.12),    // Over-extracted area
                            Color.brown.opacity(0.15),
                            Color.orange.opacity(0.12), // Harsh area
                            Color.brown.opacity(0.15),
                            Color.blue.opacity(0.12),   // Weak area
                            Color.brown.opacity(0.15)   // Back to start
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    )
                )
                .frame(width: compassSize - 20, height: compassSize - 20)
            
            // Add a very subtle radial gradient overlay for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.brown.opacity(0.08)
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: radius
                    )
                )
                .frame(width: compassSize - 20, height: compassSize - 20)
            
            // Subtle quadrant divider lines (replacing the stark borders)
            Path { path in
                // Horizontal line
                path.move(to: CGPoint(x: 20, y: center.y))
                path.addLine(to: CGPoint(x: compassSize - 20, y: center.y))
                // Vertical line
                path.move(to: CGPoint(x: center.x, y: 20))
                path.addLine(to: CGPoint(x: center.x, y: compassSize - 20))
            }
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
        }
    }
    
    private var crosshairLines: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: compassSize - 40, height: 1)
            
            // Vertical line  
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 1, height: compassSize - 40)
        }
    }
    
    private var compassLabels: some View {
        ZStack {
            // Extract Less (top) - clean text without background
            VStack(spacing: 2) {
                Text("EXTRACT LESS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Coarser grind • Shorter time")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
            .position(x: compassSize/2, y: 40)
            
            // Extract More (bottom) - clean text without background
            VStack(spacing: 2) {
                Text("EXTRACT MORE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Finer grind • Longer time")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
            .position(x: compassSize/2, y: compassSize - 40)
            
            // More Coffee (left) - clean text without background
            VStack(spacing: 2) {
                Text("MORE COFFEE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Higher ratio")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
            .rotationEffect(.degrees(-90))
            .position(x: 40, y: compassSize/2)
            
            // Less Coffee (right) - clean text without background
            VStack(spacing: 2) {
                Text("LESS COFFEE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Lower ratio")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
            }
            .rotationEffect(.degrees(90))
            .position(x: compassSize - 40, y: compassSize/2)
            
            // Quadrant taste labels - clean text without backgrounds
            Group {
                // Sour/Weak quadrant
                VStack(spacing: 1) {
                    Text("SOUR")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("WEAK")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white.opacity(0.85))
                .position(x: compassSize * 0.28, y: compassSize * 0.28)
                
                // Bitter/Dry quadrant
                VStack(spacing: 1) {
                    Text("BITTER")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("DRY")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white.opacity(0.85))
                .position(x: compassSize * 0.72, y: compassSize * 0.28)
                
                // Lacks Body quadrant
                VStack(spacing: 1) {
                    Text("LACKS")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("BODY")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white.opacity(0.85))
                .position(x: compassSize * 0.28, y: compassSize * 0.72)
                
                // Harsh/Astringent quadrant
                VStack(spacing: 1) {
                    Text("HARSH")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("BITTER")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white.opacity(0.85))
                .position(x: compassSize * 0.72, y: compassSize * 0.72)
            }
        }
    }
    
    private func currentPositionIndicator(at position: CGPoint) -> some View {
        ZStack {
            // Outer glow effect
            Circle()
                .fill(currentPosition.color.opacity(0.4))
                .frame(width: 28, height: 28)
                .blur(radius: 4)
            
            // Main indicator circle
            Circle()
                .fill(Color.white)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [currentPosition.color.opacity(0.9), currentPosition.color],
                                center: .center,
                                startRadius: 2,
                                endRadius: 8
                            )
                        )
                        .frame(width: 16, height: 16)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 20, height: 20)
                )
            
            // Pulsing animation ring
            Circle()
                .stroke(currentPosition.color.opacity(0.6), lineWidth: 2)
                .frame(width: 24, height: 24)
                .scaleEffect(1.2)
                .opacity(0.7)
        }
        .position(position)
        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
    }
    
    private var compassLegend: some View {
        VStack(spacing: 12) {
            if let profile = flavorProfile {
                HStack(spacing: 12) {
                    // Current position indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(currentPosition.color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your Coffee")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text(profile.overallTaste.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                    
                    // Target indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.green.opacity(0.9), Color.green.opacity(0.7)],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 8
                                )
                            )
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            Text("Balanced & Sweet")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Coffee Compass Position

struct CoffeeCompassPosition {
    let taste: FlavorProfile.OverallTaste
    let intensity: FlavorProfile.TasteIntensity
    
    init(flavorProfile: FlavorProfile) {
        self.taste = flavorProfile.overallTaste
        self.intensity = flavorProfile.intensity
        print("🧭 CoffeeCompassPosition init:")
        print("   - Overall taste: \(flavorProfile.overallTaste.rawValue)")
        print("   - Intensity: \(flavorProfile.intensity.rawValue)")
        print("   - Flavor issues: \(flavorProfile.flavorIssues.map { $0.rawValue })")
    }
    
    var coordinates: CGPoint? {
        let compassSize: CGFloat = 320 // Match the actual compass size in CoffeeCompassView
        let center = CGPoint(x: compassSize/2, y: compassSize/2)
        let radius = compassSize/2 - 40 // Leave space for center circle
        
        // Intensity affects distance from center
        let distanceMultiplier: CGFloat
        switch intensity {
        case .veryMild:
            distanceMultiplier = 0.3
        case .mild: 
            distanceMultiplier = 0.4
        case .moderate: 
            distanceMultiplier = 0.7
        case .strong: 
            distanceMultiplier = 0.9
        case .veryStrong:
            distanceMultiplier = 1.0
        }
        
        let distance = radius * distanceMultiplier
        
        let result: CGPoint
        switch taste {
        case .balanced:
            result = center // Always stay perfectly centered for balanced coffee
        case .underExtracted:
            // Top-left quadrant - SOUR/WEAK (position 0.28, 0.28)
            result = CGPoint(
                x: center.x - distance * 0.7,  // Move left
                y: center.y - distance * 0.7   // Move up
            )
        case .overExtracted:
            // Top-right quadrant - BITTER/DRY (position 0.72, 0.28)
            result = CGPoint(
                x: center.x + distance * 0.7,  // Move right
                y: center.y - distance * 0.7   // Move up
            )
        case .weak:
            // Bottom-left quadrant - LACKS BODY (position 0.28, 0.72)
            result = CGPoint(
                x: center.x - distance * 0.7,  // Move left
                y: center.y + distance * 0.7   // Move down
            )
        case .harsh:
            // Bottom-right quadrant - HARSH (position 0.72, 0.72)
            result = CGPoint(
                x: center.x + distance * 0.7,  // Move right
                y: center.y + distance * 0.7   // Move down
            )
        }
        
        print("🧭 Compass coordinates calculated:")
        print("   - Taste: \(taste.rawValue)")
        print("   - Position: (\(String(format: "%.1f", result.x)), \(String(format: "%.1f", result.y)))")
        print("   - Center: (\(String(format: "%.1f", center.x)), \(String(format: "%.1f", center.y)))")
        
        return result
    }
    
    var color: Color {
        switch taste {
        case .balanced: return .green
        case .underExtracted: return .yellow
        case .overExtracted: return .red
        case .weak: return .blue
        case .harsh: return .orange
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CoffeeCompassView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProfile = FlavorProfile(
            overallTaste: .underExtracted,
            flavorIssues: [.sour, .weak],
            intensity: .moderate,
            notes: "Tastes quite sour",
            timestamp: Date()
        )
        
        ZStack {
            Color.brown.opacity(0.7)
                .ignoresSafeArea()
            
            CoffeeCompassView(
                flavorProfile: sampleProfile,
                currentPosition: CoffeeCompassPosition(flavorProfile: sampleProfile)
            )
        }
    }
}
#endif
