import XCTest
@testable import Coffee_Grind_Analyzer

final class Coffee_Grind_AnalyzerTests: XCTestCase {
    func testParticleAccuracySuiteIsDiscoverable() {
        let suite = ParticleAlgorithmsAccuracyTests.defaultTestSuite
        XCTAssertFalse(suite.tests.isEmpty, "Particle accuracy tests should be discoverable by XCTest")
    }
}
