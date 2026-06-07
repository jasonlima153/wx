import SwiftUI

// MARK: - 会话列表
struct ConversationListView: View {
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var showingNewChat = false
    @State private var searchText = ""

    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return wsManager.conversations
        }
        return wsManager.conversations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            List {
                if filteredConversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("暂无会话")
                            .foregroundColor(.gray)
                        Text("点击右上角 + 开始新聊天")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(filteredConversations) { conv in
                        NavigationLink(destination: ChatDetailView(conversationName: conv.name)) {
                            ConversationRowView(conversation: conv)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .searchable(text: $searchText, placeholder: "搜索")
            .navigationTitle("微信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewChat = true }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22))
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                NewChatView()
            }
            .onAppear {
                wsManager.fetchConversations()
            }
            .refreshable {
                wsManager.fetchConversations()
            }
        }
    }
}

// MARK: - 会话行
struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: conversation.isGroup ? "person.2.circle.fill" : "person.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.green)
            }

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.name)
                        .font(.system(size: 17, weight: .medium))
                        .lineLimit(1)

                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text(conversation.lastMessageTime?.displayTime ?? "")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                HStack {
                    Text(conversation.lastMessage ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
