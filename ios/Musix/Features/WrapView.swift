import SwiftUI
import UIKit

struct WrapView: View {
    @EnvironmentObject private var listening: ListeningStore
    @EnvironmentObject private var music: MusicStore
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var session: Session

    @State private var shareImage: Image?

    private var wrap: DailyWrap { listening.wrap() }
    private var history: [DailyWrap] { listening.recentWraps(days: 7) }

    private var peakHour: Int {
        guard let maxValue = wrap.hourly.max(), maxValue > 0 else { return 0 }
        return wrap.hourly.firstIndex(of: maxValue) ?? 0
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                if wrap.minutes == 0 {
                    emptyState
                } else {
                    ringCard
                    statsGrid
                    topArtistCard
                    if let topTrack = wrap.topTrack.flatMap({ title in
                        listening.events.last(where: { $0.title == title })
                    }) {
                        topTrackCard(event: topTrack)
                    }
                    hourlyCard
                }

                weekCard
                actions
                footnote
            }
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { renderShareImage() }
        .onChange(of: wrap.minutes) { _, _ in renderShareImage() }
        .onChange(of: wrap.id) { _, _ in renderShareImage() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Daily Wrap")
                    .font(Theme.display(30))
                    .tracking(-1.2)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Text(DateFormatter.wrapDay.string(from: wrap.date).uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.surface))
            }

            Text("A snapshot of today, made on your device.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .pageGutter()
    }

    // MARK: - Ring

    private var ringCard: some View {
        let progress = min(1.0, Double(wrap.minutes) / 60.0)

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 14)

            Circle()
                .trim(from: 0, to: CGFloat(max(0.004, progress)))
                .stroke(Theme.brandGradient,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)

            VStack(spacing: 2) {
                Text("\(wrap.minutes)")
                    .font(Theme.display(56))
                    .tracking(-2)
                    .foregroundStyle(Theme.textPrimary)
                Text("minutes")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textSecondary)
                Text(wrap.headline)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 26)
        }
        .frame(width: 210, height: 210)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            StatTile(value: "\(wrap.trackCount)", label: "tracks played", accent: Theme.lime)
            StatTile(value: "\(wrap.streak)", label: "day streak", accent: Theme.cyan)
            StatTile(value: wrap.topGenre ?? "—", label: "top genre", accent: Theme.pink)
            StatTile(value: hourLabel(peakHour), label: "peak hour", accent: Theme.violet)
        }
        .pageGutter()
    }

    private var topArtistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ARTIST OF THE DAY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)

            Text(wrap.topArtist ?? "Unknown")
                .font(Theme.display(28))
                .tracking(-1)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                Text("You played them the most today")
                    .font(Theme.body(12))
            }
            .foregroundStyle(Theme.lime.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .pageGutter()
    }

    private func topTrackCard(event: ListeningStore.Event) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRACK OF THE DAY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 12) {
                ArtworkView(palette: palette(for: event.trackId), corner: 14)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(Theme.title(16))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(event.artist)
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    if let track = music.tracks.first(where: { $0.id == event.trackId }) {
                        player.play(track)
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Theme.lime))
                }
                .buttonStyle(PressableStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .pageGutter()
    }

    private var hourlyCard: some View {
        let peak = max(wrap.hourly.max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("LISTENING RHYTHM")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("12am → 12am")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(hour == peakHour
                              ? AnyShapeStyle(Theme.lime)
                              : AnyShapeStyle(Color.white.opacity(0.14)))
                        .frame(height: max(4, CGFloat(wrap.hourly[hour] / peak) * 56))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 60, alignment: .bottom)

            HStack {
                Text("6am").font(Theme.body(10)).foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("12pm").font(Theme.body(10)).foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("6pm").font(Theme.body(10)).foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("12am").font(Theme.body(10)).foregroundStyle(Theme.textTertiary)
            }
        }
        .card()
        .pageGutter()
    }

    // MARK: - Week

    private var weekCard: some View {
        let peak = max(history.map(\.minutes).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "This week", subtitle: "Minutes per day")

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(history) { day in
                    VStack(spacing: 8) {
                        Text("\(day.minutes)")
                            .font(Theme.mono(10))
                            .foregroundStyle(day.id == wrap.id ? Theme.lime : Theme.textTertiary)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(day.id == wrap.id
                                  ? AnyShapeStyle(Theme.brandGradient)
                                  : AnyShapeStyle(Theme.surfaceRaised))
                            .frame(height: max(6, CGFloat(day.minutes) / CGFloat(peak) * 86))

                        Text(DateFormatter.weekday.string(from: day.date).prefix(1))
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 128, alignment: .bottom)
        }
        .card()
        .pageGutter()
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if let shareImage {
                ShareLink(item: shareImage,
                          preview: SharePreview("My Musix Daily Wrap", image: shareImage)) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share my wrap")
                    }
                    .font(Theme.title(16))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.brandGradient)
                    )
                }
                .buttonStyle(PressableStyle())
            }

            SecondaryButton(title: "Play today's soundtrack", systemImage: "play.fill") {
                let tracks = todayTracks()
                if let first = tracks.first {
                    player.play(first, queue: tracks)
                }
            }
        }
        .pageGutter()
    }

    private var footnote: some View {
        Text("Wraps are computed on-device from your playback. Nothing is uploaded.")
            .font(Theme.body(11))
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .pageGutter()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.lime)

            Text("Today is still quiet")
                .font(Theme.title(18))
                .foregroundStyle(Theme.textPrimary)

            Text("Play a few tracks and your wrap builds itself — top artist, rhythm, streak, all of it.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "Start listening", systemImage: "play.fill") {
                if let first = music.editorsPicks.first {
                    player.play(first, queue: music.editorsPicks)
                }
            }
            .padding(.top, 4)
        }
        .card(padding: 24)
        .pageGutter()
    }

    // MARK: - Helpers

    private func todayTracks() -> [Track] {
        let ids = listening.events
            .filter { Calendar.current.isDateInToday($0.date) }
            .map(\.trackId)
        var seen = Set<String>()
        let ordered = ids.filter { seen.insert($0).inserted }
        let tracks = ordered.compactMap { id in music.tracks.first { $0.id == id } }
        return tracks.isEmpty ? music.editorsPicks : tracks
    }

    private func palette(for trackId: String) -> Int {
        music.tracks.first { $0.id == trackId }?.palette ?? 0
    }

    private func hourLabel(_ hour: Int) -> String {
        let suffix = hour < 12 ? "am" : "pm"
        var display = hour % 12
        if display == 0 { display = 12 }
        return "\(display)\(suffix)"
    }

    @MainActor
    private func renderShareImage() {
        let renderer = ImageRenderer(content: WrapShareCard(wrap: wrap, name: session.greetingName))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 380, height: 540)
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}

// MARK: - Share card

struct WrapShareCard: View {
    let wrap: DailyWrap
    let name: String

    var body: some View {
        ZStack {
            Theme.background
            LinearGradient(colors: [Theme.violet.opacity(0.55), Theme.pink.opacity(0.35), Theme.background],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { index in
                            Capsule()
                                .fill(index == 2 ? Theme.lime : Color.white)
                                .frame(width: 3, height: [7, 12, 17, 10, 6][index])
                        }
                    }
                    .frame(height: 18)

                    Text("musix")
                        .font(Theme.display(16))
                        .foregroundStyle(Color.white)

                    Spacer()

                    Text(DateFormatter.wrapDay.string(from: wrap.date).uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.white.opacity(0.7))
                }

                Spacer(minLength: 20)

                Text("\(name)'s day")
                    .font(Theme.body(13))
                    .foregroundStyle(Color.white.opacity(0.65))

                Text("Daily Wrap")
                    .font(Theme.display(30))
                    .tracking(-1)
                    .foregroundStyle(Color.white)

                Spacer(minLength: 18)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(wrap.minutes)")
                        .font(Theme.display(76))
                        .tracking(-4)
                        .foregroundStyle(Color.white)
                    Text("min")
                        .font(Theme.title(16))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                    .padding(.vertical, 16)

                VStack(alignment: .leading, spacing: 10) {
                    shareRow(label: "TOP ARTIST", value: wrap.topArtist ?? "—")
                    shareRow(label: "TOP TRACK", value: wrap.topTrack ?? "—")
                    shareRow(label: "STREAK", value: "\(wrap.streak) days")
                }

                Spacer(minLength: 16)

                HStack {
                    Text("no ads · invite only")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Spacer()
                    Text("musix.app")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.lime.opacity(0.8))
                }
            }
            .padding(24)
        }
        .frame(width: 380, height: 540)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func shareRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 78, alignment: .leading)

            Text(value)
                .font(Theme.title(14))
                .foregroundStyle(Color.white)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Date helpers

extension DateFormatter {
    static let wrapDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let longDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()
}
