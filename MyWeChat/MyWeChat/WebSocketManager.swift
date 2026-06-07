import Foundation
import Combine

class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()

    @Published var isConnected = false
    @Published var messages: [Message] = []
    @Published var conversations: [Conversation] = []

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
        }
        let payload: [String: Any] = ["type": "message", "text": text, "targetId": targetId]
        sendJSON(payload)
    }

    func disconnect() {
        webSocketTask?.cancel()
        isConnected = false
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
            }
        default: break
        }
    }

    // MARK: - 云端同步指令

    /// 同步"撤回消息"指令到云端
    func sendRecallCommand(messageId: String, targetId: String) {
        let payload: [String: Any] = [
            "type": "recall_message",
            "messageId": messageId,
            "targetId": targetId
        ]
        sendJSON(payload)
        print("📤 已向服务器发送撤回指令: \(messageId)")
    }

    /// 同步"图片消息"指令到云端
    func sendImageMessageSync(localPath: String, to targetId: String) {
        let payload: [String: Any] = [
            "type": "image_message",
            "imageUrl": localPath,
            "targetId": targetId
        ]
        sendJSON(payload)
        print("📤 已向服务器发送图片同步指令")
    }

    /// 同步"群发定时任务"到云端
    func syncMassTaskToServer(task: MassSendTask) {
        let payload: [String: Any] = [
            "type": "add_mass_task",
            "task": [
                "id": task.id,
                "taskName": task.taskName,
                "targetIds": task.targetIds,
                "messageContent": task.messageContent,
                "triggerTime": task.triggerTime.timeIntervalSince1970,
                "repeatMode": task.repeatMode
            ]
        ]
        sendJSON(payload)
        print("📤 已向服务器下发定时群发任务: \(task.taskName)")
    }
}
