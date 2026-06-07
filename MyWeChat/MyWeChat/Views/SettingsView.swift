import SwiftUI

// MARK: - 新建聊天视图
struct NewChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String = ""

    let quickContacts = ["张三", "李四", "王五", "赵六", "文件传输助手", "工作群", "项目组"]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("输入联系人")) {
                    TextField("联系人名称", text: $name)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Section(header: Text("快速选择")) {
                    ForEach(quickContacts, id: \.self) { contact in
                        Button(action: { name = contact }) {
                            HStack {
                                Image(systemName: contact == "工作群" || contact == "项目组" ? "person.2.circle.fill" : "person.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))
                                Text(contact)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("新建聊天")
            .navigationBarItems(
                leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("开始") {
                    if !name.isEmpty {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(name.isEmpty)
            )
        }
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var serverURL: String = ""
    @State private var showConnected = false

    var body: some View {
        NavigationView {
            Form {
                // 服务器配置
                Section(header: Text("服务器配置")) {
                    HStack {
                        Text("WebSocket 地址")
                        Spacer()
                        Circle()
                            .fill(wsManager.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                    }

                    TextField("ws://your-server:8000/ws", text: $serverURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)

                    Button(action: connectServer) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                            Text("连接服务器")
                        }
                    }

                    if let error = wsManager.connectionError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // 当前账号
                Section(header: Text("当前账号")) {
                    HStack {
                        Text("账号 ID")
                        Spacer()
                        Text(wsManager.currentAccountID.isEmpty ? "未选择" : wsManager.currentAccountID)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                // 数据管理
                Section(header: Text("数据管理")) {
                    Button(action: clearCache) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("清除本地缓存")
                        }
                        .foregroundColor(.red)
                    }
                }

                // 关于
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("2.0.0")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("构建")
                        Spacer()
                        Text("完整版")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear {
                serverURL = wsManager.serverURL
            }
            .alert(isPresented: $showConnected) {
                Alert(
                    title: Text("连接状态"),
                    message: Text(wsManager.isConnected ? "✅ 连接成功" : "❌ 连接失败，请检查地址"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }

    private func connectServer() {
        wsManager.setServerURL(serverURL)
        wsManager.connect()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showConnected = true
        }
    }

    private func clearCache() {
        // 清除本地数据库
        let dbPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wechat_cache.db")
        try? FileManager.default.removeItem(at: dbPath)

        // 重新初始化
        _ = StorageManager.shared
        wsManager.conversations = []
        wsManager.messages = []
    }
}
