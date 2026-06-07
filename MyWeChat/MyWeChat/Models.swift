import Foundation

// MARK: - 消息模型
struct Message: Identifiable, Codable {
    let id: Int?
    let sender: String
    let receiver: String
    let content: String
    let timestamp: String
    let msg_type: String?

    var isFromMe: Bool {
        return sender == "user"
    }

    var displayTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            return displayFormatter.string(from: date)
        }
        return timestamp
    }
}

// MARK: - 会话模型
struct Conversation: Identifiable, Codable {
    let id: Int?
    let name: String
    let avatar: String?
    let last_message: String?
    let last_time: String?
    let unread_count: Int?
}

// MARK: - WebSocket 消息
struct WSMessage: Codable {
    let type: String
    let sender: String?
    let receiver: String?
    let content: String?
    let timestamp: String?
    let msg_type: String?
}
