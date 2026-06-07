import Foundation
import Combine

// MARK: - WebSocket 实时通信管理
class WebSocketManager: ObservableObject {
    static let shared = WebSocketManager()

    @Published var isConnected = false
    @Published var messages: [Message] = []
    @Published var conversations: [Conversation] = []
    @Published var serverURL: String = ""
    @Published var currentAccountID: String = ""
    @Published var connectionError: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectTimer: Timer?
    private var pingTimer: Timer?
    private let defaults = UserDefaults.standard
    private let storage = StorageManager.shared

    init() {
        self.serverURL = defaults.string(forKey: "serverURL") ?? "ws://localhost:8000/ws"
        self.currentAccountID = defaults.string(forKey: "currentAccountID") ?? ""

        // 加载本地缓存
        loadCachedData()
    }

    // MARK: - 配置

    func setServerURL(_ url: String) {
        serverURL = url
        defaults.set(url, forKey: "serverURL")
    }

    func setCurrentAccount(_ accountID: String) {
        currentAccountID = accountID
        defaults.set(accountID, forKey: "currentAccountID")
        loadCachedData()
    }

    // MARK: - 连接管理

    func connect() {
        guard let url = URL(string: serverURL) else {
            connectionError = "无效的 URL"
            return
        }

        disconnect()

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true
        connectionError = nil
        receiveMessage()
        startPingTimer()
        print("✅ WebSocket 连接中... \(serverURL)")
    }

    func disconnect() {
        stopPingTimer()
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - 发送消息

    func sendMessage(content: String, to receiver: String, type: MessageType = .text,
                     mediaURL: String? = nil, fileName: String? = nil,
                     fileSize: Int64? = nil, voiceDuration: Double? = nil) {
        let msg = WSMessage(
            type: "message",
            sender: currentAccountID,
            receiver: receiver,
            content: content,
            msg_type: type.rawValue,
            media_url: mediaURL,
            file_name: fileName,
            file_size: fileSize,
            voice_duration: voiceDuration,
            timestamp: Date().iso8601,
            account_id: currentAccountID,
            message_id: UUID().uuidString
        )

        if let data = try? JSONEncoder().encode(msg),
           let json = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(json)) { [weak self] error in
                if let error = error {
                    print("❌ 发送失败: \(error)")
                    DispatchQueue.main.async {
                        self?.connectionError = "发送失败"
                    }
                }
            }
        }

        // 本地保存
        let localMsg = Message(
            sender: currentAccountID,
            receiver: receiver,
            content: content,
            type: type,
            accountID: currentAccountID,
            mediaURL: mediaURL,
            fileName: fileName,
            fileSize: fileSize,
            voiceDuration: voiceDuration,
            isFromMe: true
        )
        DispatchQueue.main.async {
            self.messages.append(localMsg)
            self.storage.saveMessage(localMsg)
        }
    }

    func sendReadReceipt(messageID: String) {
        let msg = WSMessage(type: "read_receipt", message_id: messageID)
        if let data = try? JSONEncoder().encode(msg),
           let json = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(json)) { _ in }
        }
        storage.markMessageAsRead(messageID)
    }

    // MARK: - 接收消息

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleIncomingMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage()

            case .failure(let error):
                print("❌ WebSocket 错误: \(error)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.connectionError = "连接断开"
                }
                self.scheduleReconnect()
            }
        }
    }

    private func handleIncomingMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        guard let wsMsg = try? JSONDecoder().decode(WSMessage.self, from: data) else { return }

        if wsMsg.type == "new_message" {
            var msg = Message(
                id: wsMsg.message_id ?? UUID().uuidString,
                sender: wsMsg.sender ?? "",
                receiver: wsMsg.receiver ?? "",
                content: wsMsg.content ?? "",
                type: MessageType(rawValue: wsMsg.msg_type ?? "text") ?? .text,
                accountID: wsMsg.account_id ?? currentAccountID,
                mediaURL: wsMsg.media_url,
                fileName: wsMsg.file_name,
                fileSize: wsMsg.file_size,
                voiceDuration: wsMsg.voice_duration,
                isFromMe: (wsMsg.sender ?? "") == currentAccountID
            )

            // 解析时间
            if let ts = wsMsg.timestamp {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: ts) {
                    msg.timestamp = date
                }
            }

            DispatchQueue.main.async {
                self.messages.append(msg)
                self.storage.saveMessage(msg)
                self.fetchConversations()
            }
        }
    }

    // MARK: - 数据加载

    func fetchConversations() {
        let baseURL = serverURL.replacingOccurrences(of: "/ws", with: "")
        guard let url = URL(string: "\(baseURL)/api/conversations?account_id=\(currentAccountID)") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data else { return }
            // 尝试从服务器获取，失败则用本地缓存
            if let convs = try? JSONDecoder().decode([Conversation].self, from: data) {
                DispatchQueue.main.async {
                    self?.conversations = convs
                    for conv in convs {
                        self?.storage.saveConversation(conv)
                    }
                }
            }
        }.resume()
    }

    func fetchMessages(for conversationName: String) {
        let baseURL = serverURL.replacingOccurrences(of: "/ws", with: "")
        guard let url = URL(string: "\(baseURL)/api/conversations/\(conversationName)/messages?account_id=\(currentAccountID)") else { return }

        // 先显示本地缓存
        let cached = storage.fetchMessages(accountID: currentAccountID, conversationName: conversationName)
        DispatchQueue.main.async {
            self.messages = cached
        }

        // 再从服务器拉取
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let serverMsgs = try? JSONDecoder().decode([ServerMessage].self, from: data) else { return }

            let msgs = serverMsgs.compactMap { $0.toMessage(accountID: self?.currentAccountID ?? "") }
            DispatchQueue.main.async {
                self?.messages = msgs
                self?.storage.saveMessages(msgs)
            }
        }.resume()
    }

    func fetchUnreadMessages() {
        let cached = storage.fetchUnreadMessages(accountID: currentAccountID)
        if !cached.isEmpty {
            DispatchQueue.main.async {
                self.messages = cached
            }
        }

        let baseURL = serverURL.replacingOccurrences(of: "/ws", with: "")
        guard let url = URL(string: "\(baseURL)/api/messages/unread?account_id=\(currentAccountID)") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let serverMsgs = try? JSONDecoder().decode([ServerMessage].self, from: data) else { return }
            let msgs = serverMsgs.compactMap { $0.toMessage(accountID: self?.currentAccountID ?? "") }
            DispatchQueue.main.async {
                self?.storage.saveMessages(msgs)
            }
        }.resume()
    }

    private func loadCachedData() {
        if !currentAccountID.isEmpty {
            conversations = storage.fetchConversations(accountID: currentAccountID)
        }
    }

    // MARK: - 定时器

    private func startPingTimer() {
        stopPingTimer()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self, self.isConnected else { return }
            let ping = WSMessage(type: "ping")
            if let data = try? JSONEncoder().encode(ping),
               let json = String(data: data, encoding: .utf8) {
                self.webSocketTask?.send(.string(json)) { _ in }
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            print("🔄 尝试重新连接...")
            self?.connect()
        }
    }
}

// MARK: - 服务器消息解码辅助
struct ServerMessage: Codable {
    var id: String?
    var sender: String?
    var receiver: String?
    var content: String?
    var msg_type: String?
    var media_url: String?
    var file_name: String?
    var file_size: Int64?
    var voice_duration: Double?
    var timestamp: String?
    var account_id: String?
    var is_read: Int?

    func toMessage(accountID: String) -> Message? {
        guard let id = id, let sender = sender, let receiver = receiver else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = timestamp.flatMap { formatter.date(from: $0) } ?? Date()

        return Message(
            id: id,
            sender: sender,
            receiver: receiver,
            content: content ?? "",
            type: MessageType(rawValue: msg_type ?? "text") ?? .text,
            timestamp: date,
            accountID: account_id ?? accountID,
            mediaURL: media_url,
            fileName: file_name,
            fileSize: file_size,
            voiceDuration: voice_duration,
            isRead: is_read == 1,
            isFromMe: sender == accountID
        )
    }
}
