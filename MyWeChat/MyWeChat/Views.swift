import SwiftUI

// MARK: - 入口 Tab 视图
struct MainTabView: View {
    var body: some View {
        TabView {
            ConversationListView()
                .tabItem { Label("微信", systemImage: "message.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gear") }
        }
    }
}

// MARK: - 会话列表视图
struct ConversationListView: View {
    @StateObject private var wsManager = WebSocketManager.shared

    var body: some View {
        NavigationView {
            List(wsManager.conversations) { conv in
                NavigationLink(destination: ChatDetailView(targetId: conv.id, name: conv.name)) {
                    HStack {
                        Image(systemName: conv.avatar)
                            .resizable().frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(conv.name).font(.headline)
                            Text(conv.lastMessage).font(.subheadline).foregroundColor(.gray).lineLimit(1)
                        }
                        Spacer()
                        if conv.unreadCount > 0 {
                            Text("\(conv.unreadCount)")
                                .font(.caption2).padding(5)
                                .background(Color.red).foregroundColor(.white)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .navigationTitle("消息")
            .onAppear { wsManager.connect() }
        }
    }
}

// MARK: - 聊天详情视图
struct ChatDetailView: View {
    let targetId: String
    let name: String
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var inputText = ""

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(wsManager.messages.filter { $0.targetId == targetId }) { msg in
                        HStack {
                            if msg.isFromMe { Spacer() }
                            Text(msg.text)
                                .padding(10)
                                .background(msg.isFromMe ? Color.green : Color.white)
                                .foregroundColor(msg.isFromMe ? .white : .black)
                                .cornerRadius(10)
                            if !msg.isFromMe { Spacer() }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemGray6))

            HStack {
                TextField("输入消息...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("发送") {
                    guard !inputText.isEmpty else { return }
                    wsManager.sendMessage(inputText, to: targetId)
                    inputText = ""
                }
                .disabled(!wsManager.isConnected)
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(wsManager.isConnected ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { wsManager.clearUnread(for: targetId) }
    }
}

// MARK: - 设置与定时任务视图
struct SettingsView: View {
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var inputAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? "ws://192.168.1.100:8080"
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showAddTask = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("服务器配置")) {
                    TextField("地址 (如 ws://192.168.x.x:8080)", text: $inputAddress)
                        .autocapitalization(.none)
                    Button("保存并重连") {
                        wsManager.setServerAddress(inputAddress)
                        wsManager.connect()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            alertMessage = wsManager.isConnected ? "✅ 连接成功！" : "❌ 连接失败，请检查 IP 和后端。"
                            showAlert = true
                        }
                    }
                }

                Section(header: Text("连接状态")) {
                    HStack {
                        Text("当前状态")
                        Spacer()
                        Text(wsManager.isConnected ? "已连接" : "未连接")
                            .foregroundColor(wsManager.isConnected ? .green : .red)
                    }
                }

                Section(header: HStack { Text("定时任务列表"); Spacer(); Button("添加"){ showAddTask = true } }) {
                    ForEach(wsManager.taskList) { task in
                        VStack(alignment: .leading) {
                            Text(task.name).font(.headline)
                            Text("发送给: \(wsManager.getName(for: task.targetId)) | 内容: \(task.message)").font(.caption)
                            Text("时间: \(task.cron)").font(.caption2).foregroundColor(.blue)
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            wsManager.deleteTask(wsManager.taskList[index].id)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView()
            }
        }
    }
}

// MARK: - 添加任务弹窗
struct AddTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var wsManager = WebSocketManager.shared

    @State private var taskName = ""
    @State private var targetId = "assistant"
    @State private var message = ""
    @State private var selectedCron = "0 9 * * *"

    let targets = ["assistant": "测试助手", "zhangxiaolong": "张小龙"]
    let cronOptions = ["每天上午 09:00": "0 9 * * *", "每天下午 18:00": "0 18 * * *", "每分钟(测试用)": "* * * * *"]

    var body: some View {
        NavigationView {
            Form {
                TextField("任务名称", text: $taskName)
                Picker("发送给", selection: $targetId) {
                    ForEach(Array(targets.keys), id: \.self) { key in Text(targets[key]!).tag(key) }
                }
                TextField("消息内容", text: $message)
                Picker("执行时间", selection: $selectedCron) {
                    ForEach(Array(cronOptions.keys), id: \.self) { key in Text(key).tag(cronOptions[key]!) }
                }

                Button("保存任务") {
                    let task = Task(id: UUID().uuidString, name: taskName.isEmpty ? "新任务" : taskName, targetId: targetId, message: message, cron: selectedCron)
                    wsManager.addTask(task)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(message.isEmpty)
            }
            .navigationTitle("新建定时任务")
        }
    }
}
