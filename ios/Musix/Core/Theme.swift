import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Central design tokens. Musix is dark-first, high-contrast and ad-free by design.
enum Theme {

    // MARK: Surfaces
    static let background    = Color(hex: 0x07070B)
    static let surface       = Color(hex: 0x111118)
    static let surfaceRaised = Color(hex: 0x191922)
    static let stroke        = Color.white.opacity(0.08)
    static let strokeStrong  = Color.white.opacity(0.16)

    // MARK: Text
    static let textPrimary   = Color(hex: 0xF6F6FA)
    static let textSecondary = Color(hex: 0x8E8EA3)
    static let textTertiary  = Color(hex: 0x5C5C70)

    // MARK: Brand
    static let lime   = Color(hex: 0xB8FF3F)
    static let violet = Color(hex: 0x7C5CFF)
    static let pink   = Color(hex: 0xFF4D8D)
    static let cyan   = Color(hex: 0x4DE1FF)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [lime, cyan, violet],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    static var warmGradient: LinearGradient {
        LinearGradient(colors: [pink, violet],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    // MARK: Type ramp
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }

    static func configure() {
        #if canImport(UIKit)
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: UIColor(Theme.textPrimary)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.textPrimary)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        UITableView.appearance().backgroundColor = .clear
        #endif
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    init?(hexString: String) {
        var value = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let int = UInt32(value, radix: 16) else { return nil }
        self.init(hex: int)
    }
}

// MARK: - Reusable modifiers

struct CardStyle: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 18, radius: CGFloat = 24) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }

    /// Standard horizontal page gutter used across every screen.
    func pageGutter() -> some View {
        padding(.horizontal, 20)
    }

    func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }
}
