import UIKit

struct QualityScore {
    let sharpness: Double   // 0-100
    let exposure: Double    // 0-100
    var overall: Double { (sharpness * 0.6) + (exposure * 0.4) }
}

enum AnalyzerError: Error {
    case invalidImage
    case processingFailed
}

/// Anything that can look at an image and return a quality score.
/// The ViewModel only ever talks to this protocol, never to a concrete
/// analyzer directly — so swapping HeuristicQualityAnalyzer for
/// CoreMLQualityAnalyzer later is a one-line change, not a rewrite.
protocol QualityAnalyzing {
    var version: String { get }
    func analyze(_ image: UIImage) async throws -> QualityScore
}
