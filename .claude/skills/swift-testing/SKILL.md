# Swift Testing Skill

Generate comprehensive unit tests for Swift code, especially for iOS apps using SwiftUI, Vision framework, and complex data models.

## When to Activate

This skill activates when:
- User asks to "write tests", "add tests", "generate tests"
- User mentions "test coverage", "unit tests", "XCTest"
- User asks to test specific Swift files or classes
- Discussion involves testing strategies for iOS code

## Capabilities

### 1. Swift Test Generation
- Generate XCTest classes for Swift code
- Create test cases using modern Swift Testing framework (@Test macro)
- Mock external dependencies (camera, Vision framework, network)
- Generate test fixtures and sample data

### 2. iOS-Specific Testing
- **SwiftUI View Tests**: Test view hierarchies, state changes, user interactions
- **Vision Framework Tests**: Mock vision requests, test image processing
- **AVFoundation Tests**: Mock camera operations, test video capture
- **Core Image Tests**: Test image filters and transformations
- **UserDefaults/Persistence**: Test data storage and retrieval

### 3. Test Patterns

**Analysis Engine Tests**:
```swift
import XCTest
@testable import Coffee_Grind_Analyzer

final class CoffeeAnalysisEngineTests: XCTestCase {
    var sut: CoffeeAnalysisEngine!

    override func setUp() {
        super.setUp()
        sut = CoffeeAnalysisEngine()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testParticleDetection_WithValidImage_ReturnsParticles() {
        // Given
        let testImage = createTestImage(withParticles: 100)

        // When
        let result = sut.analyzeImage(testImage)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result.particleCount, 100, accuracy: 10)
    }

    func testGrindSizeCalculation_WithCoinCalibration_ReturnsAccurateSize() {
        // Given
        let coinDiameter: Double = 21.21 // US quarter in mm
        let pixelRatio = calculatePixelRatio(coinDiameter: coinDiameter)

        // When
        let grindSize = sut.calculateGrindSize(pixelRatio: pixelRatio)

        // Then
        XCTAssertGreaterThan(grindSize, 0)
        XCTAssertLessThan(grindSize, 2000) // Reasonable range
    }
}
```

**Model Tests**:
```swift
import XCTest
@testable import Coffee_Grind_Analyzer

final class CoffeeModelsTests: XCTestCase {
    func testCoffeeAnalysisResult_Encoding_RoundTrip() throws {
        // Given
        let original = CoffeeAnalysisResult(
            particleCount: 500,
            meanSize: 450.0,
            medianSize: 425.0,
            standardDeviation: 75.0
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CoffeeAnalysisResult.self, from: data)

        // Then
        XCTAssertEqual(original.particleCount, decoded.particleCount)
        XCTAssertEqual(original.meanSize, decoded.meanSize, accuracy: 0.01)
    }
}
```

**ViewModel Tests**:
```swift
import XCTest
@testable import Coffee_Grind_Analyzer

final class TimerVMTests: XCTestCase {
    var sut: TimerVM!

    func testStartTimer_UpdatesTimeElapsed() {
        // Given
        sut = TimerVM()
        let expectation = XCTestExpectation(description: "Timer updates")

        // When
        sut.startTimer()

        // Wait for timer to tick
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            // Then
            XCTAssertGreaterThan(self.sut.timeElapsed, 1.0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}
```

**SwiftUI View Tests**:
```swift
import XCTest
import SwiftUI
@testable import Coffee_Grind_Analyzer

final class ResultsViewTests: XCTestCase {
    func testResultsView_WithAnalysisResult_DisplaysCorrectly() {
        // Given
        let result = CoffeeAnalysisResult(
            particleCount: 250,
            meanSize: 400.0,
            medianSize: 380.0,
            standardDeviation: 50.0
        )

        // When
        let view = ResultsView(analysisResult: result)

        // Then
        let hostingController = UIHostingController(rootView: view)
        XCTAssertNotNil(hostingController.view)

        // Verify view hierarchy contains expected elements
        // (This is simplified - real view testing would use ViewInspector)
    }
}
```

### 4. Mock Generators

Use `test_helpers.py` to generate mock data:
- Mock images with known properties
- Mock Vision framework responses
- Mock camera capture sessions
- Mock analysis results for UI testing

### 5. Test Coverage Analysis

After generating tests, suggest:
- Which critical paths need coverage
- Edge cases to test (nil handling, empty data, invalid input)
- Performance tests for expensive operations
- UI tests for critical user flows

## GrindLab-Specific Testing Focus

### High Priority Test Areas
1. **CoffeeAnalysisEngine** - Core analysis logic (currently untested)
2. **ParticleSeparationEngine** - Particle detection algorithms
3. **AdvancedStatistics** - Statistical calculations
4. **CoffeeAnalysisHistory** - Persistence and data retrieval
5. **TimerVM** - Timer accuracy and state management
6. **CoffeeModels** - Data model encoding/decoding

### Test Data Requirements
- Sample coffee grind images (various grind sizes)
- Coin calibration test images
- Edge cases: blurry images, no particles, over-saturated
- Different grind types: espresso, filter, french press

### Mocking Strategies
- **Vision Framework**: Mock VNImageRequestHandler, VNRequest
- **Camera**: Mock AVCaptureDevice, AVCaptureSession
- **Core Image**: Use small test images, mock CIImage
- **UserDefaults**: Use test suite-specific defaults

## Usage Instructions

When user requests tests:

1. **Analyze the target file**:
   - Read the Swift file to understand its structure
   - Identify classes, methods, and dependencies
   - Note any complex logic or calculations

2. **Generate test structure**:
   - Create test class with proper imports
   - Add setUp/tearDown for test isolation
   - Generate test methods following naming convention

3. **Create test cases**:
   - **Happy path**: Normal operation with valid inputs
   - **Edge cases**: Boundary values, empty data, nil
   - **Error cases**: Invalid input, expected failures
   - **Integration**: Component interactions

4. **Add assertions**:
   - Use appropriate XCTAssert methods
   - Test both output values and side effects
   - Verify state changes

5. **Generate mocks if needed**:
   - Use Python helper to create mock data
   - Create mock classes for dependencies
   - Set up test fixtures

6. **Provide test summary**:
   - Explain what each test validates
   - Note any assumptions or limitations
   - Suggest additional tests if needed

## Python Helper

The `test_helpers.py` file provides utilities for:
- Generating test fixture code
- Creating mock data structures
- Parsing Swift files to identify testable methods
- Suggesting test names based on method signatures

## Best Practices

- **Test Naming**: `test_methodName_withCondition_expectedResult()`
- **Arrange-Act-Assert**: Clear three-phase structure
- **Test Isolation**: Each test should be independent
- **Fast Tests**: Mock expensive operations (camera, Vision)
- **Readable**: Tests should document expected behavior
- **Maintainable**: Update tests when code changes

## Example Usage

**User**: "Add tests for CoffeeAnalysisEngine"

**Response**:
1. Read `Coffee Grind Analyzer/Analysis/CoffeeAnalysisEngine.swift`
2. Identify key methods: `analyzeImage()`, `detectParticles()`, etc.
3. Generate `Coffee Grind AnalyzerTests/CoffeeAnalysisEngineTests.swift`
4. Create 8-10 test methods covering main functionality
5. Add helper methods for creating test images
6. Explain test coverage and suggest additional tests

## Integration with /test-ios

After generating tests:
- Suggest running `/test-ios` to verify new tests pass
- Use test results to refine generated tests
- Iterate until all tests pass
