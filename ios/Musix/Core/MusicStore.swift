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

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var likedIds: Set<String> = []
    @Published private(set) var recentIds: [String] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var isSyncing = false
    /// Catalogue revision last applied from the server (for OTA delta sync).
    @Published private(set) var catalogRevision = 0
    @Published private(set) var lastSyncedAt: Date?

    private let likedKey = "musix.liked.v1"
    private let recentKey = "musix.recent.v1"
    private let playlistKey = "musix.playlists.v1"
    private let catalogKey = "musix.catalog.v2"
    private let revisionKey = "musix.catalog.revision.v2"
    private let syncedKey = "musix.catalog.synced.v2"

    init() {
        load()
    }

    // MARK: - Catalogue (over-the-air)

    var isEmpty: Bool { tracks.isEmpty }

    /// Pulls the catalogue from the API. The first call downloads everything;
    /// later calls send the revision we already have and only receive changes,
    /// so new music appears without shipping a new build.
    @MainActor
    func loadCatalog(force: Bool = false) async {
        if isSyncing { return }
        if !force, let last = lastSyncedAt, Date().timeIntervalSince(last) < 45 { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let query = catalogRevision > 0 ? ["since": String(catalogRevision)] : [:]
            let response: CatalogResponse = try await APIClient.shared.get("/v1/catalog", query: query)

            if response.unchanged == true {
                lastSyncedAt = Date()
                saveCatalog()
                return
            }

            apply(response)
            lastSyncedAt = Date()
            saveCatalog()
        } catch {
            // Offline or no backend configured: keep the cached catalogue.
        }
    }

    private func apply(_ response: CatalogResponse) {
        let removed = Set(response.removed ?? [])
        let incoming = response.tracks
        let isFull = response.full ?? (response.revision == nil)

        if isFull {
            tracks = incoming
        } else {
            var order = tracks.map(\.id).filter { !removed.contains($0) }
            var byId: [String: Track] = [:]
            for track in tracks { byId[track.id] = track }

            for id in removed { byId.removeValue(forKey: id) }

            for track in incoming {
                if byId[track.id] == nil { order.append(track.id) }
                byId[track.id] = track
            }

            tracks = order.compactMap { byId[$0] }
        }

        if let revision = response.revision { catalogRevision = revision }
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
            playlists = []
        }

        if let data = defaults.data(forKey: catalogKey),
           let decoded = try? JSONDecoder().decode([Track].self, from: data) {
            tracks = decoded
        }

        catalogRevision = defaults.integer(forKey: revisionKey)
        lastSyncedAt = defaults.object(forKey: syncedKey) as? Date
    }

    private func saveCatalog() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(tracks) {
            defaults.set(data, forKey: catalogKey)
        }
        defaults.set(catalogRevision, forKey: revisionKey)
        defaults.set(lastSyncedAt ?? Date.distantPast, forKey: syncedKey)
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
