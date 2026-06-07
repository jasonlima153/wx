import SwiftUI

// MARK: - 创建定时群发任务视图
struct CreateScheduledTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var taskManager = ScheduledTaskManager.shared

    // 任务参数
    @State private var taskName: String = ""
    @State private var messageContent: String = ""
    @State private var messageType: MessageType = .text
    @State private var mediaURL: String = ""
    @State private var sendTime = Date()
    @State private var repeatInterval: Int = 0
    @State private var repeatCount: Int = 1

    // 多选状态
    @State private var selectedAccounts: [WeChatAccount] = []
    @State private var selectedTargets: [String] = []

    // UI 状态
    @State private var showingAccountPicker = false
    @State private var showingTargetPicker = false
    @State private var showingImagePicker = false
    @State private var isCreating = false
    @State private var showSuccess = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    // 快速选择目标
    let quickTargets = ["张三", "李四", "王五", "工作群", "项目组", "全员"]

    // 间隔选项（秒）
    let intervalOptions: [(String, Int)] = [
        ("不重复", 0),
        ("每分钟", 60),
        ("每5分钟", 300),
        ("每30分钟", 1800),
        ("每小时", 3600),
        ("每天", 86400),
        ("每周", 604800)
    ]

    var body: some View {
        NavigationView {
            Form {
                // 任务名称
                Section(header: Text("任务名称")) {
                    TextField("例如：每日早安", text: $taskName)
                }

                // 消息类型
                Section(header: Text("消息类型")) {
                    Picker("类型", selection: $messageType) {
                        Text("文字").tag(MessageType.text)
                        Text("图片").tag(MessageType.image)
                        Text("语音").tag(MessageType.voice)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // 消息内容/媒体
                Section(header: Text(messageType == .text ? "消息内容" : "媒体文件")) {
                    if messageType == .text {
                        TextEditor(text: $messageContent)
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                            )
                    } else {
                        if mediaURL.isEmpty {
                            Button(action: { showingImagePicker = true }) {
                                HStack {
                                    Image(systemName: messageType == .image ? "photo.on.rectangle" : "mic")
                                    Text(messageType == .image ? "选择图片" : "选择语音文件")
                                }
                                .foregroundColor(.green)
                            }
                        } else {
                            HStack {
                                Image(systemName: messageType == .image ? "photo" : "waveform")
                                    .foregroundColor(.green)
                                Text(mediaURL.components(separatedBy: "/").last ?? "已上传")
                                    .lineLimit(1)
                                Spacer()
                                Button(action: { mediaURL = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }

                // 发送账号
                Section(header: Text("发送账号")) {
                    if selectedAccounts.isEmpty {
                        Button(action: { showingAccountPicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("选择账号")
                            }
                            .foregroundColor(.green)
                        }
                    } else {
                        ForEach(selectedAccounts) { account in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.green)
                                Text(account.nickname)
                                Spacer()
                                Button(action: {
                                    selectedAccounts.removeAll { $0.id == account.id }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        Button(action: { showingAccountPicker = true }) {
                            Text("添加更多账号")
                                .foregroundColor(.green)
                        }
                    }
                }

                // 发送目标
                Section(header: Text("发送目标（群组/好友）")) {
                    ForEach(selectedTargets, id: \.self) { target in
                        HStack {
                            Image(systemName: target.contains("群") ? "person.2.circle.fill" : "person.circle.fill")
                                .foregroundColor(.blue)
                            Text(target)
                            Spacer()
                            Button(action: {
                                selectedTargets.removeAll { $0 == target }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button(action: { showingTargetPicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("添加目标")
                        }
                        .foregroundColor(.green)
                    }
                }

                // 发送时间
                Section(header: Text("发送时间")) {
                    DatePicker("首次发送时间", selection: $sendTime, displayedComponents: [.date, .hourAndMinute])
                }

                // 循环设置
                Section(header: Text("循环设置")) {
                    Picker("重复间隔", selection: $repeatInterval) {
                        ForEach(intervalOptions, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }

                    if repeatInterval > 0 {
                        Stepper("循环次数: \(repeatCount)", value: $repeatCount, in: 1...100)
                    }
                }

                // 创建按钮
                Section {
                    Button(action: createTask) {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isCreating ? "创建中..." : "创建定时任务")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .listRowInsets(EdgeInsets())
                    }
                    .listRowBackground(Color.green)
                    .disabled(isFormInvalid || isCreating)
                }
            }
            .navigationTitle("新建群发任务")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                trailing: EmptyView()
            )
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerView(selectedAccounts: $selectedAccounts)
            }
            .sheet(isPresented: $showingTargetPicker) {
                TargetPickerView(selectedTargets: $selectedTargets)
            }
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: messageType == .image ? .images : .videos)
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem = newItem else { return }
                newItem.loadTransferable(type: Data.self) { result in
                    if case .success(let data) = result, let data = data {
                        if messageType == .image, let image = UIImage(data: data) {
                            UploadManager.shared.uploadImage(image, to: "scheduled") { url in
                                if let url = url {
                                    DispatchQueue.main.async {
                                        self.mediaURL = url
                                    }
                                }
                            }
                        } else {
                            // 语音文件直接上传
                            UploadManager.shared.uploadVoice(data, duration: 0, to: "scheduled") { url in
                                if let url = url {
                                    DispatchQueue.main.async {
                                        self.mediaURL = url
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .alert(isPresented: $showSuccess) {
                Alert(
                    title: Text("成功"),
                    message: Text("定时任务已创建"),
                    dismissButton: .default(Text("确定")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }

    private var isFormInvalid: Bool {
        let hasContent = messageType == .text ? !messageContent.isEmpty : !mediaURL.isEmpty
        return !hasContent || selectedAccounts.isEmpty || selectedTargets.isEmpty
    }

    private func createTask() {
        isCreating = true
        let content = messageType == .text ? messageContent : mediaURL
        taskManager.createTask(
            name: taskName,
            messageContent: content,
            msgType: messageType.rawValue,
            mediaURL: messageType == .text ? nil : mediaURL,
            targetAccounts: selectedAccounts.map { $0.id },
            targets: selectedTargets,
            sendTime: sendTime,
            repeatInterval: repeatInterval,
            repeatCount: repeatCount
        ) { success in
            isCreating = false
            if success {
                showSuccess = true
            }
        }
    }
}

// MARK: - 账号选择器
struct AccountPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedAccounts: [WeChatAccount]
    @State private var accounts: [WeChatAccount] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(accounts) { account in
                    Button {
                        toggleAccount(account)
                    } label: {
                        HStack {
                            let isSel = selectedAccounts.contains { $0.id == account.id }
                            Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSel ? .green : .gray)
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.nickname)
                                    .font(.system(size: 16))
                                Text("ID: \(account.wxID)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择账号")
            .navigationBarItems(
                leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("确定") { presentationMode.wrappedValue.dismiss() }
            )
            .onAppear { loadAccounts() }
        }
    }

    private func toggleAccount(_ account: WeChatAccount) {
        if let index = selectedAccounts.firstIndex(where: { $0.id == account.id }) {
            selectedAccounts.remove(at: index)
        } else {
            selectedAccounts.append(account)
        }
    }

    private func loadAccounts() {
        accounts = StorageManager.shared.fetchAccounts()
        if accounts.isEmpty {
            APIManager.shared.fetchAccounts { serverAccounts in
                if let serverAccounts = serverAccounts {
                    DispatchQueue.main.async {
                        self.accounts = serverAccounts
                    }
                }
            }
        }
    }
}

// MARK: - 目标选择器
struct TargetPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedTargets: [String]
    @State private var newTarget: String = ""

    let quickTargets = ["张三", "李四", "王五", "赵六", "工作群", "项目组", "全员"]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("输入目标")) {
                    HStack {
                        TextField("好友/群组名称", text: $newTarget)
                            .autocapitalization(.none)
                        Button("添加") {
                            if !newTarget.isEmpty && !selectedTargets.contains(newTarget) {
                                selectedTargets.append(newTarget)
                                newTarget = ""
                            }
                        }
                        .disabled(newTarget.isEmpty)
                    }
                }

                Section(header: Text("快速选择")) {
                    ForEach(quickTargets, id: \.self) { target in
                        Button {
                            toggleTarget(target)
                        } label: {
                            HStack {
                                Image(systemName: selectedTargets.contains(target) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedTargets.contains(target) ? .green : .gray)
                                Text(target)
                                Spacer()
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                if !selectedTargets.isEmpty {
                    Section(header: Text("已选 (\(selectedTargets.count))")) {
                        ForEach(selectedTargets, id: \.self) { target in
                            HStack {
                                Text(target)
                                Spacer()
                                Button(action: {
                                    selectedTargets.removeAll { $0 == target }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择目标")
            .navigationBarItems(
                leading: Button("取消") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("确定") { presentationMode.wrappedValue.dismiss() }
            )
        }
    }

    private func toggleTarget(_ target: String) {
        if let index = selectedTargets.firstIndex(of: target) {
            selectedTargets.remove(at: index)
        } else {
            selectedTargets.append(target)
        }
    }
}
