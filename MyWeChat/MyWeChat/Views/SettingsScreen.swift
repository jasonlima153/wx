import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var session: AppSession
    @State private var serverBaseURL: String = "https://your-domain.com"
    @State private var websocketURL: String = "wss://your-domain.com/ws"
    @State private var authToken: String = ""
    @State private var appearanceIndex: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    TextField("API 地址", text: $serverBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("WebSocket 地址", text: $websocketURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Token", text: $authToken)
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
                    Button("保存设置") {
                        session.settings.serverBaseURL = serverBaseURL
                        session.settings.websocketURL = websocketURL
                        session.settings.authToken = authToken
                        session.settings.appearance = appearanceIndex == 1 ? .light : (appearanceIndex == 2 ? .dark : .system)
                        session.persistAll()
                        session.connect()
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear {
                serverBaseURL = session.settings.serverBaseURL
                websocketURL = session.settings.websocketURL
                authToken = session.settings.authToken
                appearanceIndex = session.settings.appearance.index
            }
        }
    }
}
