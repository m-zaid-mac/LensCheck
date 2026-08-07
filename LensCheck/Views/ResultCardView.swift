import SwiftUI

struct ResultCardView: View {
    let score: QualityScore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            scoreRow("Overall", value: score.overall, color: .accentColor)
            scoreRow("Sharpness", value: score.sharpness, color: .blue)
            scoreRow("Exposure", value: score.exposure, color: .orange)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func scoreRow(_ label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline.bold())
                Spacer()
                Text("\(Int(value))/100").font(.subheadline.monospacedDigit())
            }
            ProgressView(value: value, total: 100)
                .tint(color)
        }
    }
}

#Preview {
    ResultCardView(score: QualityScore(sharpness: 72, exposure: 85))
        .padding()
}
