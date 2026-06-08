import Foundation

// 与后端数据库 conversations 表完全对齐
// id: TEXT, name: TEXT, avatar: TEXT, last_message: TEXT, last_time: TEXT, unread_count: INTEGER, account_id: TEXT, is_group: INTEGER, is_pinned: INTEGER
struct Chat: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var avatar: String?
    var last_message: String?
    var last_time: String?
    var unread_count: Int
    var account_id: String?
    var is_group: Int?
    var is_pinned: Int?

    // 兼容旧代码的显示字段
    var title: String { name }
    var subtitle: String { last_message ?? "" }

    static let mockData: [Chat] = [
        .init(id: "chat_1", name: "产品群", avatar: nil, last_message: "最新消息预览", last_time: nil, unread_count: 2, account_id: nil, is_group: 1, is_pinned: 0),
        .init(id: "chat_2", name: "张三", avatar: nil, last_message: "昨天 21:08", last_time: nil, unread_count: 0, account_id: nil, is_group: 0, is_pinned: 0),
        .init(id: "chat_3", name: "李四", avatar: nil, last_message: "图片", last_time: nil, unread_count: 5, account_id: nil, is_group: 0, is_pinned: 0)
    ]
}
