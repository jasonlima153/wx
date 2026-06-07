import Foundation
import Combine

final class WebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private var pingTimer: Timer?
    @Published var isConnected = false

    func connect(urlString: String, token: String, onStatus: @escaping (Result<Bool, Error>) -> Void, onMessage: @escaping (WSInboundEvent) -> Void) {
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
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            let event = try decoder.decode(WSInboundEvent.self, from: data)
                            DispatchQueue.main.async { onMessage(event) }
                        } catch {
                            // Try to decode as raw server message format
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
                                }
                            }
                        }
                    }
                case .data:
                    break
                @unknown default:
                    break
                }
                self?.receiveNext(onMessage: onMessage)
            case .failure(let error):
                DispatchQueue.main.async { onStatus(.failure(error)) }
                self?.isConnected = false
            }
        }

        webSocketTask?.resume()
        isConnected = true
        DispatchQueue.main.async { onStatus(.success(true)) }

        // Start ping
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func receiveNext(onMessage: @escaping (WSInboundEvent) -> Void) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            let event = try decoder.decode(WSInboundEvent.self, from: data)
                            DispatchQueue.main.async { onMessage(event) }
                        } catch {
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
                                }
                            }
                        }
                    }
                default: break
                }
                self?.receiveNext(onMessage: onMessage)
            case .failure:
                self?.isConnected = false
            }
        }
    }

    func sendPing() {
        let ping: [String: Any] = ["type": "ping"]
        if let data = try? JSONSerialization.data(withJSONObject: ping) {
            webSocketTask?.send(.string(String(data: data, encoding: .utf8)!)) { _ in }
        }
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
}
