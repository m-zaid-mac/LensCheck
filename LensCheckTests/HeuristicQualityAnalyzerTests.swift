import XCTest
@testable import LensCheck

final class HeuristicQualityAnalyzerTests: XCTestCase {

    var analyzer: HeuristicQualityAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = HeuristicQualityAnalyzer()
    }

    func testAnalyzeReturnsScoreWithinValidRange() async throws {
        let image = try makeSolidColorImage(color: .gray, size: CGSize(width: 200, height: 200))

        let score = try await analyzer.analyze(image)

        XCTAssertGreaterThanOrEqual(score.sharpness, 0)
        XCTAssertLessThanOrEqual(score.sharpness, 100)
        XCTAssertGreaterThanOrEqual(score.exposure, 0)
        XCTAssertLessThanOrEqual(score.exposure, 100)
    }

    func testMidGrayImageScoresWellOnExposure() async throws {
        // A flat mid-gray image should score close to well-exposed,
        // since 128 is the target brightness in exposureScore().
        let image = try makeSolidColorImage(color: UIColor(white: 0.5, alpha: 1), size: CGSize(width: 200, height: 200))

        let score = try await analyzer.analyze(image)

        XCTAssertGreaterThan(score.exposure, 80, "Mid-gray should score high on exposure")
    }

    func testVeryDarkImageScoresPoorlyOnExposure() async throws {
        let image = try makeSolidColorImage(color: .black, size: CGSize(width: 200, height: 200))

        let score = try await analyzer.analyze(image)

        XCTAssertLessThan(score.exposure, 30, "A fully black image should score low on exposure")
    }

    func testFlatColorImageScoresLowOnSharpness() async throws {
        // A single flat color has no edges at all, so sharpness should be near zero.
        let image = try makeSolidColorImage(color: .white, size: CGSize(width: 200, height: 200))

        let score = try await analyzer.analyze(image)

        XCTAssertLessThan(score.sharpness, 20, "A flat, edge-free image should score low on sharpness")
    }

    func testInvalidImageThrows() async {
        let emptyImage = UIImage()

        await XCTAssertThrowsErrorAsync {
            try await analyzer.analyze(emptyImage)
        }
    }

    // MARK: - Helpers

    private func makeSolidColorImage(color: UIColor, size: CGSize) throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// Small helper since XCTAssertThrowsError doesn't have an async variant built in.
func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail(message.isEmpty ? "Expected an error to be thrown" : message, file: file, line: line)
    } catch {
        // Expected — test passes.
    }
}
