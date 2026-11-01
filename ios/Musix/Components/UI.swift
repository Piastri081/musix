import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Artwork

/// Generated cover art. No image assets, no downloads, consistent look at any size.
struct ArtworkView: View {
    let palette: Int
    var corner: CGFloat = 14
    var showsWaveform: Bool = true

    private var colors: [Color] { CoverPalette.colors(for: palette) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

                RadialGradient(colors: [Color.white.opacity(0.30), Color.clear],
                               center: .topLeading,
                               startRadius: 0,
                               endRadius: geo.size.width * 0.95)

                if showsWaveform {
                    HStack(spacing: geo.size.width * 0.035) {
                        ForEach(0..<9, id: \.self) { index in
                            let factor = 0.28 + 0.72 * abs(sin(Double(palette + 1) * 1.7 + Double(index) * 0.85))
                            Capsule()
                                .fill(Color.white.opacity(0.30))
                                .frame(width: max(2, geo.size.width * 0.045),
                                       height: geo.size.height * 0.46 * factor)
                        }
                    }
                    .blendMode(.overlay)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    var title: String
    var systemImage: String? = nil
    var gradient: LinearGradient = Theme.brandGradient
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.black)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).font(Theme.title(16))
            }
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(gradient)
            )
        }
        .buttonStyle(PressableStyle())
        .disabled(isLoading)
        .opacity(isLoading ? 0.8 : 1)
    }
}

struct SecondaryButton: View {
    var title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(Theme.textPrimary)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).font(Theme.title(15))
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
        .disabled(isLoading)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Text field

struct MusixField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var isSecure: Bool = false
    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.textTertiary)

            focusedField
                .font(Theme.body(17))
                .foregroundStyle(Theme.textPrimary)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var focusedField: some View {
        if let focus {
            field.focused(focus)
        } else {
            field
        }
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.textTertiary))
        } else {
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.textTertiary))
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(Theme.title(13))
                    .foregroundStyle(Theme.lime)
            }
        }
    }
}

// MARK: - Track rows

struct TrackRow: View {
    let track: Track
    var isLiked: Bool = false
    var isActive: Bool = false
    var showsLike: Bool = true
    var onTap: () -> Void
    var onLike: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(palette: track.palette, corner: 12)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(Theme.title(15))
                    .foregroundStyle(isActive ? Theme.lime : Theme.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isActive {
                EqualizerBars(color: Theme.lime)
                    .frame(width: 18, height: 16)
            } else {
                Text(track.durationText)
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.textTertiary)
            }

            if showsLike {
                Button(action: onLike) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isLiked ? Theme.pink : Theme.textTertiary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct TrackCard: View {
    let track: Track
    var width: CGFloat = 150
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkView(palette: track.palette, corner: 18)
                .frame(width: width, height: width)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(Theme.title(14))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: width, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Small bits

struct EqualizerBars: View {
    var color: Color = Theme.lime
    @State private var phase: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 3, height: heights[index])
            }
        }
        .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: phase)
        .onAppear { phase.toggle() }
    }

    private var heights: [CGFloat] {
        phase ? [12, 16, 9, 14] : [6, 10, 15, 8]
    }
}

struct Chip: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.title(13))
            .foregroundStyle(selected ? Color.black : Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(selected ? Theme.lime : Theme.surfaceRaised)
            )
            .overlay(
                Capsule().strokeBorder(selected ? Color.clear : Theme.stroke, lineWidth: 1)
            )
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var accent: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.display(26))
                .foregroundStyle(accent)
            Text(label)
                .font(Theme.body(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}
