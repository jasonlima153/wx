import SwiftUI
import PhotosUI

// MARK: - 聊天详情视图
struct ChatDetailView: View {
    let conversationName: String
    @StateObject private var wsManager = WebSocketManager.shared
    @State private var inputText: String = ""
    @State private var showingImagePicker = false
    @State private var showingFilePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isRecording = false
    @State private var showMediaViewer = false
    @State private var selectedMediaURL: String = ""
    @State private var selectedMediaType: MessageType = .image

    private var filteredMessages: [Message] {
        wsManager.messages.filter {
            $0.receiver == conversationName || $0.sender == conversationName
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredMessages) { msg in
                            MessageRowView(message: msg)
                                .id(msg.id)
                                .onTapGesture {
                                    if msg.type == .image, let url = msg.mediaURL {
                                        selectedMediaURL = url
                                        selectedMediaType = .image
                                        showMediaViewer = true
                                    }
                                }
                                .onLongPressGesture {
                                    // TODO: 显示消息操作菜单（撤回、转发、删除）
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
                .onChange(of: wsManager.messages.count) { _ in
                    if let last = filteredMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // 输入栏
            HStack(spacing: 10) {
                // 语音按钮
                Button(action: toggleRecording) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isRecording ? .red : .gray)
                }

                // 图片按钮
                Button(action: { showingImagePicker = true }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }

                // 输入框
                TextField("输入消息...", text: $inputText)
                    .padding(8)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(18)
                    .onSubmit(sendTextMessage)

                // 文件按钮
                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }

                // 发送按钮
                Button(action: sendTextMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(inputText.isEmpty ? .gray : .green)
                }
                .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .navigationTitle(conversationName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            wsManager.fetchMessages(for: conversationName)
        }
        .sheet(isPresented: $showingImagePicker) {
            imagePickerSheet
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.item], onCompletion: handleFileImport)
        .fullScreenCover(isPresented: $showMediaViewer) {
            MediaViewerView(urlString: selectedMediaURL, type: selectedMediaType)
        }
        .overlay(
            Group {
                if isRecording {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text("录音中...")
                                    .font(.headline)
                                Text(String(format: "%.1f", AudioService.shared.recordingDuration) + " 秒")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(16)
                        .padding(.bottom, 100)
                    }
                }
            }
        )
    }

    // MARK: - 图片选择器
    @ViewBuilder
    private var imagePickerSheet: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Text("选择图片")
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem = newItem else { return }
            newItem.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data = data,
                   let image = UIImage(data: data) {
                    UploadManager.shared.uploadImage(image, to: conversationName) { _ in }
                }
            }
        }
    }

    // MARK: - 操作方法

    private func sendTextMessage() {
        guard !inputText.isEmpty else { return }
        wsManager.sendMessage(content: inputText, to: conversationName)
        inputText = ""
    }

    private func toggleRecording() {
        if isRecording {
            if let voiceData = AudioService.shared.stopRecording() {
                let duration = AudioService.shared.recordingDuration
                UploadManager.shared.uploadVoice(voiceData, duration: duration, to: conversationName) { _ in }
            }
            isRecording = false
        } else {
            AudioService.shared.startRecording()
            isRecording = true
        }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        if case .success(let url) = result {
            // 确保可以访问文件
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            UploadManager.shared.uploadFile(at: url, to: conversationName) { _ in }
        }
    }
}
