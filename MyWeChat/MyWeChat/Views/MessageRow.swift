import SwiftUI

// MARK: - 消息行视图
struct MessageRowView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromMe { Spacer(minLength: 60) }

            if !message.isFromMe {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.gray)
            }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                // 消息内容
                MessageContentView(message: message)

                // 时间
                Text(message.timestamp.chatTime)
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.7))
            }

            if message.isFromMe {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.green)
            }

            if !message.isFromMe { Spacer(minLength: 60) }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 消息内容视图（根据类型显示不同样式）
struct MessageContentView: View {
    let message: Message

    var body: some View {
        switch message.type {
        case .text:
            Text(message.content)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isFromMe ? Color.green : Color(UIColor.systemGray5))
                .foregroundColor(message.isFromMe ? .white : .primary)
                .cornerRadius(16)

        case .image:
            AsyncImageView(urlString: message.mediaURL ?? "")
                .frame(maxWidth: 200, maxHeight: 200)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )

        case .voice:
            VoiceMessageView(message: message)

        case .file:
            FileMessageView(message: message)

        case .video:
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.system(size: 24))
                Text("[视频]")
                    .font(.system(size: 14))
            }
            .padding(12)
            .background(message.isFromMe ? Color.green : Color(UIColor.systemGray5))
            .foregroundColor(message.isFromMe ? .white : .primary)
            .cornerRadius(12)

        case .system:
            Text(message.content)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// MARK: - 语音消息视图
struct VoiceMessageView: View {
    let message: Message
    @State private var isPlaying = false

    var body: some View {
        Button(action: playVoice) {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(message.isFromMe ? .white : .green)

                // 声波动画
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(message.isFromMe ? Color.white.opacity(0.6) : Color.green.opacity(0.6))
                            .frame(width: 3, height: CGFloat.random(in: 8...20))
                    }
                }
                .frame(height: 24)

                if let duration = message.voiceDuration {
                    Text(String(format: "%.0f\"", duration))
                        .font(.system(size: 13))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(message.isFromMe ? Color.green : Color(UIColor.systemGray5))
            .foregroundColor(message.isFromMe ? .white : .primary)
            .cornerRadius(16)
        }
    }

    private func playVoice() {
        if isPlaying {
            AudioService.shared.stopPlaying()
            isPlaying = false
        } else {
            if let url = message.mediaURL {
                AudioService.shared.playVoiceFromURLString(url, messageID: message.id)
            }
            isPlaying = true
        }
    }
}

// MARK: - 文件消息视图
struct FileMessageView: View {
    let message: Message

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: fileIconName)
                .font(.system(size: 32))
                .foregroundColor(message.isFromMe ? .white : .blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.fileName ?? "未知文件")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                if let size = message.fileSize {
                    Text(size.fileSizeString)
                        .font(.system(size: 11))
                        .foregroundColor(message.isFromMe ? .white.opacity(0.8) : .gray)
                }
            }
        }
        .padding(12)
        .background(message.isFromMe ? Color.green : Color(UIColor.systemGray5))
        .foregroundColor(message.isFromMe ? .white : .primary)
        .cornerRadius(12)
    }

    private var fileIconName: String {
        guard let name = message.fileName?.lowercased() else { return "doc.fill" }
        if name.hasSuffix(".pdf") { return "doc.richtext.fill" }
        if name.hasSuffix(".doc") || name.hasSuffix(".docx") { return "doc.fill" }
        if name.hasSuffix(".xls") || name.hasSuffix(".xlsx") { return "tablecells.fill" }
        if name.hasSuffix(".ppt") || name.hasSuffix(".pptx") { return "presentation.fill" }
        if name.hasSuffix(".zip") || name.hasSuffix(".rar") { return "archivebox.fill" }
        return "doc.fill"
    }
}

// MARK: - 异步图片视图
struct AsyncImageView: View {
    let urlString: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        let baseURL = WebSocketManager.shared.serverURL.replacingOccurrences(of: "/ws", with: "")
        let fullURL = urlString.hasPrefix("http") ? urlString : "\(baseURL)\(urlString)"

        guard let url = URL(string: fullURL) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = img
                }
            }
        }.resume()
    }
}
