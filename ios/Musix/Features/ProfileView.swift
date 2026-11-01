import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var music: MusicStore
    @EnvironmentObject private var listening: ListeningStore

    @AppStorage("musix.lossless") private var lossless = true
    @AppStorage("musix.autoplay") private var autoplay = true
    @AppStorage("musix.haptics") private var haptics = true

    @State private var showPlans = false
    @State private var showSignOut = false

    private var user: AppUser { session.user ?? .preview }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                planCard
                preferences
                account
                about
                signOutButton
                footer
            }
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPlans) {
            PlansView()
        }
        .confirmationDialog("Sign out of Musix?",
                            isPresented: $showSignOut,
                            titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                session.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your likes, playlists and wraps stay on this device.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.brandGradient)
                    .frame(width: 78, height: 78)

                Text(String(session.greetingName.prefix(1)).uppercased())
                    .font(Theme.display(30))
                    .foregroundStyle(Color.black)
            }

            VStack(spacing: 4) {
                Text(session.greetingName)
                    .font(Theme.display(24))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.textPrimary)

                Text(user.email)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 18) {
                miniStat(value: "\(music.likedTracks.count)", label: "liked")
                divider
                miniStat(value: "\(listening.streak())", label: "day streak")
                divider
                miniStat(value: "\(user.seats)", label: "seats")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .pageGutter()
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(width: 1, height: 22)
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.title(17))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.body(11))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(minWidth: 54)
    }

    // MARK: - Plan

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR PLAN")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Theme.textSecondary)

                    Text(user.planName ?? "No plan yet")
                        .font(Theme.display(26))
                        .tracking(-0.8)
                        .foregroundStyle(Theme.textPrimary)
                }

                Spacer()

                Text("INVITE ONLY")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Theme.lime)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.lime.opacity(0.12)))
            }

            seatMeter

            HStack(spacing: 10) {
                Button {
                    showPlans = true
                } label: {
                    Text("Manage plan")
                        .font(Theme.title(14))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.lime))
                }
                .buttonStyle(PressableStyle())

                Button {
                    showPlans = true
                } label: {
                    Text("Redeem code")
                        .font(Theme.title(14))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(PressableStyle())
            }
        }
        .card(padding: 18)
        .pageGutter()
    }

    private var seatMeter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(user.seatsUsed) of \(user.seats) seats used")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Add up to \(max(0, user.seats - user.seatsUsed)) more")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Theme.brandGradient)
                        .frame(width: geo.size.width * CGFloat(min(1, Double(user.seatsUsed) / Double(max(user.seats, 1)))))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Preferences

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Playback")
                .font(Theme.title(17))
                .foregroundStyle(Theme.textPrimary)
                .pageGutter()

            VStack(spacing: 0) {
                toggleRow(icon: "waveform", title: "Lossless audio", subtitle: "Higher bitrate, more data", isOn: $lossless)
                rowDivider
                toggleRow(icon: "play.circle", title: "Autoplay", subtitle: "Keep the queue going", isOn: $autoplay)
                rowDivider
                toggleRow(icon: "hand.tap", title: "Haptics", subtitle: "Taps you can feel", isOn: $haptics)
                rowDivider
                infoRow(icon: "lock.shield", title: "Privacy", value: "On-device")
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .pageGutter()
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1)
            .padding(.leading, 52)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.title(14))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.lime)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon)

            Text(title)
                .font(Theme.title(14))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Text(value)
                .font(Theme.body(13))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.lime)
            .frame(width: 26, height: 26)
    }

    // MARK: - Account

    private var account: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(Theme.title(17))
                .foregroundStyle(Theme.textPrimary)
                .pageGutter()

            VStack(spacing: 0) {
                infoRow(icon: "envelope", title: "Email", value: user.email)
                rowDivider
                infoRow(icon: "calendar", title: "Member since", value: user.memberSince ?? "2026")
                rowDivider
                infoRow(icon: "person.2", title: "Plan", value: user.planName ?? "None")
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .pageGutter()
        }
    }

    // MARK: - About

    private var about: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(Theme.title(17))
                .foregroundStyle(Theme.textPrimary)
                .pageGutter()

            VStack(spacing: 0) {
                infoRow(icon: "info.circle", title: "Version", value: "1.0.0 (1)")
                rowDivider
                Link(destination: URL(string: "https://musix.app/privacy")!) {
                    infoRow(icon: "hand.raised", title: "Privacy policy", value: "Read")
                }
                rowDivider
                Link(destination: URL(string: "https://musix.app/terms")!) {
                    infoRow(icon: "doc.text", title: "Terms", value: "Read")
                }
                rowDivider
                Link(destination: URL(string: "mailto:hello@musix.app")!) {
                    infoRow(icon: "bubble.left", title: "Support", value: Config.supportEmail)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
            )
            .pageGutter()
        }
    }

    private var signOutButton: some View {
        Button {
            showSignOut = true
        } label: {
            Text("Sign out")
                .font(Theme.title(15))
                .foregroundStyle(Theme.pink)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.pink.opacity(0.10))
                )
        }
        .buttonStyle(PressableStyle())
        .pageGutter()
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("musix")
                .font(Theme.display(15))
                .foregroundStyle(Theme.textTertiary)
            Text("No ads. No trackers. Invite only.")
                .font(Theme.body(11))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }
}
