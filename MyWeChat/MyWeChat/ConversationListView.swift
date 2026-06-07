import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.timestamp, order: .reverse) private var conversations: [Conversation]

    var body: some View {
        NavigationView {
            List {
                ForEach(conversations) { conv in
                    NavigationLink(destination: ChatDetailView(conversation: conv)) {
                        HStack(spacing: 12) {
                            Image(systemName: conv.avatar)
                                .resizable()
                                .frame(width: 45, height: 45)
                                .foregroundColor(.blue)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(conv.name)
                                    .font(.system(size: 17, weight: .regular))
                                Text(conv.lastMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatTime(conv.timestamp))
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)

                                if conv.unreadCount > 0 {
                                    Text("\(conv.unreadCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteConversation)
            }
            .listStyle(PlainListStyle())
            .navigationTitle("微信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "plus.circle")
                }
            }
        }
    }

    private func deleteConversation(offsets: IndexSet) {
        for index in offsets {
            let conv = conversations[index]
            modelContext.delete(conv)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
