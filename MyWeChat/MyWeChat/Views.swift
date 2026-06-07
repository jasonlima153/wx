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

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("设置")
                }
        }
        .accentColor(.green)
    }
}

// MARK: - 会话列表
struct ConversationListView: View {
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var showingNewChat = false

    var body: some View {
        NavigationView {
            List {
                ForEach(wsManager.conversations) { conv in
                    NavigationLink(destination: ChatDetailView(conversationName: conv.name)) {
                        HStack(spacing: 12) {
                            Image(systemName: conv.avatar ?? "person.circle.fill")
                                .resizable()
                                .frame(width: 45, height: 45)
                                .foregroundColor(.blue)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(conv.name)
                                    .font(.system(size: 17, weight: .regular))
                                Text(conv.last_message ?? "")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatTime(conv.last_time))
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)

                                if let unread = conv.unread_count, unread > 0 {
                                    Text("\(unread)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("微信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewChat = true }) {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatView()
            }
            .onAppear {
                wsManager.fetchConversations()
            }
        }
    }

    private func formatTime(_ time: String?) -> String {
        guard let time = time else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: time) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            return displayFormatter.string(from: date)
        }
        return time
    }
}

// MARK: - 聊天详情
struct ChatDetailView: View {
    let conversationName: String
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var inputText: String = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(wsManager.messages.filter {
                            $0.receiver == conversationName || $0.sender == conversationName
                        }) { msg in
                            MessageBubbleView(message: msg)
                                .id(msg.id ?? 0)
                        }
                    }
                    .padding()
                }
                .onChange(of: wsManager.messages.count) { _ in
                    if let last = wsManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id ?? 0, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 输入栏
            HStack(spacing: 12) {
                TextField("输入消息...", text: $inputText)
                    .padding(10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(20)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(inputText.isEmpty ? Color.gray : Color.green)
                        .clipShape(Circle())
                }
                .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle(conversationName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            wsManager.fetchMessages(for: conversationName)
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        wsManager.sendMessage(content: inputText, to: conversationName)
        inputText = ""
    }
}

// MARK: - 消息气泡
struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top) {
            if message.isFromMe { Spacer() }

            if !message.isFromMe {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 35, height: 35)
                    .foregroundColor(.gray)
            }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.system(size: 16))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isFromMe ? Color.green : Color.white)
                    .foregroundColor(message.isFromMe ? .white : .black)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)

                Text(message.displayTime)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if message.isFromMe {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 35, height: 35)
                    .foregroundColor(.blue)
            }

            if !message.isFromMe { Spacer() }
        }
    }
}

// MARK: - 新建聊天
struct NewChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String = ""

    let contacts = ["张三", "李四", "王五", "赵六", "文件传输助手", "工作群"]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("输入联系人")) {
                    TextField("联系人名称", text: $name)
                }

                Section(header: Text("快速选择")) {
                    ForEach(contacts, id: \.self) { contact in
                        Button(action: {
                            name = contact
                        }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.blue)
                                Text(contact)
                                Spacer()
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("新建聊天")
            .navigationBarItems(
                leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("开始") {
                    if !name.isEmpty {
                        presentationMode.wrappedValue.dismiss()
                        // 导航到聊天页面
                    }
                }
                .disabled(name.isEmpty)
            )
        }
    }
}

// MARK: - 设置
struct SettingsView: View {
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var serverURL: String = ""
    @State private var showConnected = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("服务器配置")) {
                    TextField("WebSocket 地址", text: $serverURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button(action: {
                        wsManager.setServerURL(serverURL)
                        wsManager.connect()
                        showConnected = true
                    }) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                            Text("连接服务器")
                        }
                    }

                    HStack {
                        Text("连接状态")
                        Spacer()
                        Circle()
                            .fill(wsManager.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        Text(wsManager.isConnected ? "已连接" : "未连接")
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
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
                    title: Text("连接"),
                    message: Text(wsManager.isConnected ? "连接成功" : "连接失败"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
}
