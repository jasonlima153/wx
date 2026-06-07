import SwiftUI

// MARK: - 多账号选择视图
struct AccountSelectionView: View {
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var accounts: [WeChatAccount] = []
    @State private var showingAddAccount = false
    @State private var newNickname = ""
    @State private var newWxID = ""

    var body: some View {
        NavigationView {
            List {
                // 当前活跃账号
                if let activeAccount = accounts.first(where: { $0.isActive }) {
                    Section(header: Text("当前账号")) {
                        ActiveAccountRow(account: activeAccount)
                    }
                }

                // 其他账号
                let otherAccounts = accounts.filter { !$0.isActive }
                if !otherAccounts.isEmpty {
                    Section(header: Text("其他账号")) {
                        ForEach(otherAccounts) { account in
                            Button(action: {
                                switchToAccount(account)
                            }) {
                                AccountRow(account: account)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // 添加账号
                Section {
                    Button(action: { showingAddAccount = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("添加账号")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("账号管理")
            .onAppear {
                loadAccounts()
            }
            .sheet(isPresented: $showingAddAccount) {
                addAccountSheet
            }
        }
    }

    // MARK: - 活跃账号行
    private struct ActiveAccountRow: View {
        let account: WeChatAccount

        var body: some View {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 55, height: 55)
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 55, height: 55)
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(account.nickname)
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                    }
                    Text("ID: \(account.wxID)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    if let date = account.lastLoginDate {
                        Text("上次登录: \(date.displayTime)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 账号行
    private struct AccountRow: View {
        let account: WeChatAccount

        var body: some View {
            HStack(spacing: 14) {
                Image(systemName: "person.circle")
                    .resizable()
                    .frame(width: 45, height: 45)
                    .foregroundColor(.gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.nickname)
                        .font(.system(size: 16, weight: .medium))
                    Text("ID: \(account.wxID)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 添加账号
    @ViewBuilder
    private var addAccountSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("账号信息")) {
                    TextField("昵称", text: $newNickname)
                    TextField("微信号", text: $newWxID)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("添加账号")
            .navigationBarItems(
                leading: Button("取消") { showingAddAccount = false },
                trailing: Button("添加") {
                    addAccount()
                }
                .disabled(newNickname.isEmpty || newWxID.isEmpty)
            )
        }
    }

    // MARK: - 操作方法

    private func loadAccounts() {
        accounts = StorageManager.shared.fetchAccounts()
        if accounts.isEmpty {
            APIManager.shared.fetchAccounts { [weak self] serverAccounts in
                if let serverAccounts = serverAccounts {
                    DispatchQueue.main.async {
                        self?.accounts = serverAccounts
                    }
                }
            }
        }
    }

    private func addAccount() {
        let account = WeChatAccount(nickname: newNickname, wxID: newWxID)
        StorageManager.shared.saveAccount(account)

        APIManager.shared.createAccount(nickname: newNickname, wxID: newWxID) { success in
            if success {
                print("✅ 账号创建成功")
            }
        }

        accounts.append(account)
        newNickname = ""
        newWxID = ""
        showingAddAccount = false
    }

    private func switchToAccount(_ account: WeChatAccount) {
        APIManager.shared.activateAccount(account.id) { success in
            if success {
                DispatchQueue.main.async {
                    self.accounts = self.accounts.map { acc in
                        var updated = acc
                        updated.isActive = (acc.id == account.id)
                        return updated
                    }
                    StorageManager.shared.saveAccount(account)

                    wsManager.setCurrentAccount(account.id)
                    wsManager.fetchConversations()
                }
            }
        }
    }
}
