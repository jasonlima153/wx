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

// MARK: - 聊天消息模型 (升级版)
@Model
class Message {
    @Attribute(.unique) var id: String
    var conversationId: String
    var text: String
    var isFromMe: Bool
    var timestamp: Date
    var msgType: String
    var localImagePath: String?
    var isRecalled: Bool

    init(id: String = UUID().uuidString, conversationId: String, text: String, isFromMe: Bool, timestamp: Date = Date(), msgType: String = "text", localImagePath: String? = nil, isRecalled: Bool = false) {
        self.id = id
        self.conversationId = conversationId
        self.text = text
        self.isFromMe = isFromMe
        self.timestamp = timestamp
        self.msgType = msgType
        self.localImagePath = localImagePath
        self.isRecalled = isRecalled
    }
}

// MARK: - 定时群发任务模型
@Model
class MassSendTask {
    @Attribute(.unique) var id: String
    var taskName: String
    var targetNames: [String]
    var targetIds: [String]
    var messageContent: String
    var triggerTime: Date
    var repeatMode: String
    var isActive: Bool

    init(id: String = UUID().uuidString, taskName: String, targetNames: [String], targetIds: [String], messageContent: String, triggerTime: Date, repeatMode: String = "单次", isActive: Bool = true) {
        self.id = id
        self.taskName = taskName
        self.targetNames = targetNames
        self.targetIds = targetIds
        self.messageContent = messageContent
        self.triggerTime = triggerTime
        self.repeatMode = repeatMode
        self.isActive = isActive
    }
}
