import Foundation
import Combine

/// Records listening seconds locally and derives the Daily Wrap.
/// Everything here is on-device: no analytics SDK, no ads, no tracking.
final class ListeningStore: ObservableObject {

    static let shared = ListeningStore()

    struct Event: Codable {
        var trackId: String
        var title: String
        var artist: String
        var genre: String
        var seconds: Double
        var date: Date
    }

    @Published private(set) var events: [Event] = []
    @Published private(set) var nowPlaying: Track?

    private let storageKey = "musix.listening.v1"
    private var ticks = 0

    init() {
        load()
    }

    // MARK: - Recording

    func begin(_ track: Track) {
        nowPlaying = track
        save()
    }

    func accumulate(seconds: Double) {
        guard let track = nowPlaying, seconds > 0 else { return }
        let now = Date()

        if let index = events.indices.last,
           events[index].trackId == track.id,
           now.timeIntervalSince(events[index].date) < 8 {
            events[index].seconds += seconds
            events[index].date = now
        } else {
            events.append(Event(trackId: track.id,
                                title: track.title,
                                artist: track.artist,
                                genre: track.genre,
                                seconds: seconds,
                                date: now))
        }

        ticks += 1
        if ticks % 20 == 0 { save() }
    }

    func flush() {
        save()
    }

    // MARK: - Daily Wrap

    func wrap(for date: Date = Date()) -> DailyWrap {
        let calendar = Calendar.current
        let dayEvents = events.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let totalSeconds = dayEvents.reduce(0) { $0 + $1.seconds }
        let minutes = Int(totalSeconds / 60)

        let topArtist = Self.topKey(dayEvents, key: \.artist)
        let topTrack = Self.topKey(dayEvents, key: \.title)
        let topGenre = Self.topKey(dayEvents, key: \.genre)

        var hourly = Array(repeating: 0.0, count: 24)
        for event in dayEvents {
            let hour = calendar.component(.hour, from: event.date)
            if hour >= 0 && hour < 24 { hourly[hour] += event.seconds }
        }

        return DailyWrap(id: DailyWrap.key(for: date),
                         date: date,
                         minutes: minutes,
                         trackCount: Set(dayEvents.map(\.trackId)).count,
                         topArtist: minutes > 0 ? topArtist : nil,
                         topTrack: minutes > 0 ? topTrack : nil,
                         topGenre: minutes > 0 ? topGenre : nil,
                         streak: streak(),
                         hourly: hourly)
    }

    func recentWraps(days: Int = 7) -> [DailyWrap] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return wrap(for: date)
        }
    }

    func streak() -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())

        if !hasListening(on: day, calendar: calendar) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var count = 0
        while count < 400, hasListening(on: day, calendar: calendar) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: - Helpers

    private func hasListening(on day: Date, calendar: Calendar) -> Bool {
        events.contains { calendar.isDate($0.date, inSameDayAs: day) && $0.seconds >= 30 }
    }

    private static func topKey(_ events: [Event], key: KeyPath<Event, String>) -> String? {
        var totals: [String: Double] = [:]
        for event in events { totals[event[keyPath: key], default: 0] += event.seconds }
        return totals.max { $0.value < $1.value }?.key
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Event].self, from: data) else { return }
        // Keep the payload small: last 60 days only.
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? .distantPast
        events = decoded.filter { $0.date >= cutoff }
    }

    private func save() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? .distantPast
        let trimmed = events.filter { $0.date >= cutoff }
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        WidgetBridge.publish()
    }
}
