import SwiftUI
import SwiftData

/// Holds the picked image and the in-progress/finished score. Views read
/// from this and call analyzeAndSave — they never talk to the analyzer
/// or SwiftData directly.
@Observable
final class QualityViewModel {
    var selectedImage: UIImage?
    var latestScore: QualityScore?
    var isAnalyzing = false
    var errorMessage: String?

    private let analyzer: QualityAnalyzing

    // Swap HeuristicQualityAnalyzer() for CoreMLQualityAnalyzer() here
    // once the v2 model is ready — nothing else in the app changes.
    init(analyzer: QualityAnalyzing = CoreMLQualityAnalyzer()) {
        self.analyzer = analyzer
    }

    @MainActor
    func analyzeAndSave(_ image: UIImage, context: ModelContext) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        do {
            let score = try await analyzer.analyze(image)
            latestScore = score

            let data = image.jpegData(compressionQuality: 0.7) ?? Data()
            let result = QualityResult(
                imageData: data,
                sharpnessScore: score.sharpness,
                exposureScore: score.exposure,
                overallScore: score.overall,
                analyzerVersion: analyzer.version
            )
            context.insert(result)
        } catch {
            errorMessage = "Couldn't analyze that image — try another one."
        }
    }
}
