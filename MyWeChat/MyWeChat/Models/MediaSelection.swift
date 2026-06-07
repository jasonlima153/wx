import Foundation

struct MediaSelection {
    enum Kind { case image, voice, file }
    let url: URL
    let fileName: String
    let mimeType: String
    let kind: Kind
}
