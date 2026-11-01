import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var music: MusicStore
    @EnvironmentObject private var player: PlayerEngine

    private enum Segment: String, CaseIterable {
        case liked = "Liked"
        case playlists = "Playlists"
        case recents = "Recent"
    }

    @State private var segment: Segment = .liked
    @State private var showCreate = false
    @State private var newPlaylistName = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                segments

                switch segment {
                case .liked:
                    likedSection
                case .playlists:
                    playlistSection
                case .recents:
                    recentsSection
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCreate) {
            createPlaylistSheet
                .presentationDetents([.height(280)])
                .presentationBackground(Theme.surface)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Library")
                    .font(Theme.display(30))
                    .tracking(-1.2)
                    .foregroundStyle(Theme.textPrimary)

                Text("\(music.likedTracks.count) liked · \(music.playlists.count) playlists")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                showCreate = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.lime)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
        }
        .pageGutter()
    }

    private var segments: some View {
        HStack(spacing: 8) {
            ForEach(Segment.allCases, id: \.self) { item in
                Chip(text: item.rawValue, selected: segment == item)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.18)) { segment = item }
                    }
            }
            Spacer()
        }
        .pageGutter()
    }

    // MARK: - Liked

    private var likedSection: some View {
        Group {
            if music.likedTracks.isEmpty {
                emptyState(icon: "heart",
                           title: "Nothing liked yet",
                           subtitle: "Tap the heart on any track and it lands here.")
            } else {
                VStack(spacing: 4) {
                    ForEach(music.likedTracks) { track in
                        TrackRow(track: track,
                                 isLiked: true,
                                 isActive: player.current?.id == track.id,
                                 showsLike: false,
                                 onTap: { player.play(track, queue: music.likedTracks) },
                                 onLike: { music.toggleLike(track) })
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface.opacity(0.45))
                )
                .pageGutter()
            }
        }
    }

    // MARK: - Playlists

    private var playlistSection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                  spacing: 18) {
            ForEach(music.playlists) { playlist in
                Button {
                    let tracks = music.tracks(in: playlist)
                    if let first = tracks.first { player.play(first, queue: tracks) }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        ArtworkView(palette: playlist.palette, corner: 20)
                            .frame(height: 150)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name)
                                .font(Theme.title(14))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text("\(playlist.trackIds.count) tracks")
                                .font(Theme.body(12))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
            }

            Button {
                showCreate = true
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .light))
                    Text("New playlist")
                        .font(Theme.title(13))
                }
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.surface.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                )
            }
            .buttonStyle(PressableStyle())
        }
        .pageGutter()
    }

    // MARK: - Recents

    private var recentsSection: some View {
        Group {
            if music.recentTracks.isEmpty {
                emptyState(icon: "clock",
                           title: "No history yet",
                           subtitle: "Play something and it shows up here.")
            } else {
                VStack(spacing: 4) {
                    ForEach(music.recentTracks) { track in
                        TrackRow(track: track,
                                 isLiked: music.isLiked(track.id),
                                 isActive: player.current?.id == track.id,
                                 onTap: { player.play(track, queue: music.recentTracks) },
                                 onLike: { music.toggleLike(track) })
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface.opacity(0.45))
                )
                .pageGutter()
            }
        }
    }

    // MARK: - Bits

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.textTertiary)

            Text(title)
                .font(Theme.title(16))
                .foregroundStyle(Theme.textPrimary)

            Text(subtitle)
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .pageGutter()
    }

    private var createPlaylistSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New playlist")
                .font(Theme.title(20))
                .foregroundStyle(Theme.textPrimary)

            MusixField(title: "Name", placeholder: "Late night drive", text: $newPlaylistName)

            PrimaryButton(title: "Create", systemImage: "plus") {
                music.createPlaylist(named: newPlaylistName)
                newPlaylistName = ""
                showCreate = false
            }

            Spacer(minLength: 0)
        }
        .padding(22)
    }
}
