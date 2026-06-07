import SwiftUI

struct ScheduleEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = "定时群发"
    @State private var content: String = ""
    @State private var sendAt: Date = .now.addingTimeInterval(60)
    @State private var repeatInterval: Double = 3600
    @State private var repeatCount: Int = 1
    @State private var type: ChatMessage.MessageType = .text
    @State private var targetChatIDs: Set<String> = []
    @State private var targetAccountIDs: Set<String> = []
    @State private var media: MediaSelection?
    @State private var mediaPickerPresented = false

    let onSave: (ScheduleTaskDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("任务标题", text: $title)
                }

                Section("消息类型") {
                    Picker("类型", selection: $type) {
                        Text("文字").tag(ChatMessage.MessageType.text)
                        Text("图片").tag(ChatMessage.MessageType.image)
                        Text("语音").tag(ChatMessage.MessageType.voice)
                        Text("文件").tag(ChatMessage.MessageType.file)
                    }
                    .pickerStyle(.segmented)
                }

                Section("内容") {
                    if type == .text {
                        TextEditor(text: $content)
                            .frame(minHeight: 120)
                    } else {
                        Button("选择媒体文件") {
                            mediaPickerPresented = true
                        }
                        if let media {
                            Text(media.fileName).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("发送时间") {
                    DatePicker("首次发送", selection: $sendAt)
                }

                Section("循环") {
                    Stepper("循环次数：\(repeatCount)", value: $repeatCount, in: 1...999)
                    Stepper("循环间隔：\(Int(repeatInterval)) 秒", value: $repeatInterval, in: 60...86400)
                }

                Section("目标") {
                    Text("建议你后面改成多选聊天和多账号列表")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新建任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let draft = ScheduleTaskDraft(
                            title: title,
                            content: content,
                            messageType: type,
                            sendAt: sendAt,
                            repeatInterval: repeatInterval,
                            repeatCount: repeatCount,
                            targetAccountIDs: Array(targetAccountIDs),
                            targetChatIDs: Array(targetChatIDs),
                            mediaURL: media?.url.absoluteString
                        )
                        onSave(draft)
                    }
                }
            }
            .sheet(isPresented: $mediaPickerPresented) {
                MediaPicker { result in
                    switch result {
                    case .success(let m): media = m
                    case .failure: break
                    }
                    mediaPickerPresented = false
                }
            }
        }
    }
}
