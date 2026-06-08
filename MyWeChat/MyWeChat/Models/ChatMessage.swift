import Foundation

// 适配实际后端消息格式
struct ChatMessage: Identifiable, Codable, Hashable {
    enum MessageType: String, Codable {
        case text
        case image
        case voice
        case file
    }

    var id: String
    var sender: String
    var receiver: String
    var content: String?
    var msg_type: String
    var media_url: String?
    var timestamp: String?

    // 兼容旧代码
    var chatID: String { receiver }
    var senderID: String { sender }
    var isFromMe: Bool { sender == (UserDefaults.standard.string(forKey: "app.selectedAccount") ?? "") }
    var type: MessageType { MessageType(rawValue: msg_type) ?? .text }
    var text: String? { content }
    var mediaURLString: String? { media_url }
    var mediaURL: URL? { media_url.flatMap(URL.init(string:)) }
    var createdAt: Date {
        if let ts = timestamp, let d = ISO8601DateFormatter().date(from: ts) { return d }
        return .now
    }

    static let mockDataByChatId: [String: [ChatMessage]] = [
        "chat_1": [
            .init(id: UUID().uuidString, sender: "u1", receiver: "chat_1", content: "你好", msg_type: "text", media_url: nil, timestamp: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-3600))),
            .init(id: UUID().uuidString, sender: "me", receiver: "chat_1", content: "图片", msg_type: "image", media_url: "https://picsum.photos/300", timestamp: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-3200)))
        ],
        "chat_2": [
            .init(id: UUID().uuidString, sender: "u2", receiver: "chat_2", content: "语音消息", msg_type: "voice", media_url: nil, timestamp: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-1800)))
        ],
        "chat_3": [
            .init(id: UUID().uuidString, sender: "u3", receiver: "chat_3", content: "合同.pdf", msg_type: "file", media_url: nil, timestamp: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-1200)))
        ]
    ]
}
