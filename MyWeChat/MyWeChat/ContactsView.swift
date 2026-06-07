import SwiftUI
import SwiftData

struct ContactsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var conversations: [Conversation]

    let contacts = ["张小龙", "文件传输助手", "李四", "王五", "前端开发群", "产品核心群", "VIP客户名单", "所有客户群", "赵六", "孙七"]

    @State private var navigateToChat = false
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationView {
            List(contacts, id: \.self) { contact in
                Button(action: {
                    openChat(for: contact)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue.opacity(0.8))

                        Text(contact)
                            .foregroundColor(.primary)
                            .font(.system(size: 16))

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("通讯录")
            .background(
                NavigationLink(
                    destination: Group {
                        if let conv = selectedConversation {
                            ChatDetailView(conversation: conv)
                        }
                    },
                    isActive: $navigateToChat,
                    label: { EmptyView() }
                )
            )
        }
    }

    private func openChat(for name: String) {
        if let existingConv = conversations.first(where: { $0.name == name }) {
            selectedConversation = existingConv
        } else {
            let newConv = Conversation(name: name)
            modelContext.insert(newConv)
            selectedConversation = newConv
        }
        navigateToChat = true
    }
}
