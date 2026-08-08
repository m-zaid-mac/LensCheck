import UIKit
import Vision
import CoreML

/// v2 analyzer: runs the trained LensCheckQuality Core ML model on-device
/// via the Vision framework.
///
/// Setup required before this will work:
/// 1. Run the ML pipeline (see lenscheck-ml/PIPELINE.md) to produce
///    LensCheckQuality.mlpackage.
/// 2. Drag that file into the Xcode project (target: LensCheck).
/// 3. Build once (Cmd+B) so Xcode generates the `LensCheckQuality` Swift
///    class this file references below.
///
/// If you named your .mlpackage something other than "LensCheckQuality",
/// update the type name below to match.
final class CoreMLQualityAnalyzer: QualityAnalyzing {
    let version = "coreml-v1"
    private let visionModel: VNCoreMLModel?

    init() {
        if let mlModel = try? LensCheckQuality(configuration: MLModelConfiguration()).model,
           let visionModel = try? VNCoreMLModel(for: mlModel) {
            self.visionModel = visionModel
        } else {
            self.visionModel = nil
            print("⚠️ CoreMLQualityAnalyzer: couldn't load LensCheckQuality.mlpackage. " +
                  "Make sure it's added to the project target and you've built at least once.")
        }
    }

    func analyze(_ image: UIImage) async throws -> QualityScore {
        guard let visionModel else {
            throw AnalyzerError.processingFailed
        }
        guard let cgImage = image.cgImage else {
            throw AnalyzerError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                      let multiArray = results.first?.featureValue.multiArrayValue,
                      multiArray.count >= 2 else {
                    continuation.resume(throwing: AnalyzerError.processingFailed)
                    return
                }

                let sharpness = multiArray[0].doubleValue
                let exposure = multiArray[1].doubleValue
                continuation.resume(returning: QualityScore(sharpness: sharpness, exposure: exposure))
            }
            // The model was trained on square 224x224 crops — scaleFill
            // matches how Core Image / Vision will resize input to fit.
            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
