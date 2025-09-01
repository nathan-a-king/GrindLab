# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Coffee Grind Analyzer is an iOS/macOS application built with SwiftUI that analyzes coffee grind consistency using computer vision. The app uses the device camera to capture images of coffee grounds and provides detailed analysis including particle size distribution, uniformity metrics, and brewing recommendations.

## Architecture

### Core Components

- **Main App Entry**: `Coffee_Grind_AnalyzerApp.swift` - SwiftUI app entry point
- **ContentView**: Main navigation hub with TabView for Analyze and History tabs
- **CoffeeAnalysisEngine**: Core analysis engine using Vision framework and image processing
- **CoffeeCamera**: Camera management using AVFoundation for capturing grind images
- **CoinCalibrationDetector**: Coin detection for size calibration reference

### Key Directories

- `Analysis/`: Image processing and analysis logic
- `Camera/`: Camera capture and preview components  
- `Models/`: Data models, persistence, and business logic
- `Views/`: SwiftUI views and UI components
- `Assets.xcassets/`: App icons and image resources

### Data Flow

1. User selects grind type (Filter, Espresso, French Press, Cold Brew)
2. Camera captures image with optional coin calibration
3. CoffeeAnalysisEngine processes image:
   - Preprocesses and converts to grayscale
   - Detects particles using Vision framework
   - Calculates size distribution and uniformity metrics
4. Results displayed with statistics and recommendations
5. Analysis saved to history with tasting notes capability

## Development Commands

### Building and Running

This is an Xcode project. Use these commands:

```bash
# Open project in Xcode
open "Coffee Grind Analyzer.xcodeproj"

# Build from command line
xcodebuild -project "Coffee Grind Analyzer.xcodeproj" -scheme "Coffee Grind Analyzer" build

# Run tests
xcodebuild test -project "Coffee Grind Analyzer.xcodeproj" -scheme "Coffee Grind Analyzer" -destination "platform=iOS Simulator,name=iPhone 15"

# Clean build
xcodebuild clean -project "Coffee Grind Analyzer.xcodeproj" -scheme "Coffee Grind Analyzer"
```

### Swift-Specific Tools

```bash
# Format Swift code (if swift-format is installed)
swift-format -i Coffee\ Grind\ Analyzer/**/*.swift

# Lint Swift code (if SwiftLint is installed)
swiftlint lint --path "Coffee Grind Analyzer"
```

## Key Technical Details

### Image Processing Pipeline
- Uses Vision framework for particle detection
- Implements custom edge detection and thresholding
- Calculates particle size distribution using pixel-to-micron conversion
- Supports coin calibration for accurate size measurement

### Persistence
- Settings stored using UserDefaults (SettingsPersistence.swift)
- Analysis history managed by CoffeeAnalysisHistoryManager
- Supports JSON encoding/decoding for all models

### Grind Type Specifications
- Filter/Pour-Over: 400-800μm target range
- Espresso: 170-300μm target range  
- French Press: 750-1000μm target range
- Cold Brew: 800-1200μm target range

### Testing Approach
- Unit tests in Coffee_Grind_AnalyzerTests.swift
- UI tests in Coffee_Grind_AnalyzerUITests.swift
- Test on both iOS simulators and physical devices for camera functionality