import Foundation

// MARK: - 微信账号模型
struct WeChatAccount: Identifiable, Codable {
    let id: String
    var nickname: String
    var avatar: String?
    var wxID: String
    var phone: String?
    var isActive: Bool
    var lastLoginDate: Date?
    var serverURL: String?

    init(id: String = UUID().uuidString,
         nickname: String,
         avatar: String? = nil,
         wxID: String,
         phone: String? = nil,
         isActive: Bool = false,
         lastLoginDate: Date? = nil,
         serverURL: String? = nil) {
        self.id = id
        self.nickname = nickname
        self.avatar = avatar
        self.wxID = wxID
        self.phone = phone
        self.isActive = isActive
        self.lastLoginDate = lastLoginDate
        self.serverURL = serverURL
    }
}
