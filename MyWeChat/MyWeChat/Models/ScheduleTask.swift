import Foundation

struct ScheduleTask: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var summary: String
    var enabled: Bool
    var sendAt: Date
    var repeatInterval: TimeInterval
    var repeatCount: Int

    static let mockData: [ScheduleTask] = [
        .init(id: "sch_1", title: "晨间通知", summary: "每天 9:00 发送文字", enabled: true, sendAt: .now.addingTimeInterval(3600), repeatInterval: 86400, repeatCount: 30),
        .init(id: "sch_2", title: "图片群发", summary: "每 2 小时发送一次图片", enabled: false, sendAt: .now.addingTimeInterval(7200), repeatInterval: 7200, repeatCount: 10)
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
