import SwiftUI

struct AccountScreen: View {
    @EnvironmentObject private var session: AppSession
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                // 占位 UI：等我们搞定本地电脑的 Python 脚本，就把真实好友列在这里
                Section("微信好友与群聊") {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("等待接入 PC 微信通讯录...")
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("通讯录")
            .searchable(text: $searchText, prompt: "搜索联系人")
        }
    }
}
