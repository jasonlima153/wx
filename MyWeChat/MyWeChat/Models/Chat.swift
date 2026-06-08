import Foundation

// 适配实际后端: /api/conversations 返回 [{"id": 1, "target_name": "产品群", "last_message": "...", "unread_count": 2}]
struct Chat: Identifiable, Codable, Hashable {
    var id: Int
    var target_name: String
    var last_message: String?
    var unread_count: Int

    // 兼容旧代码
    var title: String { target_name }
    var subtitle: String { last_message ?? "" }

    static let mockData: [Chat] = [
        .init(id: 1, target_name: "产品群", last_message: "最新消息预览", unread_count: 2),
        .init(id: 2, target_name: "张三", last_message: "昨天 21:08", unread_count: 0),
        .init(id: 3, target_name: "李四", last_message: "图片", unread_count: 5)
    ]
}
