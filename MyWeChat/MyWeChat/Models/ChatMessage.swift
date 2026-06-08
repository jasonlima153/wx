import Foundation

// 与后端数据库 messages 表完全对齐
// id: TEXT, sender: TEXT, receiver: TEXT, content: TEXT, msg_type: TEXT, media_url: TEXT, file_name: TEXT, file_size: INTEGER, voice_duration: REAL, timestamp: TEXT, account_id: TEXT, is_read: INTEGER
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
    var file_name: String?
    var file_size: Int?
    var voice_duration: Double?
    var timestamp: String?
    var account_id: String?
    var is_read: Int?

    // 兼容旧代码的计算属性
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
            .init(id: UUID().uuidString, sender: "u1", receiver: "chat_1", content: "你好", msg_type: "text", media_url: nil, file_name: nil, file_size: nil, voice_duration: nil, timestamp: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-3600)), account_id: nil, is_read: 1),
            .init(id: UUID().uuidString, sender: "me", receiver: "chat_1", content: "图片", msg_type: "image", media_url: "https://picsum.photos/300", file_name: nil, file_size: nil, voice_duration: nil, timestamp: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-3200)), account_id: nil, is_read: 1)
        ],
        "chat_2": [
            .init(id: UUID().uuidString, sender: "u2", receiver: "chat_2", content: "语音消息", msg_type: "voice", media_url: nil, file_name: nil, file_size: nil, voice_duration: nil, timestamp: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-1800)), account_id: nil, is_read: 1)
        ],
        "chat_3": [
            .init(id: UUID().uuidString, sender: "u3", receiver: "chat_3", content: "合同.pdf", msg_type: "file", media_url: nil, file_name: nil, file_size: nil, voice_duration: nil, timestamp: ISO8601DateFormatter().string(from: .now.addingTimeInterval(-1200)), account_id: nil, is_read: 1)
        ]
    ]
}
