import Foundation

// 与后端数据库 accounts 表完全对齐
// id: TEXT, nickname: TEXT, wx_id: TEXT, phone: TEXT, avatar: TEXT, is_active: INTEGER, last_login: TEXT, server_url: TEXT
struct Account: Identifiable, Codable, Hashable {
    var id: String
    var nickname: String
    var wx_id: String?
    var phone: String?
    var avatar: String?
    var is_active: Int?
    var last_login: String?
    var server_url: String?

    // 兼容旧代码
    var name: String { nickname }
    var status: String? { (is_active == 1) ? "在线" : "离线" }

    static let mockData: [Account] = [
        .init(id: "1", nickname: "测试账号1", wx_id: nil, phone: nil, avatar: nil, is_active: 1, last_login: nil, server_url: nil),
        .init(id: "2", nickname: "测试账号2", wx_id: nil, phone: nil, avatar: nil, is_active: 0, last_login: nil, server_url: nil)
    ]
}
