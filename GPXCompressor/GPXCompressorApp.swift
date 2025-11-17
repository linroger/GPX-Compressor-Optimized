import SwiftUI

@main
struct GPXCompressorApp: App {
    @StateObject private var viewModel = ProcessingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
        .windowResizability(.contentSize)
    }
}
