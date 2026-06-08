import Foundation

final class APIClient {
    var baseURL: URL = URL(string: "https://your-domain.com")!

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            print("❌ [API] 无效 URL: \(path)")
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        print("📤 [API] \(method) \(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<binary>"
            print("❌ [API] HTTP 错误: \(String(describing: (response as? HTTPURLResponse)?.statusCode)) 响应: \(bodyStr)")
            throw URLError(.badServerResponse)
        }
        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            print("✅ [API] 解析成功: \(T.self)")
            return result
        } catch let DecodingError.keyNotFound(key, context) {
            let field = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            let msg = "找不到字段 '\(key.stringValue)' (在 \(field) 中)"
            print("❌ [API] \(msg)")
            throw NSError(domain: "JSON解析", code: -1016, userInfo: [NSLocalizedDescriptionKey: msg])
        } catch let DecodingError.typeMismatch(type, context) {
            let field = context.codingPath.last?.stringValue ?? "未知"
            let msg = "字段 '\(field)' 类型不对 (应该改成 \(type))"
            print("❌ [API] \(msg)")
            throw NSError(domain: "JSON解析", code: -1016, userInfo: [NSLocalizedDescriptionKey: msg])
        } catch {
            print("❌ [API] 其他解析错误: \(error)")
            throw NSError(domain: "JSON解析", code: -1016, userInfo: [NSLocalizedDescriptionKey: "数据格式不匹配"])
        }
    }

    // MARK: - Messages (REST fallback when WS disconnected)

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
            sender: req.accountID,
            receiver: req.chatID,
            content: req.type == .text ? req.text : (req.text.isEmpty ? nil : req.text),
            msg_type: req.type.rawValue,
            media_url: req.mediaURL,
            timestamp: ISO8601DateFormatter().string(from: .now)
        )
    }

    // MARK: - Conversations

    func fetchConversations(accountID: String = "") async throws -> [Chat] {
        let path = accountID.isEmpty ? "/api/conversations" : "/api/conversations?account_id=\(accountID)"
        return try await request(path)
    }

    func fetchMessages(for chatID: String, limit: Int = 50) async throws -> [ChatMessage] {
        return try await request("/api/conversations/\(chatID)/messages?limit=\(limit)")
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
        return try await request("/api/accounts")
    }

    // MARK: - Scheduled Tasks

    func fetchScheduledTasks() async throws -> [ScheduleTask] {
        return try await request("/api/scheduled_tasks")
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
            name: draft.title,
            message_content: draft.content,
            msg_type: draft.messageType.rawValue,
            media_url: draft.mediaURL,
            target_accounts: "[]",
            targets: "[]",
            send_time: ISO8601DateFormatter().string(from: draft.sendAt),
            repeat_interval: Int(draft.repeatInterval),
            repeat_count: draft.repeatCount,
            sent_count: 0,
            status: "pending",
            created_at: ISO8601DateFormatter().string(from: .now),
            next_run: resp.next_run
        )
    }

    func toggleSchedule(id: String, enabled: Bool) async throws -> ScheduleTask {
        let path = enabled ? "/api/scheduled_tasks/\(id)/resume" : "/api/scheduled_tasks/\(id)/pause"
        struct Resp: Decodable { let status: String }
        let _: Resp = try await request(path, method: "PUT")
        return ScheduleTask(
            id: id,
            name: "任务",
            message_content: "已更新",
            msg_type: "text",
            media_url: nil,
            target_accounts: "[]",
            targets: "[]",
            send_time: ISO8601DateFormatter().string(from: .now),
            repeat_interval: 60,
            repeat_count: 1,
            sent_count: 0,
            status: enabled ? "running" : "paused",
            created_at: ISO8601DateFormatter().string(from: .now),
            next_run: nil
        )
    }

    func deleteSchedule(id: String) async throws {
        struct Resp: Decodable { let status: String }
        let _: Resp = try await request("/api/scheduled_tasks/\(id)", method: "DELETE")
    }
}
