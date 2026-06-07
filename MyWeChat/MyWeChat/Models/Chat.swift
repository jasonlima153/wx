import Foundation

struct Chat: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var unreadCount: Int?

    static let mockData: [Chat] = [
        .init(id: "chat_1", title: "产品群", subtitle: "最新消息预览", unreadCount: 2),
        .init(id: "chat_2", title: "张三", subtitle: "昨天 21:08", unreadCount: 0),
        .init(id: "chat_3", title: "李四", subtitle: "图片", unreadCount: 5)
    ]
}
