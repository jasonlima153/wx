import SwiftUI

struct RootView: View {
    @StateObject private var session = AppSession()

    var body: some View {
        TabView {
            // 1. 会话列表页 (原有的，保持不变，它会自动接收并展现独立房间)
            ChatListScreen()
                .tabItem { Label("微信会话", systemImage: "message.fill") }
            
            // 2. 通讯录页 (已完美替换为 PC 微信真实联系人)
            AccountScreen()
                .tabItem { Label("通讯录", systemImage: "person.crop.circle.fill") }
            
            // 3. 定时群发中心 (全新深度定制页面)
            ScheduleListScreen()
                .tabItem { Label("定时功能", systemImage: "clock.fill") }
            
            // 4. 系统设置页 (原有的，用于看网络连接状态)
            SettingsScreen()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .environmentObject(session) // 🌟 极其重要：将响应式核心注入所有子页面
    }
}
