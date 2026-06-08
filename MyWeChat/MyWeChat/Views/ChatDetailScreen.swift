import SwiftUI

struct ChatDetailScreen: View {
    @EnvironmentObject var session: AppSession
    let chatTitle: String       // 房间 ID (好友wxid或群chatroom ID)
    let chatNickname: String    // 映射后的好看名字
    
    @State private var inputText: String = ""
    
    // 动态绑定到 session，数据一变，页面立刻自动重绘！
    var currentMessages: [Message] {
        return session.messages[chatTitle] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. 聊天气泡滚动区
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(currentMessages) { msg in
                            HStack(alignment: .top) {
                                if msg.isFromMe {
                                    Spacer()
                                    // 我发的绿色气泡
                                    Text(msg.content ?? "")
                                        .font(.system(size: 16))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color(red: 0.57, green: 0.89, blue: 0.45)) // 微信经典绿
                                        .foregroundColor(.black)
                                        .cornerRadius(6)
                                    
                                    Image(systemName: "person.crop.square.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                } else {
                                    // 对方发的灰色方形头像
                                    Image(systemName: "person.crop.square.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray)
                                        .cornerRadius(4)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        // 如果是群聊，额外显示一下群成员名字前缀
                                        if chatTitle.hasSuffix("@chatroom") {
                                            Text(msg.sender)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        // 对方的白色气泡
                                        Text(msg.content ?? "")
                                            .font(.system(size: 16))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color(.systemBackground))
                                            .foregroundColor(.primary)
                                            .cornerRadius(6)
                                            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 12)
                            .id(msg.id)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground)) // 微信淡灰色底色
                // ⭐️ 核心：新消息一到，自动平滑滚到底部
                .onChange(of: currentMessages.count) { _ in
                    if let last = currentMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onAppear {
                    session.selectedChatID = chatTitle
                    if let last = currentMessages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onDisappear {
                    session.selectedChatID = nil
                }
            }
            
            // 2. 底部输入框
            HStack(spacing: 12) {
                TextField("输入消息...", text: $inputText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(6)
                
                Button(action: sendMessage) {
                    Text("发送")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(inputText.isEmpty ? Color.gray : Color.green)
                        .cornerRadius(6)
                }
                .disabled(inputText.isEmpty)
            }
            .padding(12)
            .background(Color(.systemBackground))
        }
        .navigationTitle(chatNickname)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func sendMessage() {
        let text = inputText
        inputText = "" // 瞬间清空输入框
        
        let newMsg = Message(
            id: UUID().uuidString,
            sender: "2",          // 我的号
            receiver: chatTitle,  // 好友号或群号
            content: text,
            msg_type: "text",
            timestamp: "\(Int(Date().timeIntervalSince1970))",
            account_id: "2"
        )
        
        // 瞬间在手机本地画出气泡
        session.handleIncomingMessage(newMsg)
        
        // 丢给中转服务器
        guard let url = URL(string: "http://120.48.88.19:8000/api/send") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(newMsg)
        URLSession.shared.dataTask(with: req).resume()
    }
}
