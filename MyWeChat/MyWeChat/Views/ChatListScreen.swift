import SwiftUI

struct ChatListScreen: View {
    @EnvironmentObject private var session: AppSession
    @State private var searchText = ""

    // 搜索过滤
    var searchResults: [Chat] {
        if searchText.isEmpty {
            return session.chats
        }
        return session.chats.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(searchResults) { chat in
                    // 点击跳转到聊天详情页
                    NavigationLink {
                        ChatDetailScreen(chatTitle: chat.title, chatID: chat.id)
                    } label: {
                        HStack(spacing: 12) {
                            AvatarCircle(text: chat.title)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chat.title).font(.headline)
                                Text(chat.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if chat.unread_count > 0 {
                                Text("\(unread)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.red.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .navigationTitle("会话")
            .searchable(text: $searchText, prompt: "搜索联系人或群组")
            .refreshable {
                await refreshConversations()
            }
        }
    }

    // 下拉刷新：从后端拉取最新会话列表
    private func refreshConversations() async {
        do {
            let updated = try await session.api.fetchConversations(accountID: session.selectedAccountID)
            if !updated.isEmpty {
                session.chats = updated
                session.storage.saveChats(updated)
            }
        } catch {
            session.lastError = "刷新失败: \(error.localizedDescription)"
        }
    }
}
