import SwiftUI

// MARK: - 媒体查看器（图片全屏查看）
struct MediaViewerView: View {
    let urlString: String
    let type: MessageType
    @Environment(\.presentationMode) var presentationMode
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var isLoading = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .foregroundColor(.white)
                }

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    lastScale = scale
                                    if scale < 1 { scale = 1; lastScale = 1 }
                                    if scale > 5 { scale = 5; lastScale = 5 }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = value.translation
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        offset = .zero
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1 {
                                    scale = 1
                                    lastScale = 1
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                } else if !isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("图片加载失败")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .onAppear { loadImage() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private func loadImage() {
        let baseURL = WebSocketManager.shared.serverURL.replacingOccurrences(of: "/ws", with: "")
        let fullURL = urlString.hasPrefix("http") ? urlString : "\(baseURL)\(urlString)"

        guard let url = URL(string: fullURL) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = img
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
}
