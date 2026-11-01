import Foundation
import Combine

/// Catalogue, likes, playlists and recently played - persisted locally.
final class MusicStore: ObservableObject {

    static let shared = MusicStore()

    struct Playlist: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var trackIds: [String]
        var palette: Int
    }

    @Published private(set) var tracks: [Track] = DemoCatalog.tracks
    @Published private(set) var likedIds: Set<String> = []
    @Published private(set) var recentIds: [String] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var isSyncing = false

    private let likedKey = "musix.liked.v1"
    private let recentKey = "musix.recent.v1"
    private let playlistKey = "musix.playlists.v1"

    init() {
        load()
    }

    // MARK: - Catalogue

    @MainActor
    func loadCatalog() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let response: CatalogResponse = try await APIClient.shared.get("/v1/catalog")
            if !response.tracks.isEmpty {
                tracks = response.tracks
            }
        } catch {
            // Bundled demo catalogue stays in place when offline.
        }
    }

    func track(id: String) -> Track? {
        tracks.first { $0.id == id }
    }

    /// Catalog split into clean home-page shelves.
    var editorsPicks: [Track] { tracks.filter { $0.palette % 2 == 0 } }
    var lateNight: [Track] { tracks.filter { ["R&B", "Electronic", "Alt"].contains($0.genre) } }
    var fresh: [Track] { tracks.reversed() }

    func search(_ query: String) -> [Track] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return tracks.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            $0.album.lowercased().contains(q) ||
            $0.genre.lowercased().contains(q)
        }
    }

    // MARK: - Likes

    func isLiked(_ id: String) -> Bool { likedIds.contains(id) }

    func toggleLike(_ track: Track) {
        if likedIds.contains(track.id) {
            likedIds.remove(track.id)
        } else {
            likedIds.insert(track.id)
        }
        saveLikes()
    }

    var likedTracks: [Track] {
        tracks.filter { likedIds.contains($0.id) }
    }

    // MARK: - Recents

    func markPlayed(_ track: Track) {
        recentIds.removeAll { $0 == track.id }
        recentIds.insert(track.id, at: 0)
        if recentIds.count > 30 { recentIds = Array(recentIds.prefix(30)) }
        saveRecents()
    }

    var recentTracks: [Track] {
        recentIds.compactMap { id in tracks.first { $0.id == id } }
    }

    // MARK: - Playlists

    func createPlaylist(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let playlist = Playlist(id: UUID().uuidString,
                                name: trimmed,
                                trackIds: [],
                                palette: Int.random(in: 0..<8))
        playlists.append(playlist)
        savePlaylists()
    }

    func add(_ track: Track, to playlistId: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        guard !playlists[index].trackIds.contains(track.id) else { return }
        playlists[index].trackIds.append(track.id)
        savePlaylists()
    }

    func remove(_ track: Track, from playlistId: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        playlists[index].trackIds.removeAll { $0 == track.id }
        savePlaylists()
    }

    func tracks(in playlist: Playlist) -> [Track] {
        playlist.trackIds.compactMap { id in tracks.first { $0.id == id } }
    }

    // MARK: - Persistence

    private func load() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: likedKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            likedIds = Set(decoded)
        }

        if let data = defaults.data(forKey: recentKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            recentIds = decoded
        }

        if let data = defaults.data(forKey: playlistKey),
           let decoded = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = decoded
        } else {
            playlists = [
                Playlist(id: "p_late",
                         name: "Late Night Drive",
                         trackIds: ["t04", "t07", "t10", "t02"],
                         palette: 3),
                Playlist(id: "p_focus",
                         name: "Focus Window",
                         trackIds: ["t01", "t05", "t09", "t12"],
                         palette: 6)
            ]
        }
    }

    private func saveLikes() {
        UserDefaults.standard.set(try? JSONEncoder().encode(Array(likedIds)), forKey: likedKey)
    }

    private func saveRecents() {
        UserDefaults.standard.set(try? JSONEncoder().encode(recentIds), forKey: recentKey)
    }

    private func savePlaylists() {
        UserDefaults.standard.set(try? JSONEncoder().encode(playlists), forKey: playlistKey)
    }
}
