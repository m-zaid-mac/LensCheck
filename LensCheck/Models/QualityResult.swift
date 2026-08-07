import Foundation
import SwiftData

/// One saved quality check. SwiftData persists this to disk automatically —
/// no manual file or database code needed.
@Model
final class QualityResult {
    var id: UUID
    var date: Date
    var imageData: Data          // thumbnail/original, so History can render it
    var sharpnessScore: Double   // 0-100, higher = sharper
    var exposureScore: Double    // 0-100, higher = better exposed
    var overallScore: Double     // weighted combination of the above
    var analyzerVersion: String  // e.g. "heuristic-v1" or "coreml-v1" —
                                  // lets the History screen show which
                                  // analyzer produced each result once you
                                  // add the Core ML version

    init(imageData: Data, sharpnessScore: Double, exposureScore: Double,
         overallScore: Double, analyzerVersion: String) {
        self.id = UUID()
        self.date = .now
        self.imageData = imageData
        self.sharpnessScore = sharpnessScore
        self.exposureScore = exposureScore
        self.overallScore = overallScore
        self.analyzerVersion = analyzerVersion
    }
}
