import SwiftUI
import SwiftData

@main
struct MyWeChatApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(for: [Conversation.self, Message.self])
    }
}
