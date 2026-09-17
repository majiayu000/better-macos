import AppKit
import SwiftUI

enum BetterTheme {
    static let accent = Color(red: 0.95, green: 0.59, blue: 0.18)
    static let indigo = Color(red: 0.10, green: 0.12, blue: 0.27)
    static let blue = Color(red: 0.19, green: 0.47, blue: 0.92)

    static var canvas: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                indigo.opacity(0.035),
                accent.opacity(0.025)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BetterLogo: View {
    let image: NSImage
    let size: CGFloat

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct BetterStatusPill: View {
    let title: String
    let symbol: String
    var color: Color = BetterTheme.accent

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.18), lineWidth: 1))
    }
}
