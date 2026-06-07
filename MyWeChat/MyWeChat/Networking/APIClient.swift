import Foundation

final class APIClient {
    var baseURL: URL = URL(string: "https://your-domain.com")!

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Messages

    func sendMessage(_ req: SendMessageRequest) async throws -> ChatMessage {
        let payload: [String: Any] = [
            "sender": req.accountID,
            "receiver": req.chatID,
            "content": req.text,
            "msg_type": req.type.rawValue,
            "media_url": req.mediaURL ?? "",
            "account_id": req.accountID
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        struct Resp: Decodable { let status: String; let message_id: String }
        let resp: Resp = try await request("/api/send", method: "POST", body: body)
        return ChatMessage(
            id: resp.message_id,
            chatID: req.chatID,
            senderID: req.accountID,
            isFromMe: true,
            type: req.type,
            text: req.type == .text ? req.text : (req.text.isEmpty ? nil : req.text),
            mediaURLString: req.mediaURL,
            createdAt: .now
        )
    }

    func fetchConversations(accountID: String = "") async throws -> [Chat] {
        let path = accountID.isEmpty ? "/api/conversations" : "/api/conversations?account_id=\(accountID)"
        return try await request(path)
    }

    func fetchMessages(for chatID: String, limit: Int = 50) async throws -> [ChatMessage] {
        struct MsgResp: Decodable {
            let id: String
            let sender: String
            let receiver: String
            let content: String
            let msg_type: String
            let media_url: String?
            let timestamp: String
            let account_id: String?
        }
        let msgs: [MsgResp] = try await request("/api/conversations/\(chatID)/messages?limit=\(limit)")
        return msgs.map {
            ChatMessage(
                id: $0.id,
                chatID: $0.receiver,
                senderID: $0.sender,
                isFromMe: $0.sender == (UserDefaults.standard.string(forKey: "app.selectedAccount") ?? ""),
                type: ChatMessage.MessageType(rawValue: $0.msg_type) ?? .text,
                text: $0.content,
                mediaURLString: $0.media_url,
                createdAt: ISO8601DateFormatter().date(from: $0.timestamp) ?? .now
            )
        }
    }

    // MARK: - Upload

    func upload(data: Data, filename: String, mimeType: String, accountID: String = "", msgType: String = "file") async throws -> UploadResponse {
        guard let url = URL(string: "/api/upload", relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        let boundary = UUID().uuidString
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"account_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(accountID)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"msg_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(msgType)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (dataResp, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        struct UploadResp: Decodable { let status: String; let media_url: String }
        let resp = try JSONDecoder().decode(UploadResp.self, from: dataResp)
        return UploadResponse(url: resp.media_url)
    }

    // MARK: - Accounts

    func fetchAccounts() async throws -> [Account] {
        struct AccResp: Decodable {
            let id: String
            let nickname: String
            let is_active: Int
        }
        let accs: [AccResp] = try await request("/api/accounts")
        return accs.map {
            Account(id: $0.id, nickname: $0.nickname, status: $0.is_active == 1 ? .online : .offline)
        }
    }

    // MARK: - Scheduled Tasks

    func fetchScheduledTasks() async throws -> [ScheduleTask] {
        struct TaskResp: Decodable {
            let id: String
            let name: String
            let message_content: String
            let status: String
            let send_time: String
            let repeat_interval: Int
            let repeat_count: Int
        }
        let tasks: [TaskResp] = try await request("/api/scheduled_tasks")
        return tasks.map {
            ScheduleTask(
                id: $0.id,
                title: $0.name,
                summary: $0.message_content,
                enabled: $0.status != "paused",
                sendAt: ISO8601DateFormatter().date(from: $0.send_time) ?? .now,
                repeatInterval: TimeInterval($0.repeat_interval),
                repeatCount: $0.repeat_count
            )
        }
    }

    func createSchedule(_ draft: ScheduleTaskDraft) async throws -> ScheduleTask {
        let payload: [String: Any] = [
            "name": draft.title,
            "message_content": draft.content,
            "msg_type": draft.messageType.rawValue,
            "media_url": draft.mediaURL ?? "",
            "target_accounts": draft.targetAccountIDs,
            "targets": draft.targetChatIDs,
            "send_time": ISO8601DateFormatter().string(from: draft.sendAt),
            "repeat_interval": Int(draft.repeatInterval),
            "repeat_count": draft.repeatCount
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        struct Resp: Decodable { let status: String; let id: String; let next_run: String? }
        let resp: Resp = try await request("/api/scheduled_tasks", method: "POST", body: body)
        return ScheduleTask(
            id: resp.id,
            title: draft.title,
            summary: "\(draft.messageType.rawValue) / \(draft.repeatCount)次 / 间隔\(Int(draft.repeatInterval))秒",
            enabled: true,
            sendAt: draft.sendAt,
            repeatInterval: draft.repeatInterval,
            repeatCount: draft.repeatCount
        )
    }

    func toggleSchedule(id: String, enabled: Bool) async throws -> ScheduleTask {
        let path = enabled ? "/api/scheduled_tasks/\(id)/resume" : "/api/scheduled_tasks/\(id)/pause"
        struct Resp: Decodable { let status: String }
        let _: Resp = try await request(path, method: "PUT")
        return ScheduleTask(id: id, title: "任务", summary: "已更新", enabled: enabled, sendAt: .now, repeatInterval: 60, repeatCount: 1)
    }

    func deleteSchedule(id: String) async throws {
        struct Resp: Decodable { let status: String }
        let _: Resp = try await request("/api/scheduled_tasks/\(id)", method: "DELETE")
    }
}
