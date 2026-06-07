import SwiftUI
import SwiftData

struct ChatDetailView: View {
    @Environment(\.modelContext) private var modelContext
    var conversation: Conversation

    @State private var inputText: String = ""
    @Query private var messages: [Message]

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
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
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
            let replyText = "[模拟本地回复] 收到你的消息: \(sentText)"
            let replyMsg = Message(conversationId: conversation.id, text: replyText, isFromMe: false)
            modelContext.insert(replyMsg)

            conversation.lastMessage = replyText
            conversation.timestamp = Date()
        }
    }
}

struct MessageBubbleView: View {
    var message: Message

    var body: some View {
        HStack {
            if message.isFromMe { Spacer() }

            Text(message.text)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isFromMe ? Color("WeChatGreen") : Color.white)
                .foregroundColor(message.isFromMe ? .white : .black)
                .cornerRadius(6)

            if !message.isFromMe { Spacer() }
        }
    }
}
