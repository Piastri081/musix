import Foundation

/// Data shared between the app and the widget extension.
/// Keep this file free of UIKit/SwiftUI so both targets can compile it.
enum MusixShared {

    static let appGroup = "group.app.musix.ios"
    static let wrapKey = "musix.widget.wrap"

    struct Snapshot: Codable {
        var minutes: Int
        var streak: Int
        var trackCount: Int
        var topArtist: String?
        var topTrack: String?
        var topGenre: String?
        var hourly: [Double]
        var updatedAt: Date
        var isPlaying: Bool
        var nowTitle: String?
        var nowArtist: String?
        var palette: Int
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func save(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: wrapKey)
    }

    static func load() -> Snapshot? {
        guard let data = defaults?.data(forKey: wrapKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}

extension MusixShared.Snapshot {
    static let preview = MusixShared.Snapshot(
        minutes: 74,
        streak: 6,
        trackCount: 18,
        topArtist: "Vale",
        topTrack: "Neon Tide",
        topGenre: "Electronic",
        hourly: [0, 0, 0, 0, 0, 0, 2, 6, 12, 20, 16, 9, 14, 22, 30, 26, 18, 24, 34, 28, 20, 12, 6, 2],
        updatedAt: Date(),
        isPlaying: true,
        nowTitle: "Neon Tide",
        nowArtist: "Vale",
        palette: 0
    )
}
