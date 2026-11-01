import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var music: MusicStore
    @Environment(\.dismiss) private var dismiss

    @State private var dragFraction: Double?
    @State private var toast: String?

    private var track: Track? { player.current }

    var body: some View {
        ZStack {
            background

            if let track {
                VStack(spacing: 0) {
                    topBar(track: track)
                    Spacer(minLength: 8)
                    artwork(track: track)
                    Spacer(minLength: 18)
                    titleBlock(track: track)
                    scrubber
                    transport
                    Spacer(minLength: 12)
                    upNext
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            } else {
                Text("Nothing playing")
                    .font(Theme.title(16))
                    .foregroundStyle(Theme.textSecondary)
            }

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(Theme.title(13))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.lime))
                        .padding(.bottom, 36)
                        .transition(.opacity)
                }
            }
        }
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [Theme.violet.opacity(0.45), Color.clear],
                           center: .top,
                           startRadius: 20,
                           endRadius: 480)
            RadialGradient(colors: [Theme.pink.opacity(0.22), Color.clear],
                           center: .bottomTrailing,
                           startRadius: 20,
                           endRadius: 520)
        }
        .ignoresSafeArea()
    }

    // MARK: - Pieces

    private func topBar(track: Track) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("NOW PLAYING")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Menu {
                ForEach(music.playlists) { playlist in
                    Button {
                        music.add(track, to: playlist.id)
                        flash("Added to \(playlist.name)")
                    } label: {
                        Label(playlist.name, systemImage: "text.badge.plus")
                    }
                }
                Divider()
                Button {
                    music.toggleLike(track)
                } label: {
                    Label(music.isLiked(track.id) ? "Remove from Liked" : "Add to Liked",
                          systemImage: music.isLiked(track.id) ? "heart.slash" : "heart")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.top, 8)
    }

    private func artwork(track: Track) -> some View {
        AnimatedArtworkView(track: track, corner: 30, isLive: player.isPlaying)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 20)
            .scaleEffect(player.isPlaying ? 1 : 0.97)
            .animation(.easeInOut(duration: 0.35), value: player.isPlaying)
    }

    private func titleBlock(track: Track) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(Theme.display(24))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text("\(track.artist) · \(track.album)")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                music.toggleLike(track)
            } label: {
                Image(systemName: music.isLiked(track.id) ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(music.isLiked(track.id) ? Theme.pink : Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.surface.opacity(0.6)))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.bottom, 18)
    }

    private var scrubber: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let fraction = dragFraction ?? player.progress
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 5)

                    Capsule()
                        .fill(Theme.brandGradient)
                        .frame(width: max(4, geo.size.width * CGFloat(min(max(fraction, 0), 1))), height: 5)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .offset(x: geo.size.width * CGFloat(min(max(fraction, 0), 1)) - 7)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }
                .frame(height: 18)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragFraction = min(max(Double(value.location.x / geo.size.width), 0), 1)
                        }
                        .onEnded { value in
                            let target = min(max(Double(value.location.x / geo.size.width), 0), 1)
                            player.seek(to: target)
                            dragFraction = nil
                        }
                )
            }
            .frame(height: 18)

            HStack {
                Text(format(dragFraction.map { $0 * player.duration } ?? player.elapsed))
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                Text(format(player.duration))
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.bottom, 6)
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .buttonStyle(.plain)

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.brandGradient)
                        .frame(width: 74, height: 74)
                        .shadow(color: Theme.violet.opacity(0.45), radius: 18, y: 8)

                    if player.isBuffering {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.black)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(PressableStyle())

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    private var upNext: some View {
        VStack(alignment: .leading, spacing: 8) {
            if player.upNext.isEmpty {
                HStack {
                    Text("End of queue")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                }
                .frame(height: 44)
            } else {
                HStack {
                    Text("UP NEXT")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                    Text("\(player.upNext.count) in queue")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.textTertiary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(player.upNext.prefix(6)) { track in
                            Button {
                                player.play(track)
                            } label: {
                                HStack(spacing: 8) {
                                    ArtworkView(palette: track.palette, corner: 8, showsWaveform: false, coverUrl: track.coverUrl)
                                        .frame(width: 30, height: 30)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(track.title)
                                            .font(Theme.title(11))
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(Theme.body(10))
                                            .foregroundStyle(Theme.textTertiary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Theme.surface.opacity(0.7))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func flash(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeIn(duration: 0.3)) { toast = nil }
        }
    }
}

// MARK: - Mini player

struct MiniPlayerBar: View {
    @EnvironmentObject private var player: PlayerEngine
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ArtworkView(palette: player.current?.palette ?? 0, corner: 10, coverUrl: player.current?.coverUrl)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.current?.title ?? "")
                        .font(Theme.title(13))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    Text(player.current?.artist ?? "")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.06))
                    Rectangle()
                        .fill(Theme.brandGradient)
                        .frame(width: geo.size.width * CGFloat(player.progress))
                }
            }
            .frame(height: 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { isPresented = true }
    }
}
