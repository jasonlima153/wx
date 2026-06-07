import Foundation

struct SendMessageRequest: Codable {
    var accountID: String
    var chatID: String
    var type: ChatMessage.MessageType
    var text: String
    var mediaURL: String?
}

struct SendMessageResponse: Codable {
    var id: String
    var chatID: String
    var senderID: String
    var isFromMe: Bool
    var type: ChatMessage.MessageType
    var text: String?
    var mediaURLString: String?
    var createdAt: Date

    var toMessage: ChatMessage {
        ChatMessage(id: id, chatID: chatID, senderID: senderID, isFromMe: isFromMe, type: type, text: text, mediaURLString: mediaURLString, createdAt: createdAt)
    }
}

struct UploadResponse: Codable { let url: String }

struct WSInboundEvent: Codable {
    enum Kind: String, Codable { case message, chatList, accountList, scheduleList, status }
    var kind: Kind
    var text: String?
    var message: ChatMessage?
    var chats: [Chat]?
    var accounts: [Account]?
    var schedules: [ScheduleTask]?
}
