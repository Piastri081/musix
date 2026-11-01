import Foundation

// MARK: - Catalogue

struct Track: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    /// Length in seconds, used as a fallback until AVPlayer reports the real duration.
    let duration: Int
    let genre: String
    let audioUrl: String
    /// Deterministic seed for the generated artwork gradient.
    let palette: Int
    /// Optional looping video artwork (mp4/mov). Falls back to the animated gradient.
    var videoUrl: String? = nil

    var url: URL? { URL(string: audioUrl) }

    var durationText: String {
        let m = duration / 60
        let s = duration % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Account

struct AppUser: Codable, Identifiable, Equatable {
    var id: String
    var email: String
    var displayName: String
    var planId: String?
    var planName: String?
    var seats: Int
    var seatsUsed: Int
    var memberSince: String?

    static let preview = AppUser(
        id: "u_demo",
        email: "demo@musix.app",
        displayName: "Alex",
        planId: "family",
        planName: "Family",
        seats: 6,
        seatsUsed: 3,
        memberSince: "2026-01-04"
    )
}

// MARK: - Plans

struct Plan: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var seats: Int
    var priceLabel: String
    var invitesOnly: Bool
    var tagline: String
    var features: [String]
    /// "lime" | "violet" | "pink"
    var accent: String
}

// MARK: - Family

struct FamilyMember: Codable, Identifiable, Equatable {
    var id: String
    var email: String
    var displayName: String
    var role: String // "owner" | "member" | "invited"
    var status: String // "active" | "invited"
}

struct FamilyResponse: Codable {
    var members: [FamilyMember]
    var seats: Int
    var seatsUsed: Int
}

// MARK: - Server wrap (optional; the app also computes wraps locally)

struct ServerWrap: Codable {
    var date: String
    var minutes: Int
    var topArtist: String?
    var topTrack: String?
    var topGenre: String?
    var streak: Int
}

// MARK: - Wire responses

struct CodeResponse: Codable {
    var ok: Bool
    var devCode: String?
    var message: String?
}

struct AuthResponse: Codable {
    var token: String
    var user: AppUser
}

struct PlansResponse: Codable {
    var plans: [Plan]
}

struct RedeemResponse: Codable {
    var ok: Bool
    var user: AppUser?
    var message: String?
}

struct CatalogResponse: Codable {
    var tracks: [Track]
}

struct OKResponse: Codable {
    var ok: Bool
}

struct EmptyBody: Encodable {}

// MARK: - Local wrap model used by the UI

struct DailyWrap: Identifiable, Equatable {
    var id: String
    var date: Date
    var minutes: Int
    var trackCount: Int
    var topArtist: String?
    var topTrack: String?
    var topGenre: String?
    var streak: Int
    var hourly: [Double]

    var headline: String {
        guard minutes > 0 else { return "A quiet day. Press play." }
        if minutes >= 120 { return "A long, loud day." }
        if minutes >= 45 { return "Solid listening day." }
        return "A little taste of music."
    }

    static func empty(for date: Date = Date()) -> DailyWrap {
        DailyWrap(id: DailyWrap.key(for: date),
                  date: date,
                  minutes: 0,
                  trackCount: 0,
                  topArtist: nil,
                  topTrack: nil,
                  topGenre: nil,
                  streak: 0,
                  hourly: Array(repeating: 0, count: 24))
    }

    static func key(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
