"""
Swift Test Generation Helpers

Utilities for generating Swift test code, mock data, and test fixtures.
"""

import re
from typing import List, Dict, Optional


def parse_swift_methods(swift_code: str) -> List[Dict[str, str]]:
    """
    Parse Swift code to extract method signatures.

    Args:
        swift_code: Swift source code as string

    Returns:
        List of dicts with method info: {'name', 'params', 'return_type', 'access'}
    """
    methods = []

    # Pattern for Swift function declarations
    # Matches: func methodName(param: Type) -> ReturnType
    pattern = r'(public|private|internal|fileprivate)?\s*func\s+(\w+)\s*\((.*?)\)\s*(?:->\s*([^\{]+))?'

    matches = re.finditer(pattern, swift_code, re.MULTILINE)

    for match in matches:
        access_level = match.group(1) or 'internal'
        method_name = match.group(2)
        params = match.group(3).strip()
        return_type = match.group(4).strip() if match.group(4) else 'Void'

        # Skip test methods themselves
        if method_name.startswith('test'):
            continue

        methods.append({
            'name': method_name,
            'params': params,
            'return_type': return_type,
            'access': access_level
        })

    return methods


def generate_test_name(method_name: str, condition: str, expected: str) -> str:
    """
    Generate a test method name following Swift testing conventions.

    Args:
        method_name: Name of method being tested
        condition: The test condition (e.g., "withValidInput")
        expected: Expected result (e.g., "returnsCorrectValue")

    Returns:
        Test method name like "test_methodName_withValidInput_returnsCorrectValue"

    Example:
        >>> generate_test_name("analyzeImage", "withNilImage", "returnsNil")
        'test_analyzeImage_withNilImage_returnsNil'
    """
    # Capitalize first letter of method name for readability
    formatted_method = method_name[0].upper() + method_name[1:] if method_name else ''

    return f"test_{formatted_method}_{condition}_{expected}"


def generate_mock_analysis_result() -> str:
    """
    Generate Swift code for a mock CoffeeAnalysisResult.

    Returns:
        Swift code string for creating a test fixture
    """
    return '''
    func createMockAnalysisResult() -> CoffeeAnalysisResult {
        return CoffeeAnalysisResult(
            id: UUID(),
            timestamp: Date(),
            particleCount: 250,
            meanSize: 425.0,
            medianSize: 400.0,
            standardDeviation: 75.0,
            grindType: .filter,
            uniformityCoefficient: 0.82,
            distribution: [
                200: 15,
                300: 35,
                400: 50,
                500: 40,
                600: 20
            ]
        )
    }
    '''


def generate_mock_image_swift() -> str:
    """
    Generate Swift code for creating a test UIImage.

    Returns:
        Swift code string for creating a mock image
    """
    return '''
    func createTestImage(withParticles count: Int = 100) -> UIImage {
        let size = CGSize(width: 1000, height: 1000)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw random particles
            UIColor.black.setFill()
            for _ in 0..<count {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let diameter = CGFloat.random(in: 3...8)

                let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                context.cgContext.fillEllipse(in: rect)
            }
        }
    }
    '''


def generate_test_class_template(
    class_name: str,
    target_class: str,
    imports: Optional[List[str]] = None
) -> str:
    """
    Generate a complete XCTest class template.

    Args:
        class_name: Name of test class (e.g., "CoffeeAnalysisEngineTests")
        target_class: Name of class being tested
        imports: Additional imports needed

    Returns:
        Swift test class template
    """
    import_statements = "\n".join(imports or [])

    template = f'''import XCTest
@testable import Coffee_Grind_Analyzer
{import_statements}

final class {class_name}: XCTestCase {{
    var sut: {target_class}!

    override func setUp() {{
        super.setUp()
        sut = {target_class}()
    }}

    override func tearDown() {{
        sut = nil
        super.tearDown()
    }}

    // MARK: - Test Methods

    func testExample() {{
        // Given

        // When

        // Then
        XCTAssertNotNil(sut)
    }}

    // MARK: - Helper Methods

    private func createTestData() -> Data {{
        return Data()
    }}
}}
'''
    return template


def suggest_test_cases(method_name: str, params: str, return_type: str) -> List[str]:
    """
    Suggest test cases for a given method signature.

    Args:
        method_name: Name of the method
        params: Method parameters string
        return_type: Return type of the method

    Returns:
        List of suggested test case descriptions
    """
    suggestions = []

    # Always test happy path
    suggestions.append(f"test_{method_name}_withValidInput_returnsExpectedResult")

    # Test nil/optional handling if params suggest optionals
    if '?' in params or 'Optional' in params:
        suggestions.append(f"test_{method_name}_withNilInput_handlesGracefully")

    # Test empty collections
    if 'Array' in params or '[' in params:
        suggestions.append(f"test_{method_name}_withEmptyArray_returnsExpectedDefault")

    # Test boundary values for numeric types
    if any(t in params for t in ['Int', 'Double', 'Float', 'CGFloat']):
        suggestions.append(f"test_{method_name}_withZeroValue_handlesCorrectly")
        suggestions.append(f"test_{method_name}_withNegativeValue_handlesCorrectly")

    # Test error cases if throws
    if 'throws' in return_type or 'Result' in return_type:
        suggestions.append(f"test_{method_name}_withInvalidInput_throwsError")

    # Test async completion
    if 'async' in return_type or 'completion' in params.lower():
        suggestions.append(f"test_{method_name}_completesSuccessfully")

    return suggestions


def generate_mock_vision_request() -> str:
    """
    Generate Swift code for mocking Vision framework requests.

    Returns:
        Swift code for Vision framework test helper
    """
    return '''
    class MockVisionRequest: VNImageBasedRequest {
        var mockResults: [VNObservation] = []

        override func perform(on image: CVPixelBuffer) throws {
            // Mock implementation
            self.results = mockResults
        }
    }

    func createMockRectangleObservation(
        confidence: Float = 0.95,
        boundingBox: CGRect = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
    ) -> VNRectangleObservation {
        // This is a simplified mock - actual implementation would need more detail
        let observation = VNRectangleObservation(
            requestRevision: 1,
            boundingBox: boundingBox
        )
        return observation
    }
    '''


def generate_assertions_for_type(swift_type: str, variable_name: str = "result") -> List[str]:
    """
    Generate appropriate XCTest assertions for a given Swift type.

    Args:
        swift_type: The Swift type (e.g., "Int", "String?", "[Double]")
        variable_name: Name of variable to assert on

    Returns:
        List of assertion code strings
    """
    assertions = []

    if '?' in swift_type:
        assertions.append(f"XCTAssertNotNil({variable_name})")
    else:
        assertions.append(f"// {variable_name} is non-optional")

    # Numeric types
    if any(t in swift_type for t in ['Int', 'Double', 'Float', 'CGFloat']):
        assertions.append(f"XCTAssertGreaterThan({variable_name}, 0)")
        assertions.append(f"XCTAssertEqual({variable_name}, expectedValue, accuracy: 0.01)")

    # Boolean
    if 'Bool' in swift_type:
        assertions.append(f"XCTAssertTrue({variable_name})")
        assertions.append(f"XCTAssertFalse({variable_name})")

    # Collections
    if any(t in swift_type for t in ['Array', '[', 'Set']):
        assertions.append(f"XCTAssertFalse({variable_name}.isEmpty)")
        assertions.append(f"XCTAssertEqual({variable_name}.count, expectedCount)")

    # Strings
    if 'String' in swift_type:
        assertions.append(f'XCTAssertEqual({variable_name}, "expected")')
        assertions.append(f'XCTAssertTrue({variable_name}.contains("expected"))')

    return assertions


def calculate_test_coverage_needed(method_count: int) -> Dict[str, int]:
    """
    Calculate recommended test coverage.

    Args:
        method_count: Number of methods in the class

    Returns:
        Dict with coverage recommendations
    """
    # Aim for 3-5 tests per method on average
    min_tests = method_count * 2
    recommended_tests = method_count * 3
    comprehensive_tests = method_count * 5

    return {
        'method_count': method_count,
        'minimum_tests': min_tests,
        'recommended_tests': recommended_tests,
        'comprehensive_tests': comprehensive_tests,
        'coverage_target': 80  # 80% code coverage target
    }


# Example usage
if __name__ == "__main__":
    # Example Swift code
    sample_code = '''
    class CoffeeAnalyzer {
        func analyzeImage(_ image: UIImage?) -> AnalysisResult? {
            guard let image = image else { return nil }
            return performAnalysis(on: image)
        }

        private func performAnalysis(on image: UIImage) -> AnalysisResult {
            return AnalysisResult()
        }

        func calculateMean(_ values: [Double]) -> Double {
            return values.reduce(0, +) / Double(values.count)
        }
    }
    '''

    methods = parse_swift_methods(sample_code)
    print("Found methods:")
    for method in methods:
        print(f"  - {method['name']}: {method['params']} -> {method['return_type']}")
        print(f"    Suggested tests:")
        for suggestion in suggest_test_cases(method['name'], method['params'], method['return_type']):
            print(f"      - {suggestion}")
