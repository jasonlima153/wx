import Foundation

struct Account: Identifiable, Codable, Hashable {
    // 这里的字段必须和 SQLite 数据库完全一样
    var id: String
    var nickname: String
    var wx_id: String?
    var phone: String?
    var avatar: String?
    var is_active: Int?
    var last_login: String?
    var server_url: String?

    // 兼容你旧 UI 代码的快捷属性
    var name: String { nickname }
    var status: String? { (is_active == 1) ? "在线" : "离线" }

    // 占位数据防崩
    static let mockData: [Account] = [
        .init(id: "1", nickname: "账号1", is_active: 1)
    ]
}
