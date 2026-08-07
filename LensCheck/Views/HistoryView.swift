import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \QualityResult.date, order: .reverse) private var results: [QualityResult]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { result in
                    HStack(spacing: 12) {
                        if let uiImage = UIImage(data: result.imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        VStack(alignment: .leading) {
                            Text("Score: \(Int(result.overallScore))/100")
                                .font(.headline)
                            Text(result.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(result.analyzerVersion)
                            .font(.caption2)
                            .padding(4)
                            .background(.secondary.opacity(0.15), in: Capsule())
                    }
                }
                .onDelete(perform: deleteResults)
            }
            .navigationTitle("History")
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView("No Results Yet", systemImage: "clock")
                }
            }
        }
    }

    private func deleteResults(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(results[index])
        }
    }
}

#Preview {
    HistoryView()
}
