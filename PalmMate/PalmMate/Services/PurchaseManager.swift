import Foundation
import Combine

/// Subscription + per-reading unlock state.
///
/// **Hybrid pricing model:**
/// - `palmmate.sub.monthly` ($2.99/mo) and `palmmate.sub.yearly` ($19.99/yr) — both
///   grant the `pro` entitlement. Pro users get full readings every time +
///   unlimited Compare Palms.
/// - `palmmate.unlock.single` ($1.99) — non-consumable per-reading unlock for
///   users who don't want to subscribe. Tracked locally per `readingID`.
///
/// **Wiring RevenueCat:**
///   1. SPM: https://github.com/RevenueCat/purchases-ios-spm
///   2. In `PalmMateApp.init()`:
///        Purchases.logLevel = .info
///        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
///   3. Replace the bodies of `bootstrap`, `purchaseSubscription`, and
///      `purchaseSingleUnlock` with `Purchases.shared` calls. Drive
///      `isSubscribed` from `customerInfo.entitlements[Config.entitlementID]?
///      .isActive == true` and listen on `customerInfoStream`.
///
/// Until then this manager simulates purchases locally so the UI flow is
/// fully testable end-to-end.
@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isSubscribed: Bool
    @Published private(set) var unlockedReadings: Set<UUID>
    @Published private(set) var credits: Int
    @Published var isPurchasing = false
    @Published var lastError: String?

    private let subscribedKey = "purchase.isSubscribed"
    private let unlocksKey    = "purchase.unlockedReadings"
    private let creditsKey    = "purchase.credits"

    /// One credit = one full reading unlock. Sold in packs of 3.
    static let creditPackSize = 3

    init() {
        let defaults = UserDefaults.standard
        self.isSubscribed = defaults.bool(forKey: subscribedKey)
        if let raw = defaults.array(forKey: unlocksKey) as? [String] {
            self.unlockedReadings = Set(raw.compactMap(UUID.init(uuidString:)))
        } else {
            self.unlockedReadings = []
        }
        self.credits = defaults.integer(forKey: creditsKey)
    }

    /// Spend a credit on a specific reading (one-tap unlock).
    func spendCredit(on readingID: UUID) -> Bool {
        guard credits > 0 else { return false }
        credits -= 1
        unlockedReadings.insert(readingID)
        UserDefaults.standard.set(credits, forKey: creditsKey)
        persistUnlocks()
        return true
    }

    /// Buy a pack of credits.
    func purchaseCreditPack() async {
        isPurchasing = true
        defer { isPurchasing = false }
        lastError = nil
        try? await Task.sleep(nanoseconds: 600_000_000)
        credits += Self.creditPackSize
        UserDefaults.standard.set(credits, forKey: creditsKey)
    }

    /// Should be called once on app launch (after RC is configured) to refresh
    /// the entitlement state from the server.
    func bootstrap() async {
        // TODO: Purchases.shared.customerInfo() -> set isSubscribed.
    }

    func isUnlocked(readingID: UUID) -> Bool {
        isSubscribed || unlockedReadings.contains(readingID)
    }

    // MARK: - Purchases (stubbed)

    func purchaseSubscription(_ product: SubscriptionProduct) async {
        isPurchasing = true
        defer { isPurchasing = false }
        lastError = nil

        // TODO: real RC purchase. Simulate success for now.
        try? await Task.sleep(nanoseconds: 600_000_000)
        isSubscribed = true
        UserDefaults.standard.set(true, forKey: subscribedKey)
    }

    func purchaseSingleUnlock(readingID: UUID) async {
        isPurchasing = true
        defer { isPurchasing = false }
        lastError = nil

        try? await Task.sleep(nanoseconds: 500_000_000)
        unlockedReadings.insert(readingID)
        persistUnlocks()
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        // TODO: Purchases.shared.restorePurchases()
        try? await Task.sleep(nanoseconds: 400_000_000)
    }

    // MARK: - Debug helpers (DEBUG-only flips for development)

    #if DEBUG
    func debugToggleSubscribed() {
        isSubscribed.toggle()
        UserDefaults.standard.set(isSubscribed, forKey: subscribedKey)
    }

    func debugReset() {
        isSubscribed = false
        unlockedReadings = []
        credits = 0
        UserDefaults.standard.set(false, forKey: subscribedKey)
        UserDefaults.standard.removeObject(forKey: unlocksKey)
        UserDefaults.standard.removeObject(forKey: creditsKey)
    }
    #endif

    // MARK: - Private

    private func persistUnlocks() {
        let raw = unlockedReadings.map(\.uuidString)
        UserDefaults.standard.set(raw, forKey: unlocksKey)
    }
}

enum SubscriptionProduct: Hashable {
    case monthly
    case yearly

    var id: String {
        switch self {
        case .monthly: return Config.monthlyProductID
        case .yearly:  return Config.yearlyProductID
        }
    }

    var fallbackPriceLabel: String {
        switch self {
        case .monthly: return Config.monthlyPriceFallback
        case .yearly:  return Config.yearlyPriceFallback
        }
    }
}
