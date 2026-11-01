import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Palette

enum CoverPalette {
    static let pairs: [[Color]] = [
        [Color(hex: 0x7C5CFF), Color(hex: 0xFF4D8D)],
        [Color(hex: 0x4DE1FF), Color(hex: 0x7C5CFF)],
        [Color(hex: 0xB8FF3F), Color(hex: 0x1FA97A)],
        [Color(hex: 0xFF8A3D), Color(hex: 0xFF4D8D)],
        [Color(hex: 0xFFD23D), Color(hex: 0xFF8A3D)],
        [Color(hex: 0x7C5CFF), Color(hex: 0x4DE1FF)],
        [Color(hex: 0x2DE2A6), Color(hex: 0x4DE1FF)],
        [Color(hex: 0xFF4D8D), Color(hex: 0x7C5CFF)]
    ]

    static func colors(for palette: Int) -> [Color] {
        pairs[abs(palette) % pairs.count]
    }
}

// MARK: - Animated artwork

/// Cover art that moves. Uses a looping video when a track supplies one,
/// otherwise a generated "living gradient" that reacts to playback.
struct AnimatedArtworkView: View {
    let track: Track?
    var corner: CGFloat = 26
    var isLive: Bool = true

    private var hasVideo: Bool {
        guard let raw = track?.videoUrl, let url = URL(string: raw) else { return false }
        return url.scheme == "https" || url.scheme == "http"
    }

    private var coverURL: URL? {
        guard let raw = track?.coverUrl, let url = URL(string: raw) else { return nil }
        guard url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }

    var body: some View {
        ZStack {
            if hasVideo, let raw = track?.videoUrl, let url = URL(string: raw) {
                LoopingVideoView(url: url)
                    .overlay(
                        LinearGradient(colors: [Color.black.opacity(0.15), Color.clear, Color.black.opacity(0.25)],
                                       startPoint: .top,
                                       endPoint: .bottom)
                    )
            } else if let coverURL {
                GeometryReader { geo in
                    AsyncImage(url: coverURL) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        } else {
                            ProceduralArtwork(palette: track?.palette ?? 0, isLive: isLive)
                        }
                    }
                }
            } else {
                ProceduralArtwork(palette: track?.palette ?? 0, isLive: isLive)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

/// A generated cover that breathes: slow drifting light blobs plus a pulsing waveform.
struct ProceduralArtwork: View {
    let palette: Int
    var isLive: Bool = true

    private var colors: [Color] { CoverPalette.colors(for: palette) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isLive)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                context.addFilter(.blur(radius: size.width * 0.16))

                let blobs: [(speed: Double, radius: Double, offset: Double, color: Color, alpha: Double)] = [
                    (0.24, 0.46, 0.0, colors[0], 0.85),
                    (0.19, 0.42, 2.1, colors[1], 0.75),
                    (0.31, 0.34, 4.2, Color.white, 0.28)
                ]

                for blob in blobs {
                    let phase = time * blob.speed + blob.offset
                    let x = size.width * (0.5 + 0.30 * sin(phase))
                    let y = size.height * (0.5 + 0.30 * cos(phase * 0.82 + 1.1))
                    let radius = size.width * blob.radius
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(blob.color.opacity(blob.alpha)))
                }
            }
            .overlay(waveform(time: time))
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
    }

    private func waveform(time: Double) -> some View {
        GeometryReader { geo in
            HStack(spacing: geo.size.width * 0.035) {
                ForEach(0..<9, id: \.self) { index in
                    let base = 0.3 + 0.55 * abs(sin(Double(palette + 1) * 1.34 + Double(index) * 0.9))
                    let pulse = isLive ? 0.18 * abs(sin(time * 1.7 + Double(index) * 0.7)) : 0
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: max(2, geo.size.width * 0.045),
                               height: geo.size.height * 0.46 * (base + pulse))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .blendMode(.overlay)
        }
    }
}

// MARK: - Looping video artwork

#if canImport(UIKit)

final class LoopingVideoUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// Plays a muted, looping video as album artwork (the "animated cover" format).
struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> LoopingVideoUIView {
        let view = LoopingVideoUIView()
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspectFill

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none
        view.playerLayer.player = player
        player.play()

        context.coordinator.player = player
        context.coordinator.observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        return view
    }

    func updateUIView(_ uiView: LoopingVideoUIView, context: Context) {}

    static func dismantleUIView(_ uiView: LoopingVideoUIView, coordinator: Coordinator) {
        coordinator.player?.pause()
        if let observer = coordinator.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    final class Coordinator {
        var player: AVPlayer?
        var observer: NSObjectProtocol?
    }
}

#endif

// MARK: - Static cover (lock screen + sharing)

/// Renders a still cover image with Core Graphics only.
///
/// Deliberately avoids SwiftUI (`ImageRenderer`) so it can be called from any
/// thread and from `MPNowPlayingInfoCenter` without actor-isolation hops.
enum CoverRenderer {

    /// Mirrors `CoverPalette.pairs` without touching SwiftUI colours.
    private static let pairs: [(start: UInt32, end: UInt32)] = [
        (0x7C5CFF, 0xFF4D8D),
        (0x4DE1FF, 0x7C5CFF),
        (0xB8FF3F, 0x1FA97A),
        (0xFF8A3D, 0xFF4D8D),
        (0xFFD23D, 0xFF8A3D),
        (0x7C5CFF, 0x4DE1FF),
        (0x2DE2A6, 0x4DE1FF),
        (0xFF4D8D, 0x7C5CFF)
    ]

    /// `NSCache` is thread-safe, so concurrent artwork requests are fine.
    private static let cache = NSCache<NSNumber, UIImage>()

    static func image(palette: Int, size: CGFloat = 900) -> UIImage? {
        let key = NSNumber(value: palette)
        if let cached = cache.object(forKey: key) { return cached }

        let side = max(64, Int(size.rounded()))
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side))
        let pair = pairs[abs(palette) % pairs.count]
        let start = color(pair.start, alpha: 1)
        let end = color(pair.end, alpha: 1)

        drawLinearGradient(context, rect: rect, colors: [start, end])
        drawGlow(context, rect: rect, center: CGPoint(x: rect.width * 0.32, y: rect.height * 0.30),
                 radius: rect.width * 0.52, color: color(pair.start, alpha: 0.85))
        drawGlow(context, rect: rect, center: CGPoint(x: rect.width * 0.72, y: rect.height * 0.74),
                 radius: rect.width * 0.46, color: color(pair.end, alpha: 0.80))
        drawGlow(context, rect: rect, center: CGPoint(x: rect.width * 0.54, y: rect.height * 0.44),
                 radius: rect.width * 0.30, color: color(0xFFFFFF, alpha: 0.22))
        drawWaveform(context, rect: rect, palette: palette)

        guard let cgImage = context.makeImage() else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }

    // MARK: Drawing

    private static func color(_ hex: UInt32, alpha: CGFloat) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    private static func drawLinearGradient(_ context: CGContext,
                                           rect: CGRect,
                                           colors: [CGColor]) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: colors as CFArray,
                                        locations: [0, 1]) else { return }
        context.saveGState()
        context.addRect(rect)
        context.clip()
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: rect.minX, y: rect.maxY),
                                   end: CGPoint(x: rect.maxX, y: rect.minY),
                                   options: [])
        context.restoreGState()
    }

    private static func drawGlow(_ context: CGContext,
                                 rect: CGRect,
                                 center: CGPoint,
                                 radius: CGFloat,
                                 color: CGColor) {
        let clear = color.copy(alpha: 0) ?? color
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [color, clear] as CFArray,
                                        locations: [0, 1]) else { return }
        context.saveGState()
        context.addRect(rect)
        context.clip()
        context.drawRadialGradient(gradient,
                                   startCenter: center,
                                   startRadius: 0,
                                   endCenter: center,
                                   endRadius: radius,
                                   options: [])
        context.restoreGState()
    }

    private static func drawWaveform(_ context: CGContext, rect: CGRect, palette: Int) {
        let scale = rect.width / 900
        let bars = 9
        let barWidth = 34 * scale
        let spacing = 30 * scale
        let maxHeight = 380 * scale
        let totalWidth = CGFloat(bars) * barWidth + CGFloat(bars - 1) * spacing
        var x = rect.midX - totalWidth / 2

        context.saveGState()
        context.setBlendMode(.overlay)
        context.setFillColor(color(0xFFFFFF, alpha: 0.32))

        for index in 0..<bars {
            let factor = 0.3 + 0.55 * abs(sin(Double(palette + 1) * 1.34 + Double(index) * 0.9))
            let height = max(barWidth, maxHeight * CGFloat(factor))
            let frame = CGRect(x: x, y: rect.midY - height / 2, width: barWidth, height: height)
            let path = CGPath(roundedRect: frame,
                              cornerWidth: barWidth / 2,
                              cornerHeight: barWidth / 2,
                              transform: nil)
            context.addPath(path)
            context.fillPath()
            x += barWidth + spacing
        }

        context.restoreGState()
    }
}

// MARK: - Remote artwork (lock screen)

/// Tiny image cache so the lock-screen card can show real cover art without
/// blocking playback. Generated artwork stays as the fallback.
enum RemoteArtwork {
    private static let cache = NSCache<NSString, UIImage>()

    static func cached(_ urlString: String) -> UIImage? {
        cache.object(forKey: urlString as NSString)
    }

    static func load(_ urlString: String, completion: @escaping (UIImage?) -> Void) {
        if let image = cached(urlString) {
            completion(image)
            return
        }

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            let image = data.flatMap { UIImage(data: $0) }
            if let image {
                cache.setObject(image, forKey: urlString as NSString)
            }
            DispatchQueue.main.async { completion(image) }
        }.resume()
    }
}
