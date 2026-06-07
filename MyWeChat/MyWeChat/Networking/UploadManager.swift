import Foundation
import UIKit
import MobileCoreServices

// MARK: - 文件/图片/语音上传管理
class UploadManager {
    static let shared = UploadManager()

    private var baseURL: String {
        WebSocketManager.shared.serverURL.replacingOccurrences(of: "/ws", with: "")
    }

    // MARK: - 图片上传

    func uploadImage(_ image: UIImage, to receiver: String,
                     completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(nil)
            return
        }

        let boundary = UUID().uuidString
        let fullURL = URL(string: "\(baseURL)/api/upload")!

        var request = URLRequest(url: fullURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let accountID = WebSocketManager.shared.currentAccountID

        // msg_type 字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"msg_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("image\r\n".data(using: .utf8)!)

        // account_id 字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"account_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(accountID)\r\n".data(using: .utf8)!)

        // 文件字段
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        performUpload(request: request, body: body, to: receiver, type: .image, completion: completion)
    }

    // MARK: - 语音上传

    func uploadVoice(_ voiceData: Data, duration: Double, to receiver: String,
                     completion: @escaping (String?) -> Void) {
        let boundary = UUID().uuidString
        let fullURL = URL(string: "\(baseURL)/api/upload")!

        var request = URLRequest(url: fullURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let accountID = WebSocketManager.shared.currentAccountID

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"msg_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("voice\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"account_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(accountID)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"voice.aac\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/aac\r\n\r\n".data(using: .utf8)!)
        body.append(voiceData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        performUpload(request: request, body: body, to: receiver, type: .voice,
                      voiceDuration: duration, completion: completion)
    }

    // MARK: - 文件上传

    func uploadFile(at fileURL: URL, to receiver: String,
                    completion: @escaping (String?) -> Void) {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(nil)
            return
        }

        let boundary = UUID().uuidString
        let fullURL = URL(string: "\(baseURL)/api/upload")!

        var request = URLRequest(url: fullURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let accountID = WebSocketManager.shared.currentAccountID
        let fileName = fileURL.lastPathComponent

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"msg_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("file\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"account_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(accountID)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        performUpload(request: request, body: body, to: receiver, type: .file,
                      fileName: fileName, fileSize: Int64(fileData.count), completion: completion)
    }

    // MARK: - 通用上传执行

    private func performUpload(request: URLRequest, body: Data, to receiver: String,
                                type: MessageType, fileName: String? = nil,
                                fileSize: Int64? = nil, voiceDuration: Double? = nil,
                                completion: @escaping (String?) -> Void) {
        request.httpBody = body

        let task = URLSession.shared.uploadTask(with: request, from: body) { data, _, error in
            if let error = error {
                print("❌ 上传失败: \(error)")
                completion(nil)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let mediaURL = json["media_url"] as? String else {
                completion(nil)
                return
            }

            // 上传成功后通过 WebSocket 发送消息
            let ws = WebSocketManager.shared
            let displayContent: String
            switch type {
            case .image:
                displayContent = "[图片]"
            case .voice:
                displayContent = "[语音]"
            case .file:
                displayContent = "[文件] \(fileName ?? "")"
            default:
                displayContent = ""
            }

            ws.sendMessage(
                content: displayContent,
                to: receiver,
                type: type,
                mediaURL: mediaURL,
                fileName: fileName,
                fileSize: fileSize,
                voiceDuration: voiceDuration
            )

            completion(mediaURL)
        }
        task.resume()
    }
}
