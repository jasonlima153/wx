import Foundation

// MARK: - 媒体模型
struct MediaItem: Identifiable, Codable {
    let id: String
    var url: String
    var type: MessageType
    var fileName: String?
    var fileSize: Int64?
    var thumbnailURL: String?
    var voiceDuration: Double?
    var createdAt: Date

    init(id: String = UUID().uuidString,
         url: String,
         type: MessageType,
         fileName: String? = nil,
         fileSize: Int64? = nil,
         thumbnailURL: String? = nil,
         voiceDuration: Double? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.url = url
        self.type = type
        self.fileName = fileName
        self.fileSize = fileSize
        self.thumbnailURL = thumbnailURL
        self.voiceDuration = voiceDuration
        self.createdAt = createdAt
    }
}
