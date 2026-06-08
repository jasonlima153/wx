import SwiftUI

struct RootView: View {
    enum TabItem: Hashable {
        case chats, accounts, schedules, settings
    }

    @EnvironmentObject private var session: AppSession
    @State private var tab: TabItem = .chats

    var body: some View {
        TabView(selection: $tab) {
            ChatListScreen()
                .tabItem { Label("会话", systemImage: "bubble.left.and.bubble.right") }
                .tag(TabItem.chats)

            AccountScreen()
                .tabItem { Label("通讯录", systemImage: "person.crop.circle") }
                .tag(TabItem.accounts)

            ScheduleListScreen()
                .tabItem { Label("定时", systemImage: "clock") }
                .tag(TabItem.schedules)

            SettingsScreen()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(TabItem.settings)
        }
        .overlay(alignment: .top) {
            if let err = session.lastError {
                ErrorBanner(text: err)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { session.connect() }
        .onDisappear { session.persistAll() }
    }
}
