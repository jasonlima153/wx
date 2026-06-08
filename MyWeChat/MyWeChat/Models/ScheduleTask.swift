import Foundation

// 与后端数据库 scheduled_tasks 表完全对齐
// id: TEXT, name: TEXT, message_content: TEXT, msg_type: TEXT, media_url: TEXT, target_accounts: TEXT, targets: TEXT, send_time: TEXT, repeat_interval: INTEGER, repeat_count: INTEGER, sent_count: INTEGER, status: TEXT, created_at: TEXT, next_run: TEXT
struct ScheduleTask: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var message_content: String
    var msg_type: String
    var media_url: String?
    var target_accounts: String
    var targets: String
    var send_time: String
    var repeat_interval: Int
    var repeat_count: Int
    var sent_count: Int
    var status: String
    var created_at: String
    var next_run: String?

    // 兼容旧代码的计算属性
    var title: String { name }
    var summary: String { message_content }
    var enabled: Bool { status != "paused" && status != "completed" }
    var sendAt: Date {
        if let d = ISO8601DateFormatter().date(from: send_time) { return d }
        return .now
    }
    var repeatInterval: TimeInterval { TimeInterval(repeat_interval) }

    static let mockData: [ScheduleTask] = [
        .init(id: "sch_1", name: "晨间通知", message_content: "每天 9:00 发送文字", msg_type: "text", media_url: nil, target_accounts: "[]", targets: "[]", send_time: ISO8601DateFormatter().string(from: .now.addingTimeInterval(3600)), repeat_interval: 86400, repeat_count: 30, sent_count: 0, status: "pending", created_at: ISO8601DateFormatter().string(from: .now), next_run: nil),
        .init(id: "sch_2", name: "图片群发", message_content: "每 2 小时发送一次图片", msg_type: "image", media_url: nil, target_accounts: "[]", targets: "[]", send_time: ISO8601DateFormatter().string(from: .now.addingTimeInterval(7200)), repeat_interval: 7200, repeat_count: 10, sent_count: 0, status: "paused", created_at: ISO8601DateFormatter().string(from: .now), next_run: nil)
    ]
}

struct ScheduleTaskDraft: Codable {
    var title: String
    var content: String
    var messageType: ChatMessage.MessageType
    var sendAt: Date
    var repeatInterval: TimeInterval
    var repeatCount: Int
    var targetAccountIDs: [String]
    var targetChatIDs: [String]
    var mediaURL: String?
}
