import Foundation

// MARK: - 消息类型
enum MessageType: String, Codable {
    case text = "text"
    case image = "image"
    case voice = "voice"
    case file = "file"
    case video = "video"
    case system = "system"
}

// MARK: - 消息模型
struct Message: Identifiable, Codable {
    let id: String
    var sender: String
    var receiver: String
    var content: String
    var type: MessageType
    var timestamp: Date
    var accountID: String
    var mediaURL: String?
    var fileName: String?
    var fileSize: Int64?
    var voiceDuration: Double?
    var isRead: Bool
    var isSent: Bool
    var isFromMe: Bool

    init(id: String = UUID().uuidString,
         sender: String,
         receiver: String,
         content: String,
         type: MessageType = .text,
         timestamp: Date = Date(),
         accountID: String = "",
         mediaURL: String? = nil,
         fileName: String? = nil,
         fileSize: Int64? = nil,
         voiceDuration: Double? = nil,
         isRead: Bool = true,
         isSent: Bool = true,
         isFromMe: Bool = false) {
        self.id = id
        self.sender = sender
        self.receiver = receiver
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.accountID = accountID
        self.mediaURL = mediaURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.voiceDuration = voiceDuration
        self.isRead = isRead
        self.isSent = isSent
        self.isFromMe = isFromMe
    }
}

// MARK: - 会话模型
struct Conversation: Identifiable, Codable {
    let id: String
    var name: String
    var avatar: String?
    var lastMessage: String?
    var lastMessageTime: Date?
    var unreadCount: Int
    var accountID: String
    var isGroup: Bool
    var isPinned: Bool

    init(id: String = UUID().uuidString,
         name: String,
         avatar: String? = nil,
         lastMessage: String? = nil,
         lastMessageTime: Date? = Date(),
         unreadCount: Int = 0,
         accountID: String = "",
         isGroup: Bool = false,
         isPinned: Bool = false) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
        self.accountID = accountID
        self.isGroup = isGroup
        self.isPinned = isPinned
    }
}

// MARK: - WebSocket 消息协议
struct WSMessage: Codable {
    var type: String
    var sender: String?
    var receiver: String?
    var content: String?
    var msg_type: String?
    var media_url: String?
    var file_name: String?
    var file_size: Int64?
    var voice_duration: Double?
    var timestamp: String?
    var account_id: String?
    var message_id: String?
}

// MARK: - 辅助扩展
extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }

    var displayTime: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(self) {
            return "昨天"
        } else {
            formatter.dateFormat = "MM/dd"
        }
        return formatter.string(from: self)
    }

    var chatTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}

extension Int64 {
    var fileSizeString: String {
        if self < 1024 {
            return "\(self) B"
        } else if self < 1024 * 1024 {
            return String(format: "%.1f KB", Double(self) / 1024.0)
        } else if self < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(self) / 1024.0 / 1024.0)
        } else {
            return String(format: "%.1f GB", Double(self) / 1024.0 / 1024.0 / 1024.0)
        }
    }
}
