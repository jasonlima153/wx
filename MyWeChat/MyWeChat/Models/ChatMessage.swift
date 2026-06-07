import Foundation

struct ChatMessage: Identifiable, Codable, Hashable {
    enum MessageType: String, Codable {
        case text
        case image
        case voice
        case file
    }

    var id: String
    var chatID: String
    var senderID: String
    var isFromMe: Bool
    var type: MessageType
    var text: String?
    var mediaURLString: String?
    var createdAt: Date

    var mediaURL: URL? { mediaURLString.flatMap(URL.init(string:)) }

    static let mockDataByChatId: [String: [ChatMessage]] = [
        "chat_1": [
            .init(id: UUID().uuidString, chatID: "chat_1", senderID: "u1", isFromMe: false, type: .text, text: "你好", mediaURLString: nil, createdAt: .now.addingTimeInterval(-3600)),
            .init(id: UUID().uuidString, chatID: "chat_1", senderID: "me", isFromMe: true, type: .image, text: "图片", mediaURLString: "https://picsum.photos/300", createdAt: .now.addingTimeInterval(-3200))
        ],
        "chat_2": [
            .init(id: UUID().uuidString, chatID: "chat_2", senderID: "u2", isFromMe: false, type: .voice, text: "语音消息", mediaURLString: nil, createdAt: .now.addingTimeInterval(-1800))
        ],
        "chat_3": [
            .init(id: UUID().uuidString, chatID: "chat_3", senderID: "u3", isFromMe: false, type: .file, text: "合同.pdf", mediaURLString: nil, createdAt: .now.addingTimeInterval(-1200))
        ]
    ]
}
