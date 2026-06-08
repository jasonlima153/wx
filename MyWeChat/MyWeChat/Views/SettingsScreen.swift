import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var session: AppSession
    @State private var serverBaseURL: String = ""
    @State private var websocketURL: String = ""
    @State private var authToken: String = ""
    @State private var appearanceIndex: Int = 0

    // 弹窗状态
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("当前受控微信") {
                    if session.accounts.isEmpty {
                        Text("暂无微信账号").foregroundStyle(.secondary)
                    } else {
                        Picker("选择微信", selection: $session.selectedAccountID) {
                            ForEach(session.accounts) { account in
                                Text(account.nickname).tag(account.id)
                            }
                        }
                        .onChange(of: session.selectedAccountID) { _ in
                            session.persistAll()
                            // 切换账号后自动刷新外面的会话列表
                            Task {
                                do {
                                    let updated = try await session.api.fetchConversations(accountID: session.selectedAccountID)
                                    session.chats = updated
                                } catch {}
                            }
                        }
                    }
                }

                Section("服务器") {
                    TextField("API 地址", text: $serverBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("WebSocket 地址", text: $websocketURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Token", text: $authToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("外观") {
                    Picker("主题", selection: $appearanceIndex) {
                        Text("跟随系统").tag(0)
                        Text("浅色").tag(1)
                        Text("深色").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(action: saveSettings) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isSaving ? "正在保存..." : "保存设置")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.green)
                    .disabled(isSaving)
                }

                Section {
                    HStack {
                        Image(systemName: session.ws.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(session.ws.isConnected ? .green : .red)
                        Text(session.ws.isConnected ? "已连接" : "未连接")
                            .foregroundColor(.secondary)
                        Spacer()
                        if let status = session.ws.reconnectStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("连接状态")
                }
            }
            .navigationTitle("设置")
            .alert(alertTitle, isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                serverBaseURL = session.settings.serverBaseURL
                websocketURL = session.settings.websocketURL
                authToken = session.settings.authToken
                appearanceIndex = session.settings.appearance.index
            }
        }
    }

    private func saveSettings() {
        // 去除前后空格
        serverBaseURL = serverBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        websocketURL = websocketURL.trimmingCharacters(in: .whitespacesAndNewlines)
        authToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)

        // 格式校验
        if serverBaseURL.isEmpty || websocketURL.isEmpty {
            alertTitle = "保存失败"
            alertMessage = "API 地址和 WebSocket 地址不能为空。"
            showAlert = true
            return
        }

        if !serverBaseURL.hasPrefix("http://") && !serverBaseURL.hasPrefix("https://") {
            alertTitle = "格式错误"
            alertMessage = "API 地址必须以 http:// 或 https:// 开头。"
            showAlert = true
            return
        }

        if !websocketURL.hasPrefix("ws://") && !websocketURL.hasPrefix("wss://") {
            alertTitle = "格式错误"
            alertMessage = "WebSocket 地址必须以 ws:// 或 wss:// 开头。"
            showAlert = true
            return
        }

        // 校验通过，保存
        isSaving = true
        session.settings.serverBaseURL = serverBaseURL
        session.settings.websocketURL = websocketURL
        session.settings.authToken = authToken
        session.settings.appearance = appearanceIndex == 1 ? .light : (appearanceIndex == 2 ? .dark : .system)
        session.persistAll()

        // 重新连接
        session.disconnect()
        session.connect()

        // 延迟一点显示成功，让用户看到保存过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            alertTitle = "保存成功"
            alertMessage = "服务器配置已更新，正在重新连接..."
            showAlert = true
        }
    }
}
