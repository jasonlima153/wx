import Foundation

struct Chat: Identifiable, Codable, Hashable {
    // 这里的字段必须和 SQLite 的 conversations 表完全一样
    var id: String
    var name: String
    var avatar: String?
    var last_message: String?
    var last_time: String?
    var unread_count: Int?  // 改成可选 Int? 防止后端传 null 崩溃
    var account_id: String?
    var is_group: Int?
    var is_pinned: Int?

    // 兼容旧 UI 的计算属性
    var title: String { name }
    var subtitle: String { last_message ?? "暂无消息" }

    // 占位数据
    static let mockData: [Chat] = [
        .init(id: "1", name: "产品群", unread_count: 2)
    ]
}
