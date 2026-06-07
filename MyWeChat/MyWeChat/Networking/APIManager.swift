import Foundation

// MARK: - API 请求管理
class APIManager {
    static let shared = APIManager()

    private var baseURL: String {
        let wsURL = WebSocketManager.shared.serverURL
        return wsURL.replacingOccurrences(of: "/ws", with: "")
    }

    private var accountID: String {
        WebSocketManager.shared.currentAccountID
    }

    // MARK: - 账号管理

    func fetchAccounts(completion: @escaping ([WeChatAccount]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/accounts") else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let accounts = try? JSONDecoder().decode([ServerAccount].self, from: data) {
                let result = accounts.map { $0.toAccount() }
                DispatchQueue.main.async {
                    for acc in result {
                        StorageManager.shared.saveAccount(acc)
                    }
                }
                completion(result)
            } else {
                completion(nil)
            }
        }.resume()
    }

    func createAccount(nickname: String, wxID: String, phone: String? = nil,
                       completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/accounts") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "nickname": nickname,
            "wx_id": wxID,
            "phone": phone ?? ""
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            URLSession.shared.uploadTask(with: request, from: jsonData) { data, _, _ in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["status"] as? String == "ok" {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
        }
    }

    func activateAccount(_ accountID: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/accounts/\(accountID)/activate") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["status"] as? String == "ok" {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }

    // MARK: - 会话

    func fetchConversations(completion: @escaping ([Conversation]?) -> Void) {
        var urlString = "\(baseURL)/api/conversations"
        if !accountID.isEmpty {
            urlString += "?account_id=\(accountID)"
        }
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let convs = try? JSONDecoder().decode([ServerConversation].self, from: data) {
                let result = convs.map { $0.toConversation() }
                DispatchQueue.main.async {
                    for conv in result {
                        StorageManager.shared.saveConversation(conv)
                    }
                }
                completion(result)
            } else {
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - 服务器数据解码辅助
struct ServerAccount: Codable {
    var id: String?
    var nickname: String?
    var wx_id: String?
    var phone: String?
    var avatar: String?
    var is_active: Int?
    var last_login: String?
    var server_url: String?

    func toAccount() -> WeChatAccount {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return WeChatAccount(
            id: id ?? UUID().uuidString,
            nickname: nickname ?? "",
            avatar: avatar,
            wxID: wx_id ?? "",
            phone: phone,
            isActive: is_active == 1,
            lastLoginDate: last_login.flatMap { formatter.date(from: $0) },
            serverURL: server_url
        )
    }
}

struct ServerConversation: Codable {
    var id: String?
    var name: String?
    var avatar: String?
    var last_message: String?
    var last_time: String?
    var unread_count: Int?
    var account_id: String?
    var is_group: Int?
    var is_pinned: Int?

    func toConversation() -> Conversation {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return Conversation(
            id: id ?? UUID().uuidString,
            name: name ?? "",
            avatar: avatar,
            lastMessage: last_message,
            lastMessageTime: last_time.flatMap { formatter.date(from: $0) },
            unreadCount: unread_count ?? 0,
            accountID: account_id ?? "",
            isGroup: is_group == 1,
            isPinned: is_pinned == 1
        )
    }
}
