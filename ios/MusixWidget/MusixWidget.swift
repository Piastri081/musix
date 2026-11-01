import WidgetKit
import SwiftUI

// MARK: - Bundle

@main
struct MusixWidgets: WidgetBundle {
    var body: some Widget {
        DailyWrapWidget()
    }
}

// MARK: - Timeline

struct WrapEntry: TimelineEntry {
    let date: Date
    let snapshot: MusixShared.Snapshot
}

struct WrapProvider: TimelineProvider {
    func placeholder(in context: Context) -> WrapEntry {
        WrapEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (WrapEntry) -> Void) {
        completion(WrapEntry(date: Date(), snapshot: MusixShared.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WrapEntry>) -> Void) {
        let entry = WrapEntry(date: Date(), snapshot: MusixShared.load() ?? .preview)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct DailyWrapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MusixDailyWrap", provider: WrapProvider()) { entry in
            WrapWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(palette: entry.snapshot.palette)
                }
        }
        .configurationDisplayName("Daily Wrap")
        .description("Today's minutes, streak and top artist.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WrapWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WrapEntry

    private var snapshot: MusixShared.Snapshot { entry.snapshot }

    var body: some View {
        Group {
            if family == .systemMedium {
                medium
            } else {
                small
            }
        }
        .widgetURL(URL(string: "musix://wrap"))
    }

    // MARK: Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 0)

                if snapshot.streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(snapshot.streak)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.widgetHex(0xB8FF3F))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(snapshot.minutes)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text("min")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 0)

            Text(snapshot.isPlaying ? (snapshot.nowTitle ?? "Playing") : (snapshot.topArtist ?? "Nothing yet"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)

            hourBars(buckets: 8)
        }
    }

    // MARK: Medium

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("DAILY WRAP")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.55))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(snapshot.minutes)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("min")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Text(snapshot.streak > 0 ? "\(snapshot.streak) day streak" : "Start a streak today")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.widgetHex(0xB8FF3F).opacity(0.9))

                Spacer(minLength: 0)

                hourBars(buckets: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.isPlaying ? "NOW PLAYING" : "TOP TODAY")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.45))

                Text(snapshot.isPlaying ? (snapshot.nowTitle ?? "—") : (snapshot.topTrack ?? "—"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(snapshot.isPlaying ? (snapshot.nowArtist ?? "") : (snapshot.topArtist ?? "Play something"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    HStack(spacing: 2) {
                        Capsule().fill(Color.widgetHex(0xB8FF3F)).frame(width: 3, height: 8)
                        Capsule().fill(Color.widgetHex(0xB8FF3F)).frame(width: 3, height: 13)
                        Capsule().fill(Color.widgetHex(0xB8FF3F)).frame(width: 3, height: 10)
                    }
                    Text("musix")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Bars

    private func hourBars(buckets: Int) -> some View {
        let counts = bucketize(snapshot.hourly, into: buckets)
        let peak = max(counts.max() ?? 0, 1)

        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<buckets, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.white.opacity(counts[index] > 0 ? 0.55 : 0.14))
                    .frame(height: max(2, CGFloat(counts[index] / peak) * 18))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 18, alignment: .bottom)
    }

    private func bucketize(_ values: [Double], into buckets: Int) -> [Double] {
        guard !values.isEmpty, buckets > 0 else { return Array(repeating: 0, count: max(buckets, 1)) }
        let size = max(1, values.count / buckets)
        var result: [Double] = []

        for bucket in 0..<buckets {
            let start = bucket * size
            let end = min(values.count, start + size)
            guard start < end else {
                result.append(0)
                continue
            }
            result.append(values[start..<end].reduce(0, +))
        }
        return result
    }
}

// MARK: - Background

struct WidgetBackground: View {
    let palette: Int

    private var colors: [Color] {
        let pairs: [[UInt32]] = [
            [0x7C5CFF, 0xFF4D8D],
            [0x4DE1FF, 0x7C5CFF],
            [0xB8FF3F, 0x1FA97A],
            [0xFF8A3D, 0xFF4D8D],
            [0xFFD23D, 0xFF8A3D],
            [0x7C5CFF, 0x4DE1FF],
            [0x2DE2A6, 0x4DE1FF],
            [0xFF4D8D, 0x7C5CFF]
        ]
        let pair = pairs[abs(palette) % pairs.count]
        return [Color.widgetHex(pair[0]), Color.widgetHex(pair[1])]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.widgetHex(0x0B0B12), colors[0].opacity(0.55)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)

            RadialGradient(colors: [colors[1].opacity(0.45), .clear],
                           center: .bottomTrailing,
                           startRadius: 0,
                           endRadius: 200)
        }
    }
}

extension Color {
    static func widgetHex(_ value: UInt32) -> Color {
        Color(.sRGB,
              red: Double((value >> 16) & 0xFF) / 255,
              green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255,
              opacity: 1)
    }
}
