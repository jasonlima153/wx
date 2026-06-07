import SwiftUI

struct ErrorBanner: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.85))
            .clipShape(Capsule())
            .shadow(radius: 6)
    }
}

struct AvatarCircle: View {
    let text: String
    var initials: String {
        let chars = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(chars.prefix(1)).uppercased()
    }
    var body: some View {
        ZStack {
            Circle().fill(Color.blue.opacity(0.15))
            Text(initials).font(.headline)
        }
        .frame(width: 40, height: 40)
    }
}
