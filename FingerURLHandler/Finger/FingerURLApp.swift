import SwiftUI

@main
struct FingerURLApp: App {
    @StateObject private var model = FingerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onOpenURL { url in
                    model.handle(url: url)
                }
        }
    }
}
