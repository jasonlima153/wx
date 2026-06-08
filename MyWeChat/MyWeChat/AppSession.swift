import SwiftUI
import Combine

@MainActor
final class AppSession: ObservableObject {
    @Published var accounts: [Account] = Account.mockData
    @Published var chats: [Chat] = Chat.mockData
    @Published var messages: [String: [ChatMessage]] = ChatMessage.mockDataByChatId
    @Published var schedules: [ScheduleTask] = ScheduleTask.mockData
    @Published var settings = AppSettings()
    @Published var selectedAccountID: String = Account.mockData.first?.id ?? ""
    @Published var selectedChatID: String = Chat.mockData.first?.id ?? ""
    @Published var isConnected: Bool = false
    @Published var lastError: String?

    let api = APIClient()
    let ws = WebSocketManager()
    let storage = StorageManager()

    init() {
        loadLocalState()
    }

    func loadLocalState() {
        settings = storage.loadSettings() ?? AppSettings()
        if let savedAccountID = storage.loadSelectedAccountID() {
            selectedAccountID = savedAccountID
        }
        if let savedChatID = storage.loadSelectedChatID() {
            selectedChatID = savedChatID
        }
        if let savedAccounts = storage.loadAccounts(), !savedAccounts.isEmpty {
            accounts = savedAccounts
        }
        if let savedChats = storage.loadChats(), !savedChats.isEmpty {
            chats = savedChats
        }
        if let savedSchedules = storage.loadSchedules(), !savedSchedules.isEmpty {
            schedules = savedSchedules
        }
        if let savedMessages = storage.loadMessages(), !savedMessages.isEmpty {
            messages = savedMessages
        }
    }

    func persistAll() {
        storage.saveSettings(settings)
        storage.saveSelectedAccountID(selectedAccountID)
        storage.saveSelectedChatID(selectedChatID)
        storage.saveAccounts(accounts)
        storage.saveChats(chats)
        storage.saveSchedules(schedules)
        storage.saveMessages(messages)
    }

    func connect() {
        guard let baseURL = URL(string: settings.serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            lastError = "服务器地址无效"
            return
        }
        api.baseURL = baseURL
        ws.connect(urlString: settings.websocketURL, token: settings.authToken) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let status):
                    self?.isConnected = status
                    self?.lastError = nil
                case .failure(let error):
                    self?.lastError = error.localizedDescription
                }
            }
        } onMessage: { [weak self] event in
            DispatchQueue.main.async {
                self?.handle(event: event)
            }
        }

        // 加载真实数据
        Task {
            await loadRealData()
        }
    }

    func disconnect() {
        ws.disconnect()
        isConnected = false
    }

    private func loadRealData() async {
        do {
            let realAccounts = try await api.fetchAccounts()
            if !realAccounts.isEmpty {
                accounts = realAccounts
                storage.saveAccounts(realAccounts)
            }
        } catch {
            // 使用本地缓存
        }

        do {
            let realChats = try await api.fetchConversations(accountID: selectedAccountID)
            if !realChats.isEmpty {
                chats = realChats
                storage.saveChats(realChats)
            }
        } catch {
            // 使用本地缓存
        }

        do {
            let realSchedules = try await api.fetchScheduledTasks()
            if !realSchedules.isEmpty {
                schedules = realSchedules
                storage.saveSchedules(realSchedules)
            }
        } catch {
            // 使用本地缓存
        }
    }

    func handle(event: WSInboundEvent) {
        switch event.kind {
        case .message:
            guard let msg = event.message else { return }
            var current = messages[msg.chatID, default: []]
            current.append(msg)
            messages[msg.chatID] = current
            storage.saveMessages(messages)

        case .chatList:
            if let chats = event.chats {
                self.chats = chats
                storage.saveChats(chats)
            }

        case .accountList:
            if let accounts = event.accounts {
                self.accounts = accounts
                storage.saveAccounts(accounts)
            }

        case .scheduleList:
            if let schedules = event.schedules {
                self.schedules = schedules
                storage.saveSchedules(schedules)
            }

        case .status:
            if let text = event.text {
                lastError = text
            }
        }
    }

    func sendMessage(type: ChatMessage.MessageType, text: String, mediaURL: URL? = nil) async {
        let request = SendMessageRequest(
            accountID: selectedAccountID,
            chatID: selectedChatID,
            type: type,
            text: text,
            mediaURL: mediaURL?.absoluteString
        )

        // 优先通过 WebSocket 发送（实时性更好）
        if ws.isConnected {
            let payload: [String: Any] = [
                "type": "message",
                "sender": selectedAccountID,
                "receiver": selectedChatID,
                "content": text,
                "msg_type": type.rawValue,
                "media_url": mediaURL?.absoluteString ?? "",
                "account_id": selectedAccountID
            ]
            ws.send(payload)

            // 本地立即显示发送的消息
            let localMsg = ChatMessage(
                id: UUID().uuidString,
                sender: selectedAccountID,
                receiver: selectedChatID,
                content: text,
                msg_type: type.rawValue,
                media_url: mediaURL?.absoluteString,
                file_name: nil,
                file_size: nil,
                voice_duration: nil,
                timestamp: ISO8601DateFormatter().string(from: .now),
                account_id: selectedAccountID,
                is_read: 1
            )
            var current = messages[selectedChatID, default: []]
            current.append(localMsg)
            messages[selectedChatID] = current
            storage.saveMessages(messages)
        } else {
            // WebSocket 未连接，走 REST API
            do {
                let sent = try await api.sendMessage(request)
                var current = messages[selectedChatID, default: []]
                current.append(sent)
                messages[selectedChatID] = current
                storage.saveMessages(messages)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func uploadMedia(_ data: Data, filename: String, mimeType: String) async -> URL? {
        let msgType: String
        if mimeType.hasPrefix("image") {
            msgType = "image"
        } else if mimeType.hasPrefix("audio") {
            msgType = "voice"
        } else {
            msgType = "file"
        }
        do {
            let resp = try await api.upload(data: data, filename: filename, mimeType: mimeType, accountID: selectedAccountID, msgType: msgType)
            return URL(string: resp.url)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func createSchedule(_ task: ScheduleTaskDraft) async {
        do {
            let created = try await api.createSchedule(task)
            schedules.append(created)
            storage.saveSchedules(schedules)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func toggleSchedule(_ id: String, enabled: Bool) async {
        do {
            let updated = try await api.toggleSchedule(id: id, enabled: enabled)
            if let idx = schedules.firstIndex(where: { $0.id == id }) {
                schedules[idx] = updated
                storage.saveSchedules(schedules)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteSchedule(_ id: String) async {
        do {
            try await api.deleteSchedule(id: id)
            schedules.removeAll { $0.id == id }
            storage.saveSchedules(schedules)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
