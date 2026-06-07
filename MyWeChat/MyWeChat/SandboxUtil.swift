import Foundation
import UIKit

struct SandboxUtil {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var imageMessagesDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("ImageMessages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func saveImageToSandbox(data: Data) -> String? {
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = imageMessagesDirectory.appendingPathComponent(fileName)

        do {
            guard let image = UIImage(data: data),
                  let compressedData = image.jpegData(compressionQuality: 0.7) else { return nil }

            try compressedData.write(to: fileURL)
            print("✅ 图片已保存到沙盒: \(fileURL.path)")
            return "ImageMessages/\(fileName)"
        } catch {
            print("❌ 保存图片失败: \(error)")
            return nil
        }
    }

    static func loadImageFromSandbox(relativePath: String) -> UIImage? {
        let fileURL = documentsDirectory.appendingPathComponent(relativePath)
        return UIImage(contentsOfFile: fileURL.path)
    }
}
