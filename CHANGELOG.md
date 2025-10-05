# Changelog

All notable changes to GrindLab will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0-beta.1] - 2025-10-05

### Added
- **Brew Timer and Recipes**: New brew timer feature with preset recipes for different brewing methods
- **Live Activities**: Real-time timer updates on lock screen and Dynamic Island (iOS 16.1+)
- **Code Counter**: Development utility for tracking codebase metrics
- **Bar Chart Visualization**: Simplified UI with bar charts for particle size distribution
- **Enhanced Camera Workflow**: Improved camera view management for better performance

### Changed
- Updated README with comprehensive feature descriptions and UI screenshots
- Improved calibration UI to match updated app design theme
- Switched to median grind size instead of average for brewing recommendations
- Optimized camera view lifecycle - removed from stack immediately after capture

### Fixed
- Fixed camera view hierarchy issues causing performance problems
- Resolved drag gesture bug when panning outside image bounds during calibration
- Fixed recommendation view background color consistency

### Improved
- Added pinch-to-zoom and drag gestures for calibration image
- Updated target size ranges for different grind types
- Enhanced UI consistency with transparent blue overlay for particle detection
- Removed hardcoded legend ranges for better dynamic scaling

[1.2.0-beta.1]: https://github.com/nathan-a-king/GrindLab/releases/tag/v1.2.0-beta.1
