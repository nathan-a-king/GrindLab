import XCTest
import Foundation
import CoreGraphics
@testable import Coffee_Grind_Analyzer

final class ParticleAlgorithmsAccuracyTests: XCTestCase {

    func testSingleParticleFixture() throws {
        let fixture = try ParticleFixture.load(named: "single_particle_fixture")
        let particles = fixture.makeParticles()

        verifyDistribution(for: fixture, particles: particles)
        verifyAnalysis(for: fixture, particles: particles)
    }

    func testTouchingParticlesFixture() throws {
        let fixture = try ParticleFixture.load(named: "touching_particles_fixture")
        let particles = fixture.makeParticles()

        verifyDistribution(for: fixture, particles: particles)
        verifyAnalysis(for: fixture, particles: particles)
        try verifySeparation(for: fixture)
    }

    func testMultiModalDistributionFixture() throws {
        let fixture = try ParticleFixture.load(named: "multi_modal_distribution_fixture")
        let particles = fixture.makeParticles()

        verifyDistribution(for: fixture, particles: particles)
        verifyAnalysis(for: fixture, particles: particles)
        verifyHistogram(for: fixture, particles: particles)
    }

    // MARK: - Verification Helpers

    private func verifyDistribution(for fixture: ParticleFixture, particles: [CoffeeParticle]) {
        let statistics = AdvancedStatistics()
        let distribution = statistics.analyzeDistribution(sizes: particles.map { $0.size })

        compare(distribution.d10, against: fixture.distributionExpectations.d10, message: "D10 mismatch for \(fixture.name)")
        compare(distribution.d50, against: fixture.distributionExpectations.d50, message: "D50 mismatch for \(fixture.name)")
        compare(distribution.d90, against: fixture.distributionExpectations.d90, message: "D90 mismatch for \(fixture.name)")
        compare(distribution.span, against: fixture.distributionExpectations.span, message: "Span mismatch for \(fixture.name)")
        compare(distribution.uniformity, against: fixture.distributionExpectations.uniformity, message: "Uniformity mismatch for \(fixture.name)")
    }

    private func verifyAnalysis(for fixture: ParticleFixture, particles: [CoffeeParticle]) {
        let engine = CoffeeAnalysisEngine()
        let snapshot = engine.evaluateSyntheticParticles(particles, grindType: fixture.grindTypeEnum)

        compare(snapshot.uniformityScore, against: fixture.analysisExpectations.uniformityScore, message: "Uniformity score mismatch for \(fixture.name)")
        compare(snapshot.averageSize, against: fixture.analysisExpectations.averageSize, message: "Average size mismatch for \(fixture.name)")
        compare(snapshot.medianSize, against: fixture.analysisExpectations.medianSize, message: "Median size mismatch for \(fixture.name)")
        compare(snapshot.standardDeviation, against: fixture.analysisExpectations.standardDeviation, message: "Standard deviation mismatch for \(fixture.name)")
        compare(snapshot.finesPercentage, against: fixture.analysisExpectations.finesPercentage, message: "Fines percentage mismatch for \(fixture.name)")
        compare(snapshot.bouldersPercentage, against: fixture.analysisExpectations.bouldersPercentage, message: "Boulders percentage mismatch for \(fixture.name)")
        compare(snapshot.confidence, against: fixture.analysisExpectations.confidence, message: "Confidence mismatch for \(fixture.name)")
    }

    private func verifyHistogram(for fixture: ParticleFixture, particles: [CoffeeParticle]) {
        guard let histogramExpectations = fixture.histogramExpectations else {
            XCTFail("Missing histogram expectations for \(fixture.name)")
            return
        }

        let generator = EnhancedHistogramGenerator()
        let histogram = generator.generateHistogram(
            particles: particles,
            type: histogramExpectations.type,
            pixelScale: fixture.pixelScale,
            logScale: histogramExpectations.logScale,
            binCount: histogramExpectations.binCount
        )

        compare(histogram.average, against: histogramExpectations.average, message: "Histogram average mismatch for \(fixture.name)")
        XCTAssertEqual(histogram.counts.count, histogramExpectations.normalizedCounts.values.count, "Normalized bin count mismatch for \(fixture.name)")

        for (index, expectedValue) in histogramExpectations.normalizedCounts.values.enumerated() {
            let actualValue = histogram.counts[index]
            let difference = abs(actualValue - expectedValue)
            XCTAssertLessThanOrEqual(difference, histogramExpectations.normalizedCounts.tolerance, "Histogram normalized count mismatch in bin \(index) for \(fixture.name)")
        }
    }

    private func verifySeparation(for fixture: ParticleFixture) throws {
        guard let separationFixture = fixture.separationFixture else {
            XCTFail("Missing separation fixture for \(fixture.name)")
            return
        }

        try runSeparationScenario(name: "\(fixture.name)-baseline", scenario: separationFixture.baseScenario)

        for snapshot in separationFixture.regressionSnapshots {
            let scenario = separationFixture.scenario(overriding: snapshot)
            try runSeparationScenario(name: "\(fixture.name)-\(snapshot.name)", scenario: scenario)
        }
    }

    private func runSeparationScenario(name: String, scenario: SeparationScenario) throws {
        let engine = ParticleSeparationEngine()
        let result = engine.separateTouchingParticles(
            clusterPixels: scenario.clusterPixels.map { ($0.x, $0.y, $0.brightness) },
            imageData: scenario.imageData,
            backgroundMedian: scenario.backgroundMedian,
            width: scenario.imageWidth,
            startPixel: scenario.startPixel
        )

        let expected = Set(scenario.expectedRetainedPixels.map { PixelCoordinate(x: $0[0], y: $0[1]) })
        let actual = Set(result.map { PixelCoordinate(x: $0.x, y: $0.y) })

        XCTAssertEqual(actual, expected, "Separated pixels mismatch for scenario \(name)")
    }

    private func compare(_ actual: Double, against expectation: FixtureValue, message: String) {
        let difference = abs(actual - expectation.value)
        XCTAssertLessThanOrEqual(difference, expectation.tolerance, "\(message). Expected \(expectation.value) ± \(expectation.tolerance), got \(actual)")
    }
}

// MARK: - Fixture Models

private struct ParticleFixture: Decodable {
    let name: String
    let grindType: String
    let calibrationMicronsPerPixel: Double
    let pixelScale: Double
    let particles: [ParticleDescriptor]
    let distributionExpectations: DistributionExpectations
    let analysisExpectations: AnalysisExpectations
    let histogramExpectations: HistogramExpectations?
    let separationFixture: SeparationFixture?

    var grindTypeEnum: CoffeeGrindType {
        switch grindType.lowercased() {
        case "filter":
            return .filter
        case "espresso":
            return .espresso
        case "frenchpress":
            return .frenchPress
        case "coldbrew":
            return .coldBrew
        default:
            XCTFail("Unsupported grind type identifier: \(grindType)")
            return .filter
        }
    }

    func makeParticles() -> [CoffeeParticle] {
        particles.map { descriptor in
            CoffeeParticle(
                size: descriptor.sizeMicrons,
                area: descriptor.areaPixels,
                circularity: descriptor.circularity,
                position: CGPoint(x: descriptor.position.x, y: descriptor.position.y),
                brightness: descriptor.brightness,
                pixels: descriptor.pixelCoordinates.map { (x: $0[0], y: $0[1]) }
            )
        }
    }

    static func load(named fileName: String, file: StaticString = #filePath) throws -> ParticleFixture {
        let baseURL = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
        let fixturesURL = baseURL.appendingPathComponent("Fixtures", isDirectory: true)
        let fileURL = fixturesURL.appendingPathComponent("\(fileName).json")
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ParticleFixture.self, from: data)
    }
}

private struct ParticleDescriptor: Decodable {
    let sizeMicrons: Double
    let areaPixels: Double
    let circularity: Double
    let position: Position
    let brightness: Double
    let pixelCoordinates: [[Int]]
}

private struct Position: Decodable {
    let x: Double
    let y: Double
}

private struct DistributionExpectations: Decodable {
    let d10: FixtureValue
    let d50: FixtureValue
    let d90: FixtureValue
    let span: FixtureValue
    let uniformity: FixtureValue
}

private struct AnalysisExpectations: Decodable {
    let uniformityScore: FixtureValue
    let averageSize: FixtureValue
    let medianSize: FixtureValue
    let standardDeviation: FixtureValue
    let finesPercentage: FixtureValue
    let bouldersPercentage: FixtureValue
    let confidence: FixtureValue
}

private struct HistogramExpectations: Decodable {
    let type: HistogramType
    let logScale: Bool
    let binCount: Int?
    let normalizedCounts: ArrayExpectation
    let average: FixtureValue
}

private struct ArrayExpectation: Decodable {
    let values: [Double]
    let tolerance: Double
}

private struct FixtureValue: Decodable {
    let value: Double
    let tolerance: Double
}

private struct SeparationFixture: Decodable {
    let backgroundMedian: Double
    let imageWidth: Int
    let imageHeight: Int
    let imageData: [UInt8]
    let clusterPixels: [ClusterPixel]
    let startPixelIndex: Int
    let expectedRetainedPixels: [[Int]]
    let regressionSnapshots: [RegressionSnapshot]

    struct RegressionSnapshot: Decodable {
        let name: String
        let backgroundMedian: Double?
        let imageData: [UInt8]?
        let clusterPixels: [ClusterPixel]?
        let startPixelIndex: Int?
        let expectedRetainedPixels: [[Int]]?

        private enum CodingKeys: String, CodingKey {
            case name
            case backgroundMedian
            case imageData
            case clusterPixels
            case startPixelIndex
            case expectedRetainedPixels
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            backgroundMedian = try container.decodeIfPresent(Double.self, forKey: .backgroundMedian)
            if let rawData = try container.decodeIfPresent([Int].self, forKey: .imageData) {
                imageData = try rawData.toUInt8Array()
            } else {
                imageData = nil
            }
            clusterPixels = try container.decodeIfPresent([ClusterPixel].self, forKey: .clusterPixels)
            startPixelIndex = try container.decodeIfPresent(Int.self, forKey: .startPixelIndex)
            expectedRetainedPixels = try container.decodeIfPresent([[Int]].self, forKey: .expectedRetainedPixels)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case backgroundMedian
        case imageWidth
        case imageHeight
        case imageData
        case clusterPixels
        case startPixelIndex
        case expectedRetainedPixels
        case regressionSnapshots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        backgroundMedian = try container.decode(Double.self, forKey: .backgroundMedian)
        imageWidth = try container.decode(Int.self, forKey: .imageWidth)
        imageHeight = try container.decode(Int.self, forKey: .imageHeight)
        let rawImageData = try container.decode([Int].self, forKey: .imageData)
        imageData = try rawImageData.toUInt8Array()
        clusterPixels = try container.decode([ClusterPixel].self, forKey: .clusterPixels)
        startPixelIndex = try container.decode(Int.self, forKey: .startPixelIndex)
        expectedRetainedPixels = try container.decode([[Int]].self, forKey: .expectedRetainedPixels)
        regressionSnapshots = try container.decode([RegressionSnapshot].self, forKey: .regressionSnapshots)
    }

    var baseScenario: SeparationScenario {
        SeparationScenario(
            name: "baseline",
            backgroundMedian: backgroundMedian,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            imageData: imageData,
            clusterPixels: clusterPixels,
            startPixelIndex: startPixelIndex,
            expectedRetainedPixels: expectedRetainedPixels
        )
    }

    func scenario(overriding snapshot: RegressionSnapshot) -> SeparationScenario {
        SeparationScenario(
            name: snapshot.name,
            backgroundMedian: snapshot.backgroundMedian ?? backgroundMedian,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            imageData: snapshot.imageData ?? imageData,
            clusterPixels: snapshot.clusterPixels ?? clusterPixels,
            startPixelIndex: snapshot.startPixelIndex ?? startPixelIndex,
            expectedRetainedPixels: snapshot.expectedRetainedPixels ?? expectedRetainedPixels
        )
    }
}

private struct SeparationScenario {
    let name: String
    let backgroundMedian: Double
    let imageWidth: Int
    let imageHeight: Int
    let imageData: [UInt8]
    let clusterPixels: [ClusterPixel]
    let startPixelIndex: Int
    let expectedRetainedPixels: [[Int]]

    var startPixel: (x: Int, y: Int, brightness: UInt8) {
        precondition(clusterPixels.indices.contains(startPixelIndex), "Start pixel index \(startPixelIndex) out of range")
        let pixel = clusterPixels[startPixelIndex]
        return (pixel.x, pixel.y, pixel.brightness)
    }
}

private struct ClusterPixel: Decodable {
    let x: Int
    let y: Int
    let brightness: UInt8

    private enum CodingKeys: String, CodingKey {
        case x
        case y
        case brightness
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(Int.self, forKey: .x)
        y = try container.decode(Int.self, forKey: .y)
        let brightnessValue = try container.decode(Int.self, forKey: .brightness)
        guard (0...255).contains(brightnessValue) else {
            throw DecodingError.dataCorruptedError(forKey: .brightness, in: container, debugDescription: "Brightness must be between 0 and 255")
        }
        brightness = UInt8(brightnessValue)
    }
}

private struct PixelCoordinate: Hashable {
    let x: Int
    let y: Int
}

private extension Array where Element == Int {
    func toUInt8Array() throws -> [UInt8] {
        try map { value in
            guard (0...255).contains(value) else {
                throw NSError(domain: "ParticleFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Value \(value) outside UInt8 range"])
            }
            return UInt8(value)
        }
    }
}
