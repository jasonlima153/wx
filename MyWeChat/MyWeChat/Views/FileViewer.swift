import SwiftUI
import QuickLook

// MARK: - 文件查看器
struct FileViewerView: View {
    let urlString: String
    let fileName: String
    @Environment(\.presentationMode) var presentationMode
    @State private var localFileURL: URL?
    @State private var isDownloading = true
    @State private var downloadProgress: Double = 0
    @State private var showError = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isDownloading {
                    VStack(spacing: 16) {
                        ProgressView(value: downloadProgress)
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)

                        Text("下载中...")
                            .foregroundColor(.gray)

                        if downloadProgress > 0 {
                            Text(String(format: "%.0f%%", downloadProgress * 100))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } else if let fileURL = localFileURL {
                    // 文件信息
                    VStack(spacing: 16) {
                        fileIcon

                        Text(fileName)
                            .font(.headline)
                            .lineLimit(1)

                        if let size = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 {
                            Text((size as Int64).fileSizeString)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 40)

                    Spacer()

                    // 操作按钮
                    VStack(spacing: 12) {
                        Button(action: { openWithQLPreview(fileURL) }) {
                            HStack {
                                Image(systemName: "eye.fill")
                                Text("预览文件")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: { shareFile(fileURL) }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("分享文件")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("文件加载失败")
                            .foregroundColor(.gray)
                        Button("重试") {
                            downloadFile()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .onAppear { downloadFile() }
        .alert(isPresented: $showError) {
            Alert(title: Text("错误"), message: Text("文件下载失败"), dismissButton: .default(Text("确定")))
        }
    }

    @ViewBuilder
    private var fileIcon: some View {
        let ext = fileName.lowercased()
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(fileColor.opacity(0.15))
                .frame(width: 80, height: 80)

            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 32))
                    .foregroundColor(fileColor)
                Text(ext.split(separator: ".").last.map(String.init) ?? "文件")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(fileColor)
            }
        }
    }

    private var iconName: String {
        let ext = fileName.lowercased()
        if ext.hasSuffix(".pdf") { return "doc.richtext.fill" }
        if ext.hasSuffix(".doc") || ext.hasSuffix(".docx") { return "doc.fill" }
        if ext.hasSuffix(".xls") || ext.hasSuffix(".xlsx") { return "tablecells.fill" }
        if ext.hasSuffix(".ppt") || ext.hasSuffix(".pptx") { return "presentation.fill" }
        if ext.hasSuffix(".zip") || ext.hasSuffix(".rar") { return "archivebox.fill" }
        return "doc.fill"
    }

    private var fileColor: Color {
        let ext = fileName.lowercased()
        if ext.hasSuffix(".pdf") { return .red }
        if ext.hasSuffix(".doc") || ext.hasSuffix(".docx") { return .blue }
        if ext.hasSuffix(".xls") || ext.hasSuffix(".xlsx") { return .green }
        if ext.hasSuffix(".ppt") || ext.hasSuffix(".pptx") { return .orange }
        return .gray
    }

    // MARK: - 操作

    private func downloadFile() {
        isDownloading = true
        let baseURL = WebSocketManager.shared.serverURL.replacingOccurrences(of: "/ws", with: "")
        let fullURL = urlString.hasPrefix("http") ? urlString : "\(baseURL)\(urlString)"

        guard let url = URL(string: fullURL) else {
            showError = true
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let destination = tempDir.appendingPathComponent(fileName)

        URLSession.shared.downloadTask(with: url) { localURL, _, error in
            DispatchQueue.main.async {
                if let localURL = localURL {
                    try? FileManager.default.removeItem(at: destination)
                    try? FileManager.default.moveItem(at: localURL, to: destination)
                    self.localFileURL = destination
                    self.isDownloading = false
                } else {
                    self.showError = true
                    self.isDownloading = false
                }
            }
        }.resume()
    }

    private func openWithQLPreview(_ url: URL) {
        let qlPreview = QLPreviewController()
        qlPreview.dataSource = PreviewItemProvider(fileURL: url)
        // 需要通过 UIHostingController 来呈现
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(qlPreview, animated: true)
        }
    }

    private func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - QLPreview 数据源
class PreviewItemProvider: NSObject, QLPreviewControllerDataSource {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return fileURL as QLPreviewItem
    }
}
