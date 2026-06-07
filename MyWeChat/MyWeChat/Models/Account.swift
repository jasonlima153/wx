import Foundation

struct Account: Identifiable, Codable, Hashable {
    enum Status: String, Codable {
        case online = "在线"
        case offline = "离线"
        case sync = "同步中"
    }

    var id: String
    var nickname: String
    var status: Status

    static let mockData: [Account] = [
        .init(id: "acc_1", nickname: "账号1", status: .online),
        .init(id: "acc_2", nickname: "账号2", status: .sync),
        .init(id: "acc_3", nickname: "账号3", status: .offline)
    ]
}
