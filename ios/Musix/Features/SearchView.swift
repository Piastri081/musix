import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var music: MusicStore
    @EnvironmentObject private var player: PlayerEngine

    @State private var query = ""
    @State private var genre: String?
    @FocusState private var focused: Bool

    private let genres = ["Electronic", "R&B", "Indie", "Hip-Hop", "Pop", "Alt"]

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var results: [Track] {
        if let genre, !isSearching {
            return music.tracks.filter { $0.genre == genre }
        }
        return music.search(query)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Search")
                    .font(Theme.display(30))
                    .tracking(-1.2)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 6)
                    .pageGutter()

                searchBar
                    .pageGutter()

                if isSearching {
                    if results.isEmpty {
                        emptyState
                    } else {
                        trackList(title: "Results", tracks: results)
                    }
                } else {
                    genreGrid

                    if music.isEmpty {
                        EmptyCatalogCard(isSyncing: music.isSyncing) {
                            Task { await music.loadCatalog(force: true) }
                        }
                        .pageGutter()
                    } else {
                        trackList(title: "Trending on Musix", tracks: Array(music.tracks.prefix(6)))
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            await music.loadCatalog(force: true)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSearching ? Theme.lime : Theme.textTertiary)

            TextField("Songs, artists, moods", text: $query)
                .font(Theme.body(16))
                .foregroundStyle(Theme.textPrimary)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            if isSearching {
                Button {
                    query = ""
                    focused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(focused ? Theme.lime.opacity(0.5) : Theme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Genres

    private var genreGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Browse", subtitle: "Every mood has a lane")
                .pageGutter()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(Array(genres.enumerated()), id: \.element) { index, name in
                    Button {
                        genre = name
                        query = ""
                        focused = false
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            ArtworkView(palette: index + 1, corner: 18, showsWaveform: false)
                            LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                           startPoint: .top,
                                           endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            Text(name)
                                .font(Theme.title(16))
                                .foregroundStyle(.white)
                                .padding(12)
                        }
                        .frame(height: 88)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .pageGutter()
        }
    }

    // MARK: - Results

    private func trackList(title: String, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(Theme.title(18))
                    .foregroundStyle(Theme.textPrimary)

                if genre != nil && !isSearching {
                    Chip(text: genre ?? "", selected: true)
                        .onTapGesture { genre = nil }
                }

                Spacer()

                if !tracks.isEmpty {
                    Button("Play all") {
                        if let first = tracks.first { player.play(first, queue: tracks) }
                    }
                    .font(Theme.title(13))
                    .foregroundStyle(Theme.lime)
                }
            }
            .pageGutter()

            VStack(spacing: 4) {
                ForEach(tracks) { track in
                    TrackRow(track: track,
                             isLiked: music.isLiked(track.id),
                             isActive: player.current?.id == track.id,
                             onTap: { player.play(track, queue: tracks) },
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.textTertiary)

            Text("Nothing matched \"\(query)\"")
                .font(Theme.title(15))
                .foregroundStyle(Theme.textPrimary)

            Text("Try an artist, a genre, or a mood.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .pageGutter()
    }
}
