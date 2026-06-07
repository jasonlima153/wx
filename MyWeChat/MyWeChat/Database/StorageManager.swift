import Foundation
import SQLite3

// MARK: - 本地 SQLite 缓存管理
class StorageManager {
    static let shared = StorageManager()
    private var db: OpaquePointer?

    private init() {
        openDatabase()
        createTables()
    }

    private func getDBPath() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("wechat_cache.db").path
    }

    private func openDatabase() {
        let path = getDBPath()
        if sqlite3_open(path, &db) != SQLITE_OK {
            print("❌ 打开数据库失败")
            return
        }
        print("✅ 数据库已打开: \(path)")
    }

    private func createTables() {
        let createMessages = """
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            sender TEXT NOT NULL,
            receiver TEXT NOT NULL,
            content TEXT DEFAULT '',
            type TEXT DEFAULT 'text',
            timestamp REAL NOT NULL,
            account_id TEXT DEFAULT '',
            media_url TEXT,
            file_name TEXT,
            file_size INTEGER,
            voice_duration REAL,
            is_read INTEGER DEFAULT 1,
            is_sent INTEGER DEFAULT 1,
            is_from_me INTEGER DEFAULT 0
        );
        """

        let createConversations = """
        CREATE TABLE IF NOT EXISTS conversations (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            avatar TEXT,
            last_message TEXT,
            last_message_time REAL,
            unread_count INTEGER DEFAULT 0,
            account_id TEXT DEFAULT '',
            is_group INTEGER DEFAULT 0,
            is_pinned INTEGER DEFAULT 0
        );
        """

        let createAccounts = """
        CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY,
            nickname TEXT NOT NULL,
            wx_id TEXT UNIQUE NOT NULL,
            phone TEXT,
            avatar TEXT,
            is_active INTEGER DEFAULT 0,
            last_login REAL,
            server_url TEXT
        );
        """

        execute(sql: createMessages)
        execute(sql: createConversations)
        execute(sql: createAccounts)
    }

    private func execute(sql: String, params: [Any]? = nil) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            guard let stmt = statement else { return }
            if let params = params {
                for (index, param) in params.enumerated() {
                    let idx = Int32(index + 1)
                    if let text = param as? String {
                        sqlite3_bind_text(stmt, idx, (text as NSString).utf8String, -1, nil)
                    } else if let num = param as? Int {
                        sqlite3_bind_int(stmt, idx, Int32(num))
                    } else if let num = param as? Int64 {
                        sqlite3_bind_int64(stmt, idx, num)
                    } else if let num = param as? Double {
                        sqlite3_bind_double(stmt, idx, num)
                    } else if let num = param as? Bool {
                        sqlite3_bind_int(stmt, idx, num ? 1 : 0)
                    }
                }
            }
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - 消息操作

    func saveMessage(_ message: Message) {
        let sql = """
        INSERT OR REPLACE INTO messages
        (id, sender, receiver, content, type, timestamp, account_id, media_url, file_name, file_size, voice_duration, is_read, is_sent, is_from_me)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        execute(sql: sql, params: [
            message.id, message.sender, message.receiver, message.content,
            message.type.rawValue, message.timestamp.timeIntervalSince1970,
            message.accountID, message.mediaURL ?? "", message.fileName ?? "",
            message.fileSize ?? 0, message.voiceDuration ?? 0,
            message.isRead, message.isSent, message.isFromMe
        ])
    }

    func saveMessages(_ messages: [Message]) {
        for msg in messages {
            saveMessage(msg)
        }
    }

    func fetchMessages(accountID: String, conversationName: String) -> [Message] {
        var results: [Message] = []
        let sql = """
        SELECT * FROM messages
        WHERE account_id = ? AND (sender = ? OR receiver = ?)
        ORDER BY timestamp DESC LIMIT 100;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            guard let stmt = statement else { return results }
            sqlite3_bind_text(stmt, 1, (accountID as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (conversationName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (conversationName as NSString).utf8String, -1, nil)

            while sqlite3_step(stmt) == SQLITE_ROW {
                if let msg = parseMessageRow(stmt) {
                    results.append(msg)
                }
            }
            sqlite3_finalize(stmt)
        }
        return results.reversed()
    }

    func fetchUnreadMessages(accountID: String) -> [Message] {
        var results: [Message] = []
        let sql = "SELECT * FROM messages WHERE account_id = ? AND is_read = 0 ORDER BY timestamp;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            guard let stmt = statement else { return results }
            sqlite3_bind_text(stmt, 1, (accountID as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let msg = parseMessageRow(stmt) {
                    results.append(msg)
                }
            }
            sqlite3_finalize(statement)
        }
        return results
    }

    func markMessageAsRead(_ messageID: String) {
        execute(sql: "UPDATE messages SET is_read = 1 WHERE id = ?;", params: [messageID])
    }

    func deleteMessage(_ messageID: String) {
        execute(sql: "DELETE FROM messages WHERE id = ?;", params: [messageID])
    }

    func clearMessages(accountID: String) {
        execute(sql: "DELETE FROM messages WHERE account_id = ?;", params: [accountID])
    }

    // MARK: - 会话操作

    func saveConversation(_ conv: Conversation) {
        let sql = """
        INSERT OR REPLACE INTO conversations
        (id, name, avatar, last_message, last_message_time, unread_count, account_id, is_group, is_pinned)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        execute(sql: sql, params: [
            conv.id, conv.name, conv.avatar ?? "",
            conv.lastMessage ?? "", conv.lastMessageTime?.timeIntervalSince1970 ?? 0,
            conv.unreadCount, conv.accountID, conv.isGroup, conv.isPinned
        ])
    }

    func fetchConversations(accountID: String) -> [Conversation] {
        var results: [Conversation] = []
        let sql = "SELECT * FROM conversations WHERE account_id = ? ORDER BY is_pinned DESC, last_message_time DESC;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            guard let stmt = statement else { return results }
            sqlite3_bind_text(stmt, 1, (accountID as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let name = String(cString: sqlite3_column_text(stmt, 1))
                let avatar = String(cString: sqlite3_column_text(stmt, 2))
                let lastMsg = String(cString: sqlite3_column_text(stmt, 3))
                let lastTime = sqlite3_column_double(stmt, 4)
                let unread = Int(sqlite3_column_int(stmt, 5))
                let accID = String(cString: sqlite3_column_text(stmt, 6))
                let isGroup = sqlite3_column_int(stmt, 7) == 1
                let isPinned = sqlite3_column_int(stmt, 8) == 1

                results.append(Conversation(
                    id: id, name: name, avatar: avatar.isEmpty ? nil : avatar,
                    lastMessage: lastMsg.isEmpty ? nil : lastMsg,
                    lastMessageTime: lastTime > 0 ? Date(timeIntervalSince1970: lastTime) : nil,
                    unreadCount: unread, accountID: accID, isGroup: isGroup, isPinned: isPinned
                ))
            }
            sqlite3_finalize(statement)
        }
        return results
    }

    // MARK: - 账号操作

    func saveAccount(_ account: WeChatAccount) {
        let sql = """
        INSERT OR REPLACE INTO accounts
        (id, nickname, wx_id, phone, avatar, is_active, last_login, server_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        execute(sql: sql, params: [
            account.id, account.nickname, account.wxID,
            account.phone ?? "", account.avatar ?? "",
            account.isActive, account.lastLoginDate?.timeIntervalSince1970 ?? 0,
            account.serverURL ?? ""
        ])
    }

    func fetchAccounts() -> [WeChatAccount] {
        var results: [WeChatAccount] = []
        let sql = "SELECT * FROM accounts ORDER BY is_active DESC, last_login DESC;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            guard let stmt = statement else { return results }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let nickname = String(cString: sqlite3_column_text(stmt, 1))
                let wxID = String(cString: sqlite3_column_text(stmt, 2))
                let phone = String(cString: sqlite3_column_text(stmt, 3))
                let avatar = String(cString: sqlite3_column_text(stmt, 4))
                let isActive = sqlite3_column_int(stmt, 5) == 1
                let lastLogin = sqlite3_column_double(stmt, 6)
                let serverURL = String(cString: sqlite3_column_text(stmt, 7))

                results.append(WeChatAccount(
                    id: id, nickname: nickname, avatar: avatar.isEmpty ? nil : avatar,
                    wxID: wxID, phone: phone.isEmpty ? nil : phone,
                    isActive: isActive,
                    lastLoginDate: lastLogin > 0 ? Date(timeIntervalSince1970: lastLogin) : nil,
                    serverURL: serverURL.isEmpty ? nil : serverURL
                ))
            }
            sqlite3_finalize(stmt)
        }
        return results
    }

    func deleteAccount(_ accountID: String) {
        execute(sql: "DELETE FROM accounts WHERE id = ?;", params: [accountID])
        execute(sql: "DELETE FROM messages WHERE account_id = ?;", params: [accountID])
        execute(sql: "DELETE FROM conversations WHERE account_id = ?;", params: [accountID])
    }

    // MARK: - 私有辅助

    private func parseMessageRow(_ statement: OpaquePointer) -> Message? {
        guard let id = sqlite3_column_text(statement, 0) else { return nil }
        guard let sender = sqlite3_column_text(statement, 1) else { return nil }
        guard let receiver = sqlite3_column_text(statement, 2) else { return nil }
        guard let content = sqlite3_column_text(statement, 3) else { return nil }
        guard let typeStr = sqlite3_column_text(statement, 4) else { return nil }

        let mediaURL = sqlite3_column_text(statement, 7).map { String(cString: $0) }
        let fileName = sqlite3_column_text(statement, 8).map { String(cString: $0) }

        return Message(
            id: String(cString: id),
            sender: String(cString: sender),
            receiver: String(cString: receiver),
            content: String(cString: content),
            type: MessageType(rawValue: String(cString: typeStr)) ?? .text,
            timestamp: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
            accountID: sqlite3_column_text(statement, 6).map { String(cString: $0) } ?? "",
            mediaURL: mediaURL,
            fileName: fileName,
            fileSize: sqlite3_column_int64(statement, 9),
            voiceDuration: sqlite3_column_double(statement, 10),
            isRead: sqlite3_column_int(statement, 11) == 1,
            isSent: sqlite3_column_int(statement, 12) == 1,
            isFromMe: sqlite3_column_int(statement, 13) == 1
        )
    }
}
