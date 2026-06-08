import Foundation

// 适配实际后端: /api/accounts 返回 [{"id": 1, "name": "管理员账号", "status": "在线"}]
struct Account: Identifiable, Codable, Hashable {
    var id: Int
    var name: String
    var status: String?

    // 兼容旧代码
    var nickname: String { name }

    static let mockData: [Account] = [
        .init(id: 1, name: "账号1", status: "在线"),
        .init(id: 2, name: "账号2", status: "离线"),
        .init(id: 3, name: "账号3", status: "同步中")
    ]
}
