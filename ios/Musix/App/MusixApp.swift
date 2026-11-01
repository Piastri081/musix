import SwiftUI

@main
struct MusixApp: App {

    @StateObject private var session = Session()
    @StateObject private var player = PlayerEngine.shared
    @StateObject private var music = MusicStore.shared
    @StateObject private var listening = ListeningStore.shared
    @StateObject private var router = TabRouter()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Theme.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(player)
                .environmentObject(music)
                .environmentObject(listening)
                .environmentObject(router)
                .preferredColorScheme(.dark)
                .tint(Theme.lime)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        // OTA catalogue check: new music lands without an app update.
                        Task { await music.loadCatalog() }
                    } else {
                        WidgetBridge.publish(force: true)
                    }
                }
        }
    }
}

/// Lets any screen jump between tabs (used by the Daily Wrap card on Home).
final class TabRouter: ObservableObject {
    @Published var tab: AppTab = .home
}

struct RootView: View {
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var music: MusicStore
    @EnvironmentObject private var router: TabRouter
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                switch session.phase {
                case .restoring:
                    SplashView()
                case .signedOut:
                    AuthView()
                case .signedIn:
                    MainTabView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: session.phase)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .task {
            await session.restore()
            await music.loadCatalog()
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
        }
        .task {
            // Keep long-running sessions in sync: the operator can publish music
            // at any time and it should land without relaunching the app.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await music.loadCatalog(force: true)
            }
        }
        .onChange(of: session.phase) { _, phase in
            // Someone who just signed in (or a brand-new install) gets the
            // full catalogue immediately, including everything published since
            // their last session.
            if phase == .signedIn {
                Task { await music.loadCatalog(force: true) }
            }
        }
        .onOpenURL { url in
            guard url.scheme == "musix" else { return }
            switch url.host {
            case "wrap":
                router.tab = .wrap
            case "search":
                router.tab = .search
            case "library":
                router.tab = .library
            default:
                router.tab = .home
            }
        }
    }
}

struct SplashView: View {
    @State private var animate = false

    private let heights: [CGFloat] = [18, 34, 52, 26, 64, 40, 22]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(colors: [Theme.violet.opacity(0.28), Color.clear],
                           center: .topTrailing,
                           startRadius: 0,
                           endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(alignment: .center, spacing: 7) {
                    ForEach(0..<7, id: \.self) { index in
                        Capsule()
                            .fill(index == 4 ? Theme.lime : Theme.textPrimary)
                            .frame(width: 9, height: animate ? heights[index] : 16)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.06),
                                value: animate
                            )
                    }
                }
                .frame(height: 70)

                VStack(spacing: 6) {
                    Text("musix")
                        .font(Theme.display(36))
                        .tracking(-1.5)
                        .foregroundStyle(Theme.textPrimary)

                    Text("music, minus the noise")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear { animate = true }
    }
}
