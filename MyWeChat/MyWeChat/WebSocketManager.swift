import Foundation
import Combine

class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()

    @Published var isConnected = false
    @Published var messages: [Message] = []
    @Published var conversations: [Conversation] = []
    @Published var taskList: [Task] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var currentServerURL = UserDefaults.standard.string(forKey: "serverAddress") ?? "ws://localhost:8080"

    func setServerAddress(_ address: String) {
        currentServerURL = address
        UserDefaults.standard.set(address, forKey: "serverAddress")
    }

    func connect() {
        guard let url = URL(string: currentServerURL) else {
            DispatchQueue.main.async { self.isConnected = false }
            return
        }
        webSocketTask?.cancel()
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        receiveMessage()

        webSocketTask?.sendPing { error in
            DispatchQueue.main.async {
                self.isConnected = (error == nil)
                if let error = error {
                    print("❌ 连接失败: \(error.localizedDescription)")
                } else {
                    print("✅ WebSocket 已连接")
                }
            }
        }
    }

    func sendMessage(_ text: String, to targetId: String) {
        let msg = Message(id: UUID().uuidString, text: text, isFromMe: true, targetId: targetId)
        DispatchQueue.main.async {
            self.messages.append(msg)
            self.updateConversation(for: msg)
        }
        sendJSON(["type": "message", "text": text, "targetId": targetId] as [String: Any])
    }

    func addTask(_ task: Task) {
        let payload: [String: Any] = [
            "type": "add_task",
            "task": ["id": task.id, "name": task.name, "targetId": task.targetId, "message": task.message, "cron": task.cron]
        ]
        sendJSON(payload)
    }

    func deleteTask(_ taskId: String) {
        sendJSON(["type": "delete_task", "taskId": taskId] as [String: Any])
    }

    func clearUnread(for targetId: String) {
        if let idx = conversations.firstIndex(where: { $0.id == targetId }) {
            conversations[idx].unreadCount = 0
        }
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error { print("❌ 发送JSON失败: \(error)") }
        }
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let msg):
                    if case .string(let text) = msg {
                        self?.handleReceivedText(text)
                    }
                case .failure:
                    self?.isConnected = false
                }
                self?.receiveMessage()
            }
        }
    }

    private func handleReceivedText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "new_message":
            if let msgDict = json["message"] as? [String: Any],
               let id = msgDict["id"] as? String,
               let text = msgDict["text"] as? String,
               let targetId = msgDict["targetId"] as? String {
                let newMsg = Message(id: id, text: text, isFromMe: false, targetId: targetId)
                self.messages.append(newMsg)
                self.updateConversation(for: newMsg)
            }
        case "task_list":
            if let tasksData = json["tasks"] as? [[String: Any]] {
                self.taskList = tasksData.compactMap { dict in
                    guard let id = dict["id"] as? String,
                          let name = dict["name"] as? String,
                          let targetId = dict["targetId"] as? String,
                          let message = dict["message"] as? String,
                          let cron = dict["cron"] as? String else { return nil }
                    return Task(id: id, name: name, targetId: targetId, message: message, cron: cron)
                }
            }
        default: break
        }
    }

    private func updateConversation(for message: Message) {
        let targetId = message.targetId
        let name = getName(for: targetId)
        if let idx = conversations.firstIndex(where: { $0.id == targetId }) {
            var conv = conversations[idx]
            conv.lastMessage = message.text
            conv.lastMessageTime = message.timestamp
            if !message.isFromMe { conv.unreadCount += 1 }
            conversations[idx] = conv
        } else {
            let newConv = Conversation(id: targetId, name: name, avatar: "person.circle.fill", lastMessage: message.text, lastMessageTime: message.timestamp, unreadCount: message.isFromMe ? 0 : 1, isGroup: false)
            conversations.append(newConv)
        }
        conversations.sort { $0.lastMessageTime > $1.lastMessageTime }
    }

    func getName(for id: String) -> String {
        let map = ["assistant":"测试助手", "file_transfer":"文件传输助手", "zhangxiaolong":"张小龙", "developer":"程序员小哥哥"]
        return map[id] ?? id
    }

    func disconnect() {
        webSocketTask?.cancel()
        isConnected = false
    }
}
