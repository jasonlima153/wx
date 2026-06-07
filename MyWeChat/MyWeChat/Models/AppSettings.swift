import SwiftUI

struct AppSettings: Codable {
    enum Appearance: String, Codable {
        case system, light, dark
        var index: Int { self == .light ? 1 : (self == .dark ? 2 : 0) }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    var serverBaseURL: String = "https://your-domain.com"
    var websocketURL: String = "wss://your-domain.com/ws"
    var authToken: String = ""
    var appearance: Appearance = .system
}
