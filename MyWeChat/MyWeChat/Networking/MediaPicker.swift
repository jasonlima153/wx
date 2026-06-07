import SwiftUI
import UniformTypeIdentifiers

struct MediaPicker: UIViewControllerRepresentable {
    let completion: (Result<MediaSelection, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .audio, .data], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<MediaSelection, Error>) -> Void
        init(completion: @escaping (Result<MediaSelection, Error>) -> Void) { self.completion = completion }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let kind: MediaSelection.Kind
            let mimeType: String
            let ext = url.pathExtension.lowercased()
            if ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "gif" || ext == "webp" {
                kind = .image
                mimeType = "image/jpeg"
            } else if ext == "m4a" || ext == "mp3" || ext == "wav" || ext == "aac" {
                kind = .voice
                mimeType = "audio/m4a"
            } else {
                kind = .file
                mimeType = "application/octet-stream"
            }
            let media = MediaSelection(url: url, fileName: url.lastPathComponent, mimeType: mimeType, kind: kind)
            completion(.success(media))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(.failure(NSError(domain: "picker", code: -1, userInfo: [NSLocalizedDescriptionKey: "已取消"])))
        }
    }
}
