import UIKit
import Vision
// import CoreML — drag your trained .mlpackage into the project first,
// Xcode auto-generates a Swift class for it, then reference that class here.

/// v2, built after the heuristic version ships: swap in a trained Core ML
/// model for perceptual quality scoring. Because this and
/// HeuristicQualityAnalyzer both conform to QualityAnalyzing, switching
/// which one QualityViewModel uses is a single line change in its
/// initializer — nothing else in the app needs to know.
///
/// Suggested path to get a model here:
/// 1. Train or fine-tune a small quality-assessment model in PyTorch
///    (transfer learning from something like MobileNetV3 keeps it light).
/// 2. Convert it with coremltools (`coremltools.convert(...)`) to .mlpackage.
/// 3. Add it to the Xcode project, then run inference through
///    VNCoreMLRequest + VNImageRequestHandler below.
final class CoreMLQualityAnalyzer: QualityAnalyzing {
    let version = "coreml-v1"

    func analyze(_ image: UIImage) async throws -> QualityScore {
        // TODO once the model is added:
        // 1. Convert `image` to a CVPixelBuffer sized to the model's input
        // 2. let request = VNCoreMLRequest(model: yourModel)
        // 3. try VNImageRequestHandler(cgImage: image.cgImage!).perform([request])
        // 4. Map request.results to a QualityScore
        throw AnalyzerError.processingFailed
    }
}
