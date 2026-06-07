import Foundation
import Combine

class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()

    @Published var isConnected = false
    @Published var messages: [Message] = []
    @Published var conversations: [Conversation] = []
    @Published var serverURL: String = ""

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTimer: Timer?
    private let defaults = UserDefaults.standard

    init() {
        self.serverURL = defaults.string(forKey: "serverURL") ?? "ws://localhost:8000/ws"
    }

    func setServerURL(_ url: String) {
        serverURL = url
        defaults.set(url, forKey: "serverURL")
    }

    func connect() {
        guard let url = URL(string: serverURL) else {
            print("❌ 无效的 URL: \(serverURL)")
            return
        }

        disconnect()

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true
        receiveMessage()
        print("✅ WebSocket 连接中... \(serverURL)")

        // 发送 ping 保持连接
        startPingTimer()
    }

    func disconnect() {
        reconnectTimer?.invalidate()
        webSocketTask?.cancel()
        webSocketTask = nil
        isConnected = false
        print("❌ WebSocket 已断开")
    }

    func sendMessage(content: String, to receiver: String) {
        let msg = WSMessage(
            type: "message",
            sender: "user",
            receiver: receiver,
            content: content,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            msg_type: "text"
        )

        do {
            let data = try JSONEncoder().encode(msg)
            if let jsonString = String(data: data, encoding: .utf8) {
                webSocketTask?.send(.string(jsonString)) { error in
                    if let error = error {
                        print("❌ 发送失败: \(error)")
                    } else {
                        print("✅ 消息已发送")
                    }
                }
            }
        } catch {
            print("❌ 编码失败: \(error)")
        }

        // 本地添加消息
        let localMsg = Message(
            id: nil,
            sender: "user",
            receiver: receiver,
            content: content,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            msg_type: "text"
        )
        DispatchQueue.main.async {
            self.messages.append(localMsg)
        }
    }

    func fetchConversations() {
        guard let url = URL(string: serverURL.replacingOccurrences(of: "/ws", with: "/api/conversations")) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data {
                do {
                    let convs = try JSONDecoder().decode([Conversation].self, from: data)
                    DispatchQueue.main.async {
                        self.conversations = convs
                    }
                } catch {
                    print("❌ 解析会话失败: \(error)")
                }
            }
        }.resume()
    }

    func fetchMessages(for conversation: String) {
        guard let url = URL(string: serverURL.replacingOccurrences(of: "/ws", with: "/api/messages/\(conversation)")) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data {
                do {
                    let msgs = try JSONDecoder().decode([Message].self, from: data)
                    DispatchQueue.main.async {
                        self.messages = msgs
                    }
                } catch {
                    print("❌ 解析消息失败: \(error)")
                }
            }
        }.resume()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage()

            case .failure(let error):
                print("❌ WebSocket 接收错误: \(error)")
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            let msg = try JSONDecoder().decode(WSMessage.self, from: data)
            if msg.type == "new_message" {
                let newMsg = Message(
                    id: nil,
                    sender: msg.sender ?? "",
                    receiver: msg.receiver ?? "",
                    content: msg.content ?? "",
                    timestamp: msg.timestamp ?? ISO8601DateFormatter().string(from: Date()),
                    msg_type: msg.msg_type ?? "text"
                )
                DispatchQueue.main.async {
                    self.messages.append(newMsg)
                    self.fetchConversations()
                }
            }
        } catch {
            print("❌ 解析消息失败: \(error)")
        }
    }

    private func startPingTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            let ping = WSMessage(type: "ping", sender: nil, receiver: nil, content: nil, timestamp: nil, msg_type: nil)
            if let data = try? JSONEncoder().encode(ping),
               let json = String(data: data, encoding: .utf8) {
                self.webSocketTask?.send(.string(json)) { _ in }
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            print("🔄 尝试重新连接...")
            self?.connect()
        }
    }
}
