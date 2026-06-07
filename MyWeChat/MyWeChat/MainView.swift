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

            ContactsView()
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
            setupTestData()
        }
    }

    private func setupTestData() {
        let convFetch = FetchDescriptor<Conversation>()
        let convCount = (try? modelContext.fetchCount(convFetch)) ?? 0
        if convCount > 0 { return }

        // 创建测试会话
        let conv1 = Conversation(id: "wxid_张小龙", name: "张小龙", avatar: "person.crop.circle", lastMessage: "新版本做得不错", timestamp: Date().addingTimeInterval(-120), unreadCount: 2)
        let conv2 = Conversation(id: "wxid_文件传输助手", name: "文件传输助手", avatar: "folder.fill", lastMessage: "[图片]", timestamp: Date().addingTimeInterval(-3600), unreadCount: 0)
        let conv3 = Conversation(id: "wxid_前端开发群", name: "前端开发群", avatar: "person.2.circle", lastMessage: "李四: 代码已提交", timestamp: Date().addingTimeInterval(-7200), unreadCount: 5)
        let conv4 = Conversation(id: "wxid_李四", name: "李四", avatar: "person.circle.fill", lastMessage: "明天见！", timestamp: Date().addingTimeInterval(-86400), unreadCount: 1)

        modelContext.insert(conv1)
        modelContext.insert(conv2)
        modelContext.insert(conv3)
        modelContext.insert(conv4)

        // 为张小龙创建聊天记录
        let msgs1: [(text: String, isFromMe: Bool, interval: TimeInterval)] = [
            ("在吗？", true, -600),
            ("在的，有什么事？", false, -540),
            ("新版本做得不错", false, -480),
            ("谢谢认可！后续还会继续优化", true, -420),
            ("期待新功能", false, -360),
            ("好的，正在开发中", true, -300),
            ("对了，明天的会议几点开始？", false, -240),
            ("下午2点，记得准时参加", true, -180),
            ("收到！", false, -120)
        ]
        for msg in msgs1 {
            let message = Message(
                conversationId: "wxid_张小龙",
                text: msg.text,
                isFromMe: msg.isFromMe,
                timestamp: Date().addingTimeInterval(msg.interval)
            )
            modelContext.insert(message)
        }

        // 为文件传输助手创建聊天记录
        let msgs2: [(text: String, isFromMe: Bool, interval: TimeInterval)] = [
            ("你好，欢迎使用", false, -3600),
            ("这是一个测试消息", true, -3500),
            ("收到文件了", false, -3400)
        ]
        for msg in msgs2 {
            let message = Message(
                conversationId: "wxid_文件传输助手",
                text: msg.text,
                isFromMe: msg.isFromMe,
                timestamp: Date().addingTimeInterval(msg.interval)
            )
            modelContext.insert(message)
        }

        // 为前端开发群创建聊天记录
        let msgs3: [(text: String, isFromMe: Bool, interval: TimeInterval)] = [
            ("大家好，今天下午发版", true, -7200),
            ("收到，我这边已经准备好了", false, -7000),
            ("代码已提交", false, -6800),
            ("好的，我来 review", true, -6600)
        ]
        for msg in msgs3 {
            let message = Message(
                conversationId: "wxid_前端开发群",
                text: msg.text,
                isFromMe: msg.isFromMe,
                timestamp: Date().addingTimeInterval(msg.interval)
            )
            modelContext.insert(message)
        }

        // 为李四创建聊天记录
        let msgs4: [(text: String, isFromMe: Bool, interval: TimeInterval)] = [
            ("明天一起吃饭吗？", false, -86400),
            ("好啊，去哪里？", true, -86300),
            ("老地方见", false, -86200),
            ("明天见！", false, -86100)
        ]
        for msg in msgs4 {
            let message = Message(
                conversationId: "wxid_李四",
                text: msg.text,
                isFromMe: msg.isFromMe,
                timestamp: Date().addingTimeInterval(msg.interval)
            )
            modelContext.insert(message)
        }
    }
}
