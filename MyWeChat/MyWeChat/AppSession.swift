import SwiftUI
import Foundation

// 1. 联系人与群聊结构体
struct Contact: Identifiable, Codable, Hashable {
    var id: String { wx_id }
    let wx_id: String
    let nickname: String
    let remark: String
    let avatar: String?
    
    // 判断是否是群聊 (微信群ID通常以 @chatroom 结尾)
    var isGroup: Bool {
        return wx_id.hasSuffix("@chatroom")
    }
}

// 2. 统一消息模型
struct Message: Identifiable, Codable, Equatable {
    let id: String
    let sender: String      // 发送者的 wxid（如果是群聊，代表具体发言人）
    let receiver: String    // 接收者的 wxid（如果是群聊，代表群ID）
    let content: String?    // ⚠️ 和服务器对接的字段名
    let msg_type: String
    let timestamp: String
    let account_id: String
    
    // 核心逻辑：如果是自己（当前控制的账号"2"）发出去的，判定为 ByMe
    var isFromMe: Bool {
        return sender == "2"
    }
}

// 3. 会话列表模型
struct ChatConversation: Identifiable, Codable {
    var id: String { title }
    var title: String          // 对方的 wxid 或群 ID
    var nickname: String?      // 映射出来的备注或群名
    var last_message: String?
    var last_time: String?
    var unread_count: Int
}

// 4. 定时任务模型
struct ScheduledTask: Identifiable, Codable {
    let id: String
    var name: String?
    let message_content: String
    let msg_type: String
    let target_accounts: String // 挂载的微信号，这里是 "2"
    let targets: String         // 接收目标，多个用逗号隔开 (如 wxid_1,xxxx@chatroom)
    let send_time: String       // 时间戳或格式化时间
    var status: String          // "pending", "sent", "failed"
}

// 5. WebSocket 事件枚举
enum WSInboundKind: String, Codable {
    case message = "new_message"
    case chatList = "chat_list"
    case status = "status"
}

struct WSInboundEvent: Codable {
    let type: String
    let sender: String?
    let receiver: String?
    let content: String?
    let msg_type: String?
    let timestamp: String?
    let id: String?
}

@MainActor
class AppSession: ObservableObject {
    @Published var chats: [ChatConversation] = [] {
        didSet { saveData(key: "saved_chats", data: chats) }
    }
    @Published var messages: [String: [Message]] = [:] {
        didSet { saveData(key: "saved_messages", data: messages) }
    }
    @Published var contacts: [Contact] = [] {
        didSet { saveData(key: "saved_contacts", data: contacts) }
    }
    @Published var scheduledTasks: [ScheduledTask] = []
    @Published var selectedAccountID: String = "2"
    @Published var isConnected: Bool = false
    @Published var lastError: String = ""
    
    var selectedChatID: String? = nil
    private var webSocketTask: URLSessionWebSocketTask?
    
    init() {
        // 开机瞬间，从手机硬盘读取历史记录
        if let data = UserDefaults.standard.data(forKey: "saved_chats"),
           let decoded = try? JSONDecoder().decode([ChatConversation].self, from: data) {
            self.chats = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "saved_messages"),
           let decoded = try? JSONDecoder().decode([String: [Message]].self, from: data) {
            self.messages = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "saved_contacts"),
           let decoded = try? JSONDecoder().decode([Contact].self, from: data) {
            self.contacts = decoded
        }
        connectWebSocket()
    }
    
    private func saveData<T: Encodable>(key: String, data: T) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    // ⭐️ 核心：连接 WebSocket 实现秒回，免手动刷新
    func connectWebSocket() {
        guard let url = URL(string: "ws://120.48.88.19:8000/ws/chat/iphone") else { return }
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        self.isConnected = true
        listenWebSocket()
    }
    
    private func listenWebSocket() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let event = try? JSONDecoder().decode(WSInboundEvent.self, from: data) {
                        DispatchQueue.main.async {
                            self?.handleIncomingEvent(event)
                        }
                    }
                default: break
                }
                self?.listenWebSocket() // 循环监听
            case .failure:
                DispatchQueue.main.async { self?.isConnected = false }
                // 3秒后自动重连
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { [weak self] in
                    self?.connectWebSocket()
                }
            }
        }
    }
    
    // 处理从服务器秒推过来的消息
    private func handleIncomingEvent(_ event: WSInboundEvent) {
        if event.type == "new_message" {
            let msg = Message(
                id: event.id ?? UUID().uuidString,
                sender: event.sender ?? "",
                receiver: event.receiver ?? "",
                content: event.content,
                msg_type: event.msg_type ?? "text",
                timestamp: event.timestamp ?? "\(Int(Date().timeIntervalSince1970))",
                account_id: "2"
            )
            
            let isGroupMessage = event.receiver?.hasSuffix("@chatroom") ?? false
            let roomId = msg.isFromMe ? msg.receiver : (isGroupMessage ? msg.receiver : msg.sender)
            
            if messages[roomId] == nil { messages[roomId] = [] }
            if !(messages[roomId]?.contains(where: { $0.id == msg.id }) ?? false) {
                messages[roomId]?.append(msg)
            }
            
            if let idx = chats.firstIndex(where: { $0.title == roomId }) {
                var updated = chats[idx]
                updated.last_message = msg.content
                updated.last_time = msg.timestamp
                if selectedChatID != roomId { updated.unread_count += 1 }
                chats.remove(at: idx)
                chats.insert(updated, at: 0)
            } else {
                let mappedName = contacts.first(where: { $0.wx_id == roomId })?.remark ?? "新会话"
                let newChat = ChatConversation(title: roomId, nickname: roomId.hasSuffix("@chatroom") ? "微信群聊" : mappedName, last_message: msg.content, last_time: msg.timestamp, unread_count: 1)
                chats.insert(newChat, at: 0)
            }
        }
    }
    
    func handleIncomingMessage(_ msg: Message) {
        let roomId = msg.isFromMe ? msg.receiver : msg.sender
        if messages[roomId] == nil { messages[roomId] = [] }
        if !(messages[roomId]?.contains(where: { $0.id == msg.id }) ?? false) {
            messages[roomId]?.append(msg)
        }
        
        if let idx = chats.firstIndex(where: { $0.title == roomId }) {
            var updated = chats[idx]
            updated.last_message = msg.content
            updated.last_time = msg.timestamp
            if selectedChatID != roomId { updated.unread_count += 1 }
            chats.remove(at: idx)
            chats.insert(updated, at: 0)
        } else {
            let mappedName = contacts.first(where: { $0.wx_id == roomId })?.remark ?? "新会话"
            let newChat = ChatConversation(title: roomId, nickname: roomId.hasSuffix("@chatroom") ? "微信群聊" : mappedName, last_message: msg.content, last_time: msg.timestamp, unread_count: 1)
            chats.insert(newChat, at: 0)
        }
    }
    
    // 拉取 PC 微信同步过来的真实通讯录
    func loadRealContacts() async {
        guard let url = URL(string: "http://120.48.88.19:8000/api/contacts?account_id=\(selectedAccountID)") else { return }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let decoded = try? JSONDecoder().decode([Contact].self, from: data) {
            self.contacts = decoded
        }
    }
    
    // 拉取定时任务列表
    func loadScheduledTasks() async {
        guard let url = URL(string: "http://120.48.88.19:8000/api/scheduled_tasks?account_id=\(selectedAccountID)") else { return }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let decoded = try? JSONDecoder().decode([ScheduledTask].self, from: data) {
            self.scheduledTasks = decoded
        }
    }
    
    // 持久化（占位）
    func persistAll() {}
    
    // ===== 兼容旧代码的属性 =====
    
    var settings: AppSettings {
        get {
            // 从 UserDefaults 读取
            if let data = UserDefaults.standard.data(forKey: "app.settings"),
               let s = try? JSONDecoder().decode(AppSettings.self, from: data) {
                return s
            }
            return AppSettings()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "app.settings")
            }
        }
    }
    
    var accounts: [Account] {
        get {
            if let data = UserDefaults.standard.data(forKey: "app.accounts"),
               let a = try? JSONDecoder().decode([Account].self, from: data) {
                return a
            }
            return Account.mockData
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "app.accounts")
            }
        }
    }
    
    let api = APIClient()
    let ws = WebSocketManager()
    let storage = StorageManager()
    
    func connect() {
        connectWebSocket()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
}
