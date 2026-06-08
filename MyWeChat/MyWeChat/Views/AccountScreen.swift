import SwiftUI

struct AccountScreen: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.accounts) { account in
                    Button {
                        session.selectedAccountID = String(account.id)
                        session.persistAll()
                    } label: {
                        HStack {
                            AvatarCircle(text: account.nickname)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.nickname).font(.headline)
                                Text(account.status ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if String(account.id) == session.selectedAccountID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("账号")
        }
    }
}
