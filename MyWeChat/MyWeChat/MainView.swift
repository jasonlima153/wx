import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            ConversationListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("微信")
                }

            Text("通讯录：好友与群聊列表")
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("通讯录")
                }

            FunctionsView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("功能")
                }

            Text("设置面板：服务器网络配置")
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("设置")
                }
        }
        .onAppear {
            setupMockData()
        }
    }

    private func setupMockData() {
        let fetchDescriptor = FetchDescriptor<Conversation>()
        let count = (try? modelContext.fetchCount(fetchDescriptor)) ?? 0
        if count == 0 {
            let mock1 = Conversation(id: "wxid_1", name: "文件传输助手", avatar: "folder.fill", lastMessage: "你好，欢迎使用", timestamp: Date())
            let mock2 = Conversation(id: "wxid_2", name: "张小龙", avatar: "person.crop.circle", lastMessage: "新版本做得不错", timestamp: Date().addingTimeInterval(-3600))
            modelContext.insert(mock1)
            modelContext.insert(mock2)
        }
    }
}
