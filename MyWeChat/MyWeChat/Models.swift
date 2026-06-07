import Foundation
import SwiftData

// MARK: - 会话列表模型
@Model
class Conversation {
    @Attribute(.unique) var id: String
    var name: String
    var avatar: String
    var lastMessage: String
    var timestamp: Date
    var unreadCount: Int

    init(id: String = UUID().uuidString, name: String, avatar: String = "person.circle.fill", lastMessage: String = "", timestamp: Date = Date(), unreadCount: Int = 0) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.lastMessage = lastMessage
        self.timestamp = timestamp
        self.unreadCount = unreadCount
    }
}

// MARK: - 聊天消息模型
@Model
class Message {
    @Attribute(.unique) var id: String
    var conversationId: String
    var text: String
    var isFromMe: Bool
    var timestamp: Date
    var msgType: String

    init(id: String = UUID().uuidString, conversationId: String, text: String, isFromMe: Bool, timestamp: Date = Date(), msgType: String = "text") {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.isFromMe = isFromMe
        self.timestamp = timestamp
        self.msgType = msgType
    }
}
