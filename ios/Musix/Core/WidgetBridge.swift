import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Publishes the current wrap + playback state to the widget's App Group container.
enum WidgetBridge {

    private static var lastSave = Date.distantPast
    private static var lastReload = Date.distantPast

    static func publish(force: Bool = false) {
        let now = Date()
        if !force, now.timeIntervalSince(lastSave) < 8 { return }
        lastSave = now

        let wrap = ListeningStore.shared.wrap()
        let player = PlayerEngine.shared

        let snapshot = MusixShared.Snapshot(
            minutes: wrap.minutes,
            streak: wrap.streak,
            trackCount: wrap.trackCount,
            topArtist: wrap.topArtist,
            topTrack: wrap.topTrack,
            topGenre: wrap.topGenre,
            hourly: wrap.hourly,
            updatedAt: now,
            isPlaying: player.isPlaying,
            nowTitle: player.current?.title,
            nowArtist: player.current?.artist,
            palette: player.current?.palette ?? 0
        )

        MusixShared.save(snapshot)

        #if canImport(WidgetKit)
        if force || now.timeIntervalSince(lastReload) > 30 {
            lastReload = now
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}
