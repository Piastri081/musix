import Foundation

/// Owns authentication state, the signed-in user and plan changes.
final class Session: ObservableObject {

    enum Phase: Equatable {
        case restoring
        case signedOut
        case signedIn
    }

    @Published private(set) var phase: Phase = .restoring
    @Published private(set) var user: AppUser?
    @Published private(set) var isDemo = false

    private let api = APIClient.shared
    private let userKey = "musix.user.v1"
    private let demoKey = "musix.demo"

    var isSignedIn: Bool { phase == .signedIn }

    var greetingName: String {
        guard let name = user?.displayName, !name.isEmpty else { return "there" }
        return name
    }

    // MARK: - Restore

    @MainActor
    func restore() async {
        if UserDefaults.standard.bool(forKey: demoKey),
           let cached = Self.cachedUser() {
            user = cached
            isDemo = true
            phase = .signedIn
            return
        }

        guard let token = Keychain.read("musix.token") else {
            phase = .signedOut
            return
        }

        api.token = token

        if let cached = Self.cachedUser() {
            user = cached
            phase = .signedIn
        }

        do {
            let me: AppUser = try await api.get("/v1/me")
            user = me
            cache(me)
            phase = .signedIn
        } catch {
            // Keep the cached session on transport errors; drop it on a hard auth failure.
            if user == nil {
                api.token = nil
                phase = .signedOut
            }
        }
    }

    // MARK: - Email code login

    /// Returns the dev code when the backend is running in development mode.
    @MainActor
    @discardableResult
    func requestCode(email: String) async throws -> String? {
        let response: CodeResponse = try await api.post("/v1/auth/request-code",
                                                        body: ["email": email.lowercased()])
        return response.devCode
    }

    @MainActor
    func verify(email: String, code: String) async throws {
        let response: AuthResponse = try await api.post("/v1/auth/verify",
                                                        body: ["email": email.lowercased(), "code": code])
        api.token = response.token
        user = response.user
        isDemo = false
        UserDefaults.standard.set(false, forKey: demoKey)
        cache(response.user)
        phase = .signedIn
    }

    // MARK: - Offline demo

    func enterDemoMode(email: String = "demo@musix.app") {
        let demoUser = AppUser(id: "u_demo",
                               email: email,
                               displayName: Self.nameFromEmail(email),
                               planId: "duo",
                               planName: "Duo",
                               seats: 2,
                               seatsUsed: 2,
                               memberSince: "2026-01-04")
        user = demoUser
        isDemo = true
        UserDefaults.standard.set(true, forKey: demoKey)
        cache(demoUser)
        phase = .signedIn
    }

    // MARK: - Plans

    @MainActor
    func redeem(code rawCode: String) async throws {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { throw APIError(message: "Enter an access code.") }

        if isDemo {
            let plan = Self.demoPlan(for: code)
            guard let plan else { throw APIError(message: "That code isn't valid. Check it and try again.") }
            var updated = user ?? .preview
            updated.planId = plan.id
            updated.planName = plan.name
            updated.seats = plan.seats
            updated.seatsUsed = min(updated.seatsUsed, plan.seats)
            user = updated
            cache(updated)
            return
        }

        let response: RedeemResponse = try await api.post("/v1/plans/redeem", body: ["code": code])
        guard let updated = response.user else {
            throw APIError(message: response.message ?? "That code isn't valid.")
        }
        user = updated
        cache(updated)
    }

    @MainActor
    func refreshUser() async {
        guard !isDemo else { return }
        do {
            let me: AppUser = try await api.get("/v1/me")
            user = me
            cache(me)
        } catch {
            // Silent: the UI keeps the cached profile.
        }
    }

    // MARK: - Sign out

    func signOut() {
        api.token = nil
        user = nil
        isDemo = false
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.set(false, forKey: demoKey)
        phase = .signedOut
    }

    // MARK: - Helpers

    private func cache(_ user: AppUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private static func cachedUser() -> AppUser? {
        guard let data = UserDefaults.standard.data(forKey: "musix.user.v1") else { return nil }
        return try? JSONDecoder().decode(AppUser.self, from: data)
    }

    static func nameFromEmail(_ email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "Listener"
        let cleaned = local.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return cleaned
            .split(separator: " ")
            .first
            .map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? "Listener"
    }

    private static func demoPlan(for code: String) -> Plan? {
        if code.contains("FAM") || code.contains("6") {
            return Plan(id: "family", name: "Family", seats: 6, priceLabel: "Invite only",
                        invitesOnly: true, tagline: "Six seats, one bill.",
                        features: ["6 accounts", "Lossless audio", "Daily Wraps", "Shared library"],
                        accent: "violet")
        }
        if code.contains("DUO") || code.contains("2") {
            return Plan(id: "duo", name: "Duo", seats: 2, priceLabel: "Invite only",
                        invitesOnly: true, tagline: "Two accounts, one code.",
                        features: ["2 accounts", "Lossless audio", "Daily Wraps"],
                        accent: "lime")
        }
        if code.hasPrefix("MUSIX") || code.contains("SOLO") {
            return Plan(id: "solo", name: "Solo", seats: 1, priceLabel: "Invite only",
                        invitesOnly: true, tagline: "Just you, no interruptions.",
                        features: ["1 account", "Lossless audio", "Daily Wraps"],
                        accent: "pink")
        }
        return nil
    }
}
