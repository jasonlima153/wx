import SwiftUI

struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer(minLength: 48)
                bubble
            } else {
                bubble
                Spacer(minLength: 48)
            }
        }
    }

    @ViewBuilder
    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch message.type {
            case .text:
                Text(message.text ?? "")
                    .padding(12)
                    .background(message.isFromMe ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            case .image:
                if let url = message.mediaURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure:
                            Color.gray.opacity(0.2).overlay(Image(systemName: "photo"))
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 220, height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

            case .voice:
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                    Text(message.text ?? "语音消息")
                        .font(.subheadline)
                }
                .padding(12)
                .background(message.isFromMe ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            case .file:
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                    Text(message.text ?? "文件")
                        .font(.subheadline)
                }
                .padding(12)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}
