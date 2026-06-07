import Foundation

struct Message: Identifiable, Codable {
    let id: String
    let text: String
    let isFromMe: Bool
    var timestamp: Date = Date()
    let targetId: String
}

struct Conversation: Identifiable {
    let id: String
    var name: String
    var avatar: String
    var lastMessage: String
    var lastMessageTime: Date
    var unreadCount: Int
    var isGroup: Bool
}

struct Task: Identifiable, Codable {
    let id: String
    var name: String
    var targetId: String
    var message: String
    var cron: String
}
