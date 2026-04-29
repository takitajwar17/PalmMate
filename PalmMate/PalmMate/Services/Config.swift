import Foundation

/// Central place for app-level configuration constants.
///
/// IMPORTANT: For production you should NOT ship your OpenAI key inside the
/// binary. Move the call to a backend (Cloudflare Worker, Vercel function,
/// Firebase Function, etc.) and have the app hit that proxy instead. The
/// `/backend` directory in this repo has a starter Worker that does exactly
/// that, plus the pair-invite endpoints needed for viral compare.
enum Config {
    // MARK: - Brand

    /// App Store metadata and in-app display copy.
    static let appStoreName = "PalmMate: Palm Reading"
    static let appDisplayName = "PalmMate"
    static let appSubtitle = "Free Palm Scanner"
    static let appSlogan = "Scan your palm. Compare your story."

    // MARK: - OpenAI (development; move behind backend before scale)

    static var openAIAPIKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !key.isEmpty, key != "$(OPENAI_API_KEY)" {
            return key
        }
        return ""
    }

    // MARK: - RevenueCat

    /// RevenueCat public iOS SDK key (from the RC dashboard).
    static let revenueCatAPIKey: String = ""

    /// The single entitlement that gates Pro features.
    static let entitlementID = "pro"

    /// Auto-renewing subscription product IDs (must match App Store Connect).
    static let monthlyProductID = "palmmate.sub.monthly"   // $2.99/mo
    static let yearlyProductID  = "palmmate.sub.yearly"    // $19.99/yr (~44% off)

    /// Non-renewing one-off "unlock this single reading" purchase.
    static let singleUnlockProductID = "palmmate.unlock.single"  // $1.99

    /// Consumable: 3-credit pack — uneven on purpose. Each credit = 1 reading.
    static let creditPackProductID = "palmmate.credits.three"    // $4.49

    /// Display strings — these are fallbacks; live prices come from RevenueCat.
    static let monthlyPriceFallback     = "$2.99"
    static let yearlyPriceFallback      = "$19.99"
    static let singleUnlockPriceFallback = "$1.99"
    static let creditPackPriceFallback  = "$4.49"

    // MARK: - Backend (pair invites + OpenAI proxy — see /backend)

    /// Base URL for the backend. Empty string disables backend-driven
    /// pair-compare and falls back to same-session compare.
    static var backendBaseURL: URL? {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
           let url = URL(string: raw), !raw.isEmpty, raw != "$(BACKEND_BASE_URL)" {
            return url
        }
        return nil
    }

    // MARK: - Sharing & deep links

    /// Public landing page that knows how to redirect into the app or to the
    /// App Store (for users who don't have it yet). Used in share text.
    static let appShareBaseURL = URL(string: "https://palmmate.app")!
    static let appSiteLabel = "palmmate.app"
    static let termsURL = appShareBaseURL.appendingPathComponent("terms")
    static let privacyURL = appShareBaseURL.appendingPathComponent("privacy")

    /// Custom URL scheme handled by Info.plist `CFBundleURLTypes`.
    /// Used for compare deep-links: `palmmate://compare?invite=<token>`
    static let appURLScheme = "palmmate"

    static func soloShareURL(displayName: String?) -> URL {
        var components = URLComponents(url: appShareBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "utm_source",   value: "share"),
            URLQueryItem(name: "utm_medium",   value: "image"),
            URLQueryItem(name: "utm_campaign", value: "solo_share"),
            URLQueryItem(name: "ref",          value: displayName ?? "anon")
        ]
        return components.url!
    }

    static func compareInviteURL(token: String) -> URL {
        var components = URLComponents(url: appShareBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "utm_source",   value: "share"),
            URLQueryItem(name: "utm_medium",   value: "invite"),
            URLQueryItem(name: "utm_campaign", value: "compare_invite"),
            URLQueryItem(name: "invite",       value: token)
        ]
        return components.url!
    }
}
