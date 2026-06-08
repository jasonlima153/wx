import Foundation

// 与后端数据库 accounts 表完全对齐
// id: TEXT, nickname: TEXT, wx_id: TEXT, phone: TEXT, avatar: TEXT, is_active: INTEGER, last_login: TEXT, server_url: TEXT
struct Account: Identifiable, Codable, Hashable {
    enum Status: String, Codable {
        case online = "在线"
        case offline = "离线"
        case sync = "同步中"
    }

    var id: String
    var nickname: String
    var wx_id: String
    var phone: String?
    var avatar: String?
    var is_active: Int
    var last_login: String?
    var server_url: String?

    // 计算属性：兼容旧代码的 status 显示
    var status: Status {
        is_active == 1 ? .online : .offline
    }

    static let mockData: [Account] = [
        .init(id: "acc_1", nickname: "账号1", wx_id: "wx_1", phone: nil, avatar: nil, is_active: 1, last_login: nil, server_url: nil),
        .init(id: "acc_2", nickname: "账号2", wx_id: "wx_2", phone: nil, avatar: nil, is_active: 0, last_login: nil, server_url: nil),
        .init(id: "acc_3", nickname: "账号3", wx_id: "wx_3", phone: nil, avatar: nil, is_active: 0, last_login: nil, server_url: nil)
    ]
}
