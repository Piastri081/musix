import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home, search, wrap, library, profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .wrap: return "Wrap"
        case .library: return "Library"
        case .profile: return "You"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .wrap: return "chart.bar.xaxis"
        case .library: return "square.stack.fill"
        case .profile: return "person.fill"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var router: TabRouter
    @EnvironmentObject private var player: PlayerEngine

    @State private var showPlayer = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                switch router.tab {
                case .home:
                    NavigationStack { HomeView() }
                case .search:
                    NavigationStack { SearchView() }
                case .wrap:
                    NavigationStack { WrapView() }
                case .library:
                    NavigationStack { LibraryView() }
                case .profile:
                    NavigationStack { ProfileView() }
                }
            }

            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerView()
        }
        .task {
            await MusicStore.shared.loadCatalog()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if player.current != nil {
                MiniPlayerBar(isPresented: $showPlayer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            MusixTabBar(selection: $router.tab)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .animation(.easeOut(duration: 0.22), value: player.current?.id)
        .background(
            LinearGradient(colors: [Theme.background.opacity(0), Theme.background.opacity(0.92), Theme.background],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

struct MusixTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(height: 20)

                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selection == tab ? Theme.lime : Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.surface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}
