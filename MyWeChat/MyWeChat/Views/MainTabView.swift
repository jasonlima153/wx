import SwiftUI

// MARK: - 主Tab视图
struct MainTabView: View {
    @StateObject private var wsManager = WebSocketManager.shared

    var body: some View {
        TabView {
            ConversationListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("微信")
                }

            ScheduledTasksView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("群发")
                }

            AccountSelectionView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("账号")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("设置")
                }
        }
        .accentColor(.green)
        .onAppear {
            NotificationService.shared.requestAuthorization()
        }
    }
}
