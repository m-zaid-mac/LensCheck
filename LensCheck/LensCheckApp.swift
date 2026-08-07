import SwiftUI
import SwiftData

@main
struct LensCheckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: QualityResult.self)
    }
}
