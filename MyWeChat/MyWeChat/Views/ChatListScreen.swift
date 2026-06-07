import SwiftUI

struct ChatListScreen: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.chats) { chat in
                    Button {
                        session.selectedChatID = chat.id
                        session.persistAll()
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
                            if let unread = chat.unreadCount, unread > 0 {
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
            .toolbar {
                NavigationLink("聊天") {
                    ChatDetailScreen()
                }
            }
        }
    }
}
