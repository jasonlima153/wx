import SwiftUI
import SwiftData

struct ContactsView: View {
    @Environment(\.modelContext) private var modelContext

    let friends: [(name: String, avatar: String)] = [
        ("张小龙", "person.crop.circle"),
        ("文件传输助手", "folder.fill"),
        ("李四", "person.circle.fill"),
        ("王五", "person.circle.fill"),
        ("前端开发群", "person.2.circle"),
        ("产品核心群", "person.2.circle"),
        ("VIP客户名单", "star.circle"),
        ("所有客户群", "person.3.circle"),
        ("赵六", "person.circle"),
        ("孙七", "person.circle"),
        ("周八", "person.circle"),
        ("吴九", "person.circle")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(friends, id: \.name) { friend in
                    Button(action: {
                        createOrOpenConversation(friend: friend)
                    }) {
                        HStack(spacing: 14) {
                            Image(systemName: friend.avatar)
                                .resizable()
                                .frame(width: 42, height: 42)
                                .foregroundColor(.blue.opacity(0.7))
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(friend.name)
                                    .font(.system(size: 17))
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("通讯录")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func createOrOpenConversation(friend: (name: String, avatar: String)) {
        let convId = "wxid_\(friend.name)"
        let fetchDescriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == convId })
        let existing = try? modelContext.fetch(fetchDescriptor)

        if existing?.first == nil {
            let conv = Conversation(id: convId, name: friend.name, avatar: friend.avatar, lastMessage: "", timestamp: Date())
            modelContext.insert(conv)
        }
    }
}
