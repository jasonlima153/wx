import SwiftUI
import SwiftData
import PhotosUI

struct ChatDetailView: View {
    @Environment(\.modelContext) private var modelContext
    var conversation: Conversation

    @State private var inputText: String = ""
    @Query private var messages: [Message]

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isProcessingImage = false

    init(conversation: Conversation) {
        self.conversation = conversation
        let convId = conversation.id
        let filter = #Predicate<Message> { $0.conversationId == convId }
        _messages = Query(filter: filter, sort: \Message.timestamp, order: .forward)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(messages) { msg in
                            MessageBubbleView(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))
                .onChange(of: messages.count) {
                    if let lastMsg = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }
                }
            }

            if isProcessingImage {
                ProgressView("正在处理图片...").padding()
            }

            HStack(spacing: 12) {
                Image(systemName: "mic.circle")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)

                TextField("输入消息...", text: $inputText)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(4)

                if !inputText.isEmpty {
                    Button(action: sendMessage) {
                        Text("发送")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                } else {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "photo.circle")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(UIColor.systemGray6))
        }
        .navigationTitle(conversation.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            conversation.unreadCount = 0
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            handleSelectedPhoto(newItem)
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let myMsg = Message(conversationId: conversation.id, text: inputText, isFromMe: true)
        modelContext.insert(myMsg)

        conversation.lastMessage = inputText
        conversation.timestamp = Date()

        let sentText = inputText
        inputText = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let replyText = "[模拟回复] 已收到: \(sentText)"
            let replyMsg = Message(conversationId: conversation.id, text: replyText, isFromMe: false)
            modelContext.insert(replyMsg)
            conversation.lastMessage = replyText
            conversation.timestamp = Date()
        }
    }

    private func handleSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        isProcessingImage = true

        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                isProcessingImage = false
                selectedPhotoItem = nil

                switch result {
                case .success(let data):
                    guard let imageData = data else { return }

                    guard let relativePath = SandboxUtil.saveImageToSandbox(data: imageData) else {
                        print("❌ 保存沙盒失败")
                        return
                    }

                    let imgMsg = Message(
                        conversationId: conversation.id,
                        text: "[图片消息]",
                        isFromMe: true,
                        msgType: "image",
                        localImagePath: relativePath
                    )

                    modelContext.insert(imgMsg)
                    conversation.lastMessage = "[图片]"
                    conversation.timestamp = Date()
                    print("✅ 图片消息已存入数据库: \(relativePath)")

                case .failure(let error):
                    print("❌ 读取相册失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
