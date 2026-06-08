import SwiftUI

struct AccountScreen: View {
    @EnvironmentObject private var session: AppSession
    @State private var searchText = ""

    // 自动过滤并按"群聊"和"好友"分类
    var filteredContacts: [Contact] {
        if searchText.isEmpty { return session.contacts }
        return session.contacts.filter {
            $0.nickname.contains(searchText) || $0.remark.contains(searchText) || $0.wx_id.contains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("微信群聊与好友名单") {
                    ForEach(filteredContacts) { contact in
                        NavigationLink(destination: ChatDetailScreen(
                            chatTitle: contact.wx_id,
                            chatNickname: contact.isGroup ? "👥 \(contact.nickname)" : (contact.remark.isEmpty ? contact.nickname : contact.remark)
                        )) {
                            HStack(spacing: 14) {
                                Image(systemName: contact.isGroup ? "person.3.sequence.fill" : "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 38, height: 38)
                                    .foregroundColor(contact.isGroup ? .blue : .green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.remark.isEmpty ? contact.nickname : contact.remark)
                                        .font(.system(size: 16))
                                    Text(contact.wx_id)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("通讯录")
            .searchable(text: $searchText, prompt: "搜索联系人或群聊")
            .task {
                await session.loadRealContacts() // 打开时拉取最新电脑好友
            }
        }
    }
}
