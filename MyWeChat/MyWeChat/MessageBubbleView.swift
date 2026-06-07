import SwiftUI
import SwiftData

struct MessageBubbleView: View {
    @Environment(\.modelContext) private var modelContext
    var message: Message

    var body: some View {
        HStack(alignment: .top) {
            if message.isFromMe { Spacer() }

            if !message.isFromMe {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 35, height: 35)
                    .foregroundColor(.gray.opacity(0.5))
            }

            VStack(alignment: message.isFromMe ? .trailing : .leading) {
                if message.msgType == "recalled" {
                    Text(message.isFromMe ? "你撤回了一条消息" : "对方撤回了一条消息")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                } else {
                    bubbleContent
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = message.text
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            .disabled(message.msgType == "image")

                            Button {
                                print("转发消息: \(message.id)")
                            } label: {
                                Label("转发", systemImage: "arrowshape.turn.up.right")
                            }

                            if message.isFromMe && Calendar.current.date(byAdding: .minute, value: -2, to: Date())! < message.timestamp {
                                Button(role: .destructive) {
                                    recallMessage()
                                } label: {
                                    Label("撤回", systemImage: "arrow.uturn.backward")
                                }
                            }

                            Divider()

                            Button(role: .destructive) {
                                modelContext.delete(message)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }

            if message.isFromMe {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 35, height: 35)
                    .foregroundColor(.blue.opacity(0.8))
            }

            if !message.isFromMe { Spacer() }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.msgType == "image", let path = message.localImagePath {
            if let uiImage = SandboxUtil.loadImageFromSandbox(relativePath: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .cornerRadius(8)
                    .shadow(radius: 1)
            } else {
                HStack {
                    Image(systemName: "photo").foregroundColor(.gray)
                    Text("图片加载失败").font(.caption).foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
        } else {
            Text(message.text)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isFromMe ? Color("WeChatGreen") : Color.white)
                .foregroundColor(message.isFromMe ? .white : .black)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        }
    }

    private func recallMessage() {
        withAnimation {
            message.msgType = "recalled"
            message.text = "[撤回消息]"
            message.isRecalled = true
            print("✅ 消息已在手机本地撤回: \(message.id)")
        }
    }
}
