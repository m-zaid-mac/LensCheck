import UIKit
import CoreImage

/// v1 analyzer: no trained model required, so this is what you ship first.
/// Sharpness is estimated with an edge-detection convolution (blurry images
/// lose high-frequency edge detail; sharp images keep it). Exposure is
/// estimated from average scene brightness relative to a mid-gray target.
final class HeuristicQualityAnalyzer: QualityAnalyzing {
    let version = "heuristic-v1"
    private let context = CIContext()

    func analyze(_ image: UIImage) async throws -> QualityScore {
        guard let ciImage = CIImage(image: image) else {
            throw AnalyzerError.invalidImage
        }

        let sharpness = try sharpnessScore(for: ciImage)
        let exposure = try exposureScore(for: ciImage)

        return QualityScore(sharpness: sharpness, exposure: exposure)
    }

    private func sharpnessScore(for image: CIImage) throws -> Double {
        let grayscale = image.applyingFilter("CIPhotoEffectMono")

        // A Laplacian-style kernel: strong response where edges/detail exist,
        // near-zero response over flat, blurry regions.
        let kernel: [CGFloat] = [
             0, -1,  0,
            -1,  4, -1,
             0, -1,  0
        ]
        let convolved = grayscale.applyingFilter("CIConvolution3X3", parameters: [
            "inputWeights": CIVector(values: kernel, count: 9),
            "inputBias": 0
        ])

        // Deliberately NOT converting to sRGB here: convolution output can
        // fall outside the normal 0-1 range, and forcing it into gamma space
        // would clip that signal. This just needs a consistent relative
        // measure of edge energy, not a perceptually-accurate brightness.
        guard let edgeEnergy = averageBrightness(of: convolved) else {
            throw AnalyzerError.processingFailed
        }

        // Empirically-tuned scaling factor — tune this against a small set
        // of known-sharp vs. known-blurry test photos once you're testing
        // on-device.
        let normalized = min(max(edgeEnergy / 40.0, 0), 1) * 100
        return normalized
    }

    private func exposureScore(for image: CIImage) throws -> Double {
        // Explicitly render into sRGB gamma space here, since we're comparing
        // against a target brightness (128) that only means what we want it
        // to mean in gamma-encoded terms — the same terms a photo's raw
        // pixel values are stored in. Without this, Core Image's internal
        // linear-light math makes every image read as artificially dark.
        guard let brightness = averageBrightness(of: image, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else {
            throw AnalyzerError.processingFailed
        }
        let target: CGFloat = 128 // mid-gray, out of 0-255
        let distance = abs(brightness - target)
        let normalized = max(0, 100 - (distance / target * 100))
        return normalized
    }

    private func averageBrightness(of image: CIImage, colorSpace: CGColorSpace? = nil) -> CGFloat? {
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: image.extent)
        ]), let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8, colorSpace: colorSpace)
        return CGFloat(pixel[0])
    }
}
