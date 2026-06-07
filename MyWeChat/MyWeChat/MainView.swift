import SwiftUI
import SwiftData

struct MainView: View {
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
    }
}
