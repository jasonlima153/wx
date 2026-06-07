import SwiftUI

@main
struct WeComStyleIPAApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(session.settings.appearance.colorScheme)
        }
    }
}
