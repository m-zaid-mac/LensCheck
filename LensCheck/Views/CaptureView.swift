import SwiftUI
import PhotosUI
import SwiftData

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = QualityViewModel()
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = viewModel.selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        ContentUnavailableView(
                            "No Image Selected",
                            systemImage: "photo.badge.plus",
                            description: Text("Pick a photo to check its quality")
                        )
                        .frame(height: 300)
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if viewModel.isAnalyzing {
                        ProgressView("Analyzing…")
                    } else if let score = viewModel.latestScore {
                        ResultCardView(score: score)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                .padding()
            }
            .navigationTitle("LensCheck")
            .task(id: pickerItem) {
                guard let pickerItem,
                      let data = try? await pickerItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }

                viewModel.selectedImage = uiImage
                await viewModel.analyzeAndSave(uiImage, context: modelContext)
            }
        }
    }
}

#Preview {
    CaptureView()
}
