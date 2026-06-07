import Foundation

// MARK: - 定时群发任务模型
struct ScheduledMessage: Identifiable, Codable {
    let id: String
    var name: String
    var messageContent: String
    var msgType: String
    var mediaURL: String?
    var targetAccounts: [String]
    var targets: [String]
    var sendTime: String
    var repeatInterval: Int
    var repeatCount: Int
    var sentCount: Int
    var status: TaskStatus
    var createdAt: String
    var nextRun: String?

    enum TaskStatus: String, Codable {
        case pending = "pending"
        case running = "running"
        case paused = "paused"
        case completed = "completed"
    }

    init(id: String = UUID().uuidString,
         name: String = "",
         messageContent: String,
         msgType: String = "text",
         mediaURL: String? = nil,
         targetAccounts: [String] = [],
         targets: [String] = [],
         sendTime: String,
         repeatInterval: Int = 0,
         repeatCount: Int = 1,
         sentCount: Int = 0,
         status: TaskStatus = .pending,
         createdAt: String = Date().iso8601,
         nextRun: String? = nil) {
        self.id = id
        self.name = name
        self.messageContent = messageContent
        self.msgType = msgType
        self.mediaURL = mediaURL
        self.targetAccounts = targetAccounts
        self.targets = targets
        self.sendTime = sendTime
        self.repeatInterval = repeatInterval
        self.repeatCount = repeatCount
        self.sentCount = sentCount
        self.status = status
        self.createdAt = createdAt
        self.nextRun = nextRun
    }

    // 从服务器 JSON 解码
    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? UUID().uuidString
        self.name = dict["name"] as? String ?? ""
        self.messageContent = dict["message_content"] as? String ?? ""
        self.msgType = dict["msg_type"] as? String ?? "text"
        self.mediaURL = dict["media_url"] as? String
        self.targetAccounts = Self.parseJSONArray(dict["target_accounts"] as? String)
        self.targets = Self.parseJSONArray(dict["targets"] as? String)
        self.sendTime = dict["send_time"] as? String ?? ""
        self.repeatInterval = dict["repeat_interval"] as? Int ?? 0
        self.repeatCount = dict["repeat_count"] as? Int ?? 1
        self.sentCount = dict["sent_count"] as? Int ?? 0
        self.status = TaskStatus(rawValue: dict["status"] as? String ?? "pending") ?? .pending
        self.createdAt = dict["created_at"] as? String ?? ""
        self.nextRun = dict["next_run"] as? String
    }

    private static func parseJSONArray(_ string: String?) -> [String] {
        guard let string = string, let data = string.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    // 显示属性
    var statusText: String {
        switch status {
        case .pending: return "等待中"
        case .running: return "执行中"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        }
    }

    var statusColor: String {
        switch status {
        case .pending: return "blue"
        case .running: return "green"
        case .paused: return "orange"
        case .completed: return "gray"
        }
    }

    var progressText: String {
        "\(sentCount)/\(repeatCount)"
    }

    var nextRunDisplay: String {
        guard let next = nextRun else { return "-" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: next) {
            let display = DateFormatter()
            display.dateFormat = "MM/dd HH:mm"
            return display.string(from: date)
        }
        return next
    }

    var repeatIntervalDisplay: String {
        if repeatInterval == 0 { return "不重复" }
        if repeatInterval < 60 { return "\(repeatInterval)秒" }
        if repeatInterval < 3600 { return "\(repeatInterval / 60)分钟" }
        if repeatInterval < 86400 { return "\(repeatInterval / 3600)小时" }
        return "\(repeatInterval / 86400)天"
    }
}
