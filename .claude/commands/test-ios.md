---
name: test-ios
description: Run iOS tests with filtering, coverage, and detailed failure analysis
permissions:
  bash: true
---

# iOS Test Runner Command

Run unit and UI tests for the GrindLab app with advanced filtering and analysis.

## Context

- **Test Targets**: Coffee Grind AnalyzerTests (unit), Coffee Grind AnalyzerUITests (UI)
- **Test Framework**: Swift Testing (modern Xcode testing)
- **Simulators Available**: iPhone 15, iPhone 15 Pro, iPad Pro, etc.

## Tasks

1. **Parse user intent**:
   - Specific test class? (e.g., "test CoffeeAnalysisEngine")
   - Test type? (unit tests, UI tests, or both)
   - Specific simulator? (default: iPhone 15)
   - Coverage needed? (--enable-code-coverage)

2. **Build the xcodebuild test command**:
   ```bash
   # All tests
   xcodebuild test \
     -project "Coffee Grind Analyzer.xcodeproj" \
     -scheme "Coffee Grind Analyzer" \
     -destination "platform=iOS Simulator,name=iPhone 15" \
     -enableCodeCoverage YES

   # Specific test class
   xcodebuild test \
     -project "Coffee Grind Analyzer.xcodeproj" \
     -scheme "Coffee Grind Analyzer" \
     -destination "platform=iOS Simulator,name=iPhone 15" \
     -only-testing:"Coffee Grind AnalyzerTests/ClassNameTests"

   # Only UI tests
   xcodebuild test \
     -project "Coffee Grind Analyzer.xcodeproj" \
     -scheme "Coffee Grind Analyzer" \
     -destination "platform=iOS Simulator,name=iPhone 15" \
     -only-testing:"Coffee Grind AnalyzerUITests"
   ```

3. **Analyze test results**:
   - Count: Passed, failed, skipped
   - Failed test details with exact assertion failures
   - Performance test results (if any)
   - Test duration and slowest tests
   - Code coverage percentage (if enabled)

4. **Diagnose test failures**:
   - **Assertion failures**: Show expected vs actual values
   - **Timeout failures**: Identify long-running operations
   - **UI test failures**: Element not found, interaction issues
   - **Flaky tests**: Suggest stability improvements
   - **Setup/teardown issues**: Configuration problems

5. **Provide fix recommendations**:
   - Show failed test code location (file:line)
   - Suggest fixes based on failure type
   - Offer to add missing tests for untested code
   - Recommend mocking strategies for external dependencies

## Test Areas to Focus On

Given GrindLab's architecture:

- **Analysis Engine**: Particle detection, size calculations, statistics
- **Camera Operations**: Image capture, preprocessing
- **Vision Framework**: Coin detection, edge detection
- **Models**: Data persistence, encoding/decoding
- **ViewModels**: State management, timer logic
- **SwiftUI Views**: UI component behavior

## Output Format

```
🧪 Test Results Summary
━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Passed: 42 tests
❌ Failed: 2 tests
⏭️  Skipped: 0 tests
⏱️  Duration: 12.3s

Failed Tests:
━━━━━━━━━━━━━━━━━━━━━━━━━

1. CoffeeAnalysisEngineTests.testParticleDetection()
   File: Coffee Grind AnalyzerTests/AnalysisTests.swift:45
   Error: XCTAssertEqual failed: ("150") is not equal to ("175")

   🔧 Fix: Check calibration factor in particle size calculation

2. BrewTimerTests.testTimerAccuracy()
   File: Coffee Grind AnalyzerTests/TimerTests.swift:23
   Error: Async expectation timed out after 5.0 seconds

   🔧 Fix: Increase timeout or check timer notification posting

Code Coverage: 68.4%
Low coverage areas:
  - ParticleSeparationEngine.swift (34%)
  - AdvancedStatistics.swift (41%)

Next Steps:
  - Fix failing assertions
  - Add tests for low-coverage files
  - Consider adding UI tests for ResultsView
```

## Advanced Options

Users can specify:
- `/test-ios unit` - Run only unit tests
- `/test-ios ui` - Run only UI tests
- `/test-ios AnalysisEngine` - Run tests matching "AnalysisEngine"
- `/test-ios --coverage` - Enable code coverage report
- `/test-ios --verbose` - Show full test output
