import Foundation

final class StorageManager {
    private let settingsKey = "app.settings"
    private let accountKey = "app.accounts"
    private let chatKey = "app.chats"
    private let scheduleKey = "app.schedules"
    private let messagesKey = "app.messages"
    private let selectedAccountKey = "app.selectedAccount"
    private let selectedChatKey = "app.selectedChat"

    func saveSettings(_ settings: AppSettings) { save(settings, forKey: settingsKey) }
    func loadSettings() -> AppSettings? { load(AppSettings.self, forKey: settingsKey) }

    func saveAccounts(_ accounts: [Account]) { save(accounts, forKey: accountKey) }
    func loadAccounts() -> [Account]? { load([Account].self, forKey: accountKey) }

    func saveChats(_ chats: [Chat]) { save(chats, forKey: chatKey) }
    func loadChats() -> [Chat]? { load([Chat].self, forKey: chatKey) }

    func saveSchedules(_ schedules: [ScheduleTask]) { save(schedules, forKey: scheduleKey) }
    func loadSchedules() -> [ScheduleTask]? { load([ScheduleTask].self, forKey: scheduleKey) }

    func saveMessages(_ messages: [String: [ChatMessage]]) { save(messages, forKey: messagesKey) }
    func loadMessages() -> [String: [ChatMessage]]? { load([String: [ChatMessage]].self, forKey: messagesKey) }

    func saveSelectedAccountID(_ id: String) { UserDefaults.standard.set(id, forKey: selectedAccountKey) }
    func loadSelectedAccountID() -> String? { UserDefaults.standard.string(forKey: selectedAccountKey) }

    func saveSelectedChatID(_ id: String) { UserDefaults.standard.set(id, forKey: selectedChatKey) }
    func loadSelectedChatID() -> String? { UserDefaults.standard.string(forKey: selectedChatKey) }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
