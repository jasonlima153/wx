import Foundation
import Combine

final class WebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var currentURLString: String = ""
    private var currentToken: String = ""
    private var onMessageHandler: ((WSInboundEvent) -> Void)?
    private var onStatusHandler: ((Result<Bool, Error>) -> Void)?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 10

    @Published var isConnected = false
    @Published var reconnectStatus: String?

    func connect(urlString: String, token: String, onStatus: @escaping (Result<Bool, Error>) -> Void, onMessage: @escaping (WSInboundEvent) -> Void) {
        // 保存回调以便重连时复用
        currentURLString = urlString
        currentToken = token
        onMessageHandler = onMessage
        onStatusHandler = onStatus
        reconnectAttempts = 0

        print("🔗 [WS] 正在尝试连接: \(urlString)")

        // 先断开旧连接
        silentDisconnect()

        guard let url = URL(string: urlString) else {
            print("❌ [WS] 无效 URL: \(urlString)")
            onStatus(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)

        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                print("✅ [WS] 收到消息")
                self?.isConnected = true
                self?.reconnectAttempts = 0
                self?.reconnectStatus = nil
                self?.handleMessage(message, onMessage: onMessage)
                self?.receiveNext(onMessage: onMessage)
            case .failure(let error):
                print("❌ [WS] 接收失败或断开: \(error.localizedDescription)")
                print("❌ [WS] 详细错误: \(error)")
                self?.isConnected = false
                self?.scheduleReconnect()
            }
        }

        webSocketTask?.resume()
        isConnected = true
        print("✅ [WS] 连接已建立")
        DispatchQueue.main.async { onStatus(.success(true)) }

        // 启动心跳
        startPingTimer()
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message, onMessage: @escaping (WSInboundEvent) -> Void) {
        switch message {
        case .string(let text):
            print("📥 [WS] 收到文本: \(text.prefix(200))")
            guard let data = text.data(using: .utf8) else { return }

            // 先尝试解析为 JSON 对象
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // 不是 JSON，当作纯文本消息处理
                print("📥 [WS] 收到纯文本消息")
                let msg = ChatMessage(
                    id: UUID().uuidString,
                    sender: "server",
                    receiver: "",
                    content: text,
                    msg_type: "text",
                    media_url: nil,
                    timestamp: ISO8601DateFormatter().string(from: .now)
                )
                let event = WSInboundEvent(kind: .message, text: nil, message: msg, chats: nil, accounts: nil, schedules: nil)
                DispatchQueue.main.async { onMessage(event) }
                return
            }

            let kind = json["type"] as? String ?? ""
            if kind == "new_message" || kind == "message" {
                let msg = ChatMessage(
                    id: json["message_id"] as? String ?? UUID().uuidString,
                    sender: json["sender"] as? String ?? "",
                    receiver: json["receiver"] as? String ?? "",
                    content: json["content"] as? String,
                    msg_type: json["msg_type"] as? String ?? "text",
                    media_url: json["media_url"] as? String,
                    timestamp: json["timestamp"] as? String ?? ISO8601DateFormatter().string(from: .now)
                )
                let event = WSInboundEvent(kind: .message, text: nil, message: msg, chats: nil, accounts: nil, schedules: nil)
                DispatchQueue.main.async { onMessage(event) }
            } else if kind == "pong" {
                print("💓 [WS] 收到心跳 pong")
            } else {
                print("📥 [WS] 收到其他类型消息: \(kind)")
            }

        case .data:
            print("📥 [WS] 收到二进制数据")
        @unknown default:
            break
        }
    }

    private func receiveNext(onMessage: @escaping (WSInboundEvent) -> Void) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                print("✅ [WS] 收到消息")
                self?.isConnected = true
                self?.reconnectAttempts = 0
                self?.reconnectStatus = nil
                self?.handleMessage(message, onMessage: onMessage)
                self?.receiveNext(onMessage: onMessage)
            case .failure(let error):
                print("❌ [WS] 接收失败或断开: \(error.localizedDescription)")
                print("❌ [WS] 详细错误: \(error)")
                self?.isConnected = false
                self?.scheduleReconnect()
            }
        }
    }

    // MARK: - 断线重连

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            reconnectStatus = "重连失败，请检查网络后重试"
            onStatusHandler?(.failure(NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "重连失败"])))
            return
        }

        let delay = min(pow(2.0, Double(reconnectAttempts)) * 1.0, 30.0) // 指数退避：1s, 2s, 4s, 8s...最大30s
        reconnectAttempts += 1
        reconnectStatus = "网络连接已断开，\(Int(delay))秒后尝试重连... (\(reconnectAttempts)/\(maxReconnectAttempts))"

        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.attemptReconnect()
        }
    }

    private func attemptReconnect() {
        guard let onMsg = onMessageHandler, let onSt = onStatusHandler else { return }
        silentDisconnect()

        print("🔄 [WS] 尝试重连: \(currentURLString) (第 \(reconnectAttempts) 次)")

        guard let url = URL(string: currentURLString) else { return }

        var request = URLRequest(url: url)
        request.setValue(currentToken, forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)

        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                print("✅ [WS] 重连成功，收到消息")
                self?.isConnected = true
                self?.reconnectAttempts = 0
                self?.reconnectStatus = nil
                DispatchQueue.main.async { onSt(.success(true)) }
                self?.handleMessage(message, onMessage: onMsg)
                self?.receiveNext(onMessage: onMsg)
            case .failure(let error):
                print("❌ [WS] 重连失败: \(error.localizedDescription)")
                self?.isConnected = false
                self?.scheduleReconnect()
            }
        }

        webSocketTask?.resume()
        startPingTimer()
    }

    // MARK: - 心跳

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    func sendPing() {
        let ping: [String: Any] = ["type": "ping"]
        if let data = try? JSONSerialization.data(withJSONObject: ping),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { _ in }
        }
    }

    // MARK: - 发送消息

    func send(_ dict: [String: Any]) {
        guard isConnected, let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            print("❌ [WS] 发送失败：未连接或序列化失败")
            return
        }
        print("📤 [WS] 发送: \(str)")
        webSocketTask?.send(.string(str)) { error in
            if let error = error {
                print("❌ [WS] 发送失败: \(error)")
            } else {
                print("✅ [WS] 发送成功")
            }
        }
    }

    // MARK: - 断开

    private func silentDisconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    func disconnect() {
        silentDisconnect()
        isConnected = false
        reconnectStatus = nil
        reconnectAttempts = maxReconnectAttempts // 阻止自动重连
    }
}
