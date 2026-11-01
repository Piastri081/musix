import Foundation

enum Config {
    /// Base URL of the Musix API. Override with the MUSIX_API_BASE_URL Info.plist key
    /// (or an xcconfig) when pointing at a deployed Cloudflare Worker.
    static var apiBaseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "MUSIX_API_BASE_URL") as? String,
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://127.0.0.1:8787")!
    }

    /// Lets people try the app without a running backend. Turn this off for production.
    static var allowDemoMode: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "MUSIX_ALLOW_DEMO_MODE") as? Bool) ?? false
    }

    static let appName = "Musix"
    static let supportEmail = "hello@musix.app"

    /// Invite-only catalogue preview notices.
    static let inviteOnlyNotice = "Musix is invite only. Activation requires an access or promo code."
}
