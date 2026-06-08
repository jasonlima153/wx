import SwiftUI

struct ChatListScreen: View {
    @EnvironmentObject private var session: AppSession
    @State private var searchText = ""

    // 搜索过滤（适配新的 ChatConversation 模型）
    var searchResults: [ChatConversation] {
        if searchText.isEmpty {
            return session.chats
        }
        return session.chats.filter {
            ($0.nickname ?? $0.title).localizedCaseInsensitiveContains(searchText) ||
            ($0.last_message ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(searchResults) { chat in
                    NavigationLink {
                        ChatDetailScreen(
                            chatTitle: chat.title,
                            chatNickname: chat.nickname ?? chat.title
                        )
                    } label: {
                        HStack(spacing: 12) {
                            AvatarCircle(text: chat.nickname ?? chat.title)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chat.nickname ?? chat.title).font(.headline)
                                Text(chat.last_message ?? "暂无消息")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if chat.unread_count > 0 {
                                Text("\(chat.unread_count)")
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
            .navigationTitle("微信会话")
            .searchable(text: $searchText, prompt: "搜索联系人或群组")
            .refreshable {
                await refreshConversations()
            }
        }
    }

    // 下拉刷新：从后端拉取最新会话列表
    private func refreshConversations() async {
        guard let url = URL(string: "http://120.48.88.19:8000/api/conversations?account_id=\(session.selectedAccountID)") else { return }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let decoded = try? JSONDecoder().decode([ChatConversation].self, from: data) {
            session.chats = decoded
        }
    }
}
