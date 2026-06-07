import SwiftUI

struct ChatDetailScreen: View {
    @EnvironmentObject private var session: AppSession
    var chatTitle: String = "聊天"
    var chatID: String = ""
    @State private var inputText: String = ""
    @State private var pickerPresented = false
    @State private var selectedMedia: MediaSelection?
    @StateObject private var recorder = AudioRecorder()

    private var currentMessages: [ChatMessage] {
        let cid = chatID.isEmpty ? session.selectedChatID : chatID
        return session.messages[cid, default: []]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(currentMessages) { msg in
                            MessageRow(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                }
                .onChange(of: currentMessages.count) { _ in
                    if let last = currentMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button { pickerPresented = true } label: {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Button {
                        Task {
                            if recorder.isRecording {
                                recorder.stop()
                                if let url = recorder.recordedFileURL,
                                   let data = try? Data(contentsOf: url) {
                                    if let uploaded = await session.uploadMedia(data, filename: url.lastPathComponent, mimeType: "audio/m4a") {
                                        await session.sendMessage(type: .voice, text: "语音消息", mediaURL: uploaded)
                                    }
                                }
                            } else {
                                recorder.start()
                            }
                        }
                    } label: {
                        Image(systemName: recorder.isRecording ? "stop.circle" : "mic.circle")
                    }
                    TextField("输入消息", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)

                    Button("发送") {
                        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        Task {
                            await session.sendMessage(type: .text, text: text)
                            inputText = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let selectedMedia {
                    HStack {
                        Text(selectedMedia.fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
        }
        .navigationTitle(chatTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !chatID.isEmpty {
                session.selectedChatID = chatID
                session.persistAll()
            }
        }
        .sheet(isPresented: $pickerPresented) {
            MediaPicker { result in
                switch result {
                case .success(let media):
                    selectedMedia = media
                    Task {
                        if let data = try? Data(contentsOf: media.url),
                           let uploaded = await session.uploadMedia(data, filename: media.fileName, mimeType: media.mimeType) {
                            let type: ChatMessage.MessageType = media.kind == .image ? .image : .voice
                            await session.sendMessage(type: type, text: media.fileName, mediaURL: uploaded)
                            selectedMedia = nil
                        }
                    }
                case .failure(let error):
                    session.lastError = error.localizedDescription
                }
                pickerPresented = false
            }
        }
    }
}
