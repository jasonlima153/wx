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

        // 先断开旧连接
        silentDisconnect()

        guard let url = URL(string: urlString) else {
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
                self?.isConnected = true
                self?.reconnectAttempts = 0
                self?.reconnectStatus = nil
                self?.handleMessage(message, onMessage: onMessage)
                self?.receiveNext(onMessage: onMessage)
            case .failure(let error):
                self?.isConnected = false
                self?.scheduleReconnect()
            }
        }

        webSocketTask?.resume()
        isConnected = true
        DispatchQueue.main.async { onStatus(.success(true)) }

        // 启动心跳
        startPingTimer()
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message, onMessage: @escaping (WSInboundEvent) -> Void) {
        switch message {
        case .string(let text):
            if let data = text.data(using: .utf8) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let event = try decoder.decode(WSInboundEvent.self, from: data)
                    DispatchQueue.main.async { onMessage(event) }
                } catch {
                    // 尝试解析后端原始消息格式
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let kind = json["type"] as? String ?? ""
                        if kind == "new_message" {
                            let msg = ChatMessage(
                                id: json["message_id"] as? String ?? UUID().uuidString,
                                chatID: json["receiver"] as? String ?? "",
                                senderID: json["sender"] as? String ?? "",
                                isFromMe: false,
                                type: ChatMessage.MessageType(rawValue: json["msg_type"] as? String ?? "text") ?? .text,
                                text: json["content"] as? String,
                                mediaURLString: json["media_url"] as? String,
                                createdAt: .now
                            )
                            let event = WSInboundEvent(kind: .message, text: nil, message: msg, chats: nil, accounts: nil, schedules: nil)
                            DispatchQueue.main.async { onMessage(event) }
                        } else if kind == "pong" {
                            // 心跳回复，忽略
                        }
                    }
                }
            }
        case .data:
            break
        @unknown default:
            break
        }
    }

    private func receiveNext(onMessage: @escaping (WSInboundEvent) -> Void) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.isConnected = true
                self?.reconnectAttempts = 0
                self?.reconnectStatus = nil
                self?.handleMessage(message, onMessage: onMessage)
                self?.receiveNext(onMessage: onMessage)
            case .failure:
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

        guard let url = URL(string: currentURLString) else { return }

        var request = URLRequest(url: url)
        request.setValue(currentToken, forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)

        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.isConnected = true
                self?.reconnectAttempts = 0
                self?.reconnectStatus = nil
                DispatchQueue.main.async { onSt(.success(true)) }
                self?.handleMessage(message, onMessage: onMsg)
                self?.receiveNext(onMessage: onMsg)
            case .failure:
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
              let str = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(str)) { error in
            if let error = error {
                print("WebSocket 发送失败: \(error)")
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
