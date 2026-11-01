import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var router: TabRouter
    @EnvironmentObject private var music: MusicStore
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var listening: ListeningStore

    @State private var showPlans = false

    private var wrap: DailyWrap { listening.wrap() }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var jumpBackIn: [Track] {
        music.recentTracks.isEmpty ? music.editorsPicks : music.recentTracks
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                header
                wrapCard
                jumpBackInSection
                shelves
                forYouSection
                inviteNote
            }
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPlans) {
            PlansView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)

                Text(session.greetingName)
                    .font(Theme.display(30))
                    .tracking(-1.2)
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            Button {
                router.tab = .profile
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.surfaceRaised)
                        .frame(width: 44, height: 44)

                    Text(String(session.greetingName.prefix(1)).uppercased())
                        .font(Theme.title(17))
                        .foregroundStyle(Theme.lime)
                }
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
        }
        .pageGutter()
    }

    // MARK: - Daily wrap

    private var wrapCard: some View {
        Button {
            router.tab = .wrap
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.lime)
                            .frame(width: 6, height: 6)
                        Text("DAILY WRAP")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.4)
                    }
                    .foregroundStyle(Color.white.opacity(0.85))

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.8))
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(wrap.minutes)")
                        .font(Theme.display(54))
                        .tracking(-2)
                    Text("min")
                        .font(Theme.title(16))
                        .foregroundStyle(Color.white.opacity(0.7))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(listening.streak())")
                            .font(Theme.display(24))
                        Text("day streak")
                            .font(Theme.body(11))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
                .foregroundStyle(Color.white)

                Text(wrap.headline)
                    .font(Theme.body(13))
                    .foregroundStyle(Color.white.opacity(0.85))

                hourlyBars
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.warmGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                RadialGradient(colors: [Color.white.opacity(0.18), .clear],
                                               center: .topLeading,
                                               startRadius: 0,
                                               endRadius: 320)
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Theme.pink.opacity(0.25), radius: 24, x: 0, y: 12)
        }
        .buttonStyle(PressableStyle())
        .pageGutter()
    }

    private var hourlyBars: some View {
        let peak = max(wrap.hourly.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<24, id: \.self) { hour in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(hour >= 6 && hour <= 23 ? 0.55 : 0.22))
                    .frame(height: max(3, CGFloat(wrap.hourly[hour] / peak) * 34))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 34, alignment: .bottom)
    }

    // MARK: - Jump back in

    private var jumpBackInSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: music.recentTracks.isEmpty ? "Start here" : "Jump back in",
                          subtitle: music.recentTracks.isEmpty ? "A few tracks to get you moving" : "Pick up where you left off")
                .pageGutter()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(jumpBackIn.prefix(8)) { track in
                        TrackCard(track: track, width: 148) {
                            play(track, in: jumpBackIn)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Shelves

    private var shelves: some View {
        VStack(alignment: .leading, spacing: 26) {
            shelf(title: "Late night", subtitle: "Low light, high fidelity", tracks: music.lateNight)
            shelf(title: "Fresh finds", subtitle: "New to Musix this week", tracks: music.fresh)
        }
    }

    private func shelf(title: String, subtitle: String, tracks: [Track]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle, actionTitle: "Play all") {
                if let first = tracks.first { play(first, in: tracks) }
            }
            .pageGutter()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(tracks) { track in
                        TrackCard(track: track, width: 132) {
                            play(track, in: tracks)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - For you

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "For you", subtitle: "Based on what you actually finish")
                .pageGutter()

            VStack(spacing: 6) {
                ForEach(music.editorsPicks.prefix(5)) { track in
                    TrackRow(track: track,
                             isLiked: music.isLiked(track.id),
                             isActive: player.current?.id == track.id,
                             onTap: { play(track, in: music.editorsPicks) },
                             onLike: { music.toggleLike(track) })
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.surface.opacity(0.5))
            )
            .pageGutter()
        }
    }

    // MARK: - Invite note

    private var inviteNote: some View {
        Button {
            showPlans = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.lime)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.lime.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Have an access code?")
                        .font(Theme.title(14))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Duo and Family plans are invite only.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
        .pageGutter()
    }

    // MARK: - Actions

    private func play(_ track: Track, in queue: [Track]) {
        player.play(track, queue: queue)
    }
}
