import SwiftUI

@main
struct PalmMateApp: App {
    @StateObject private var auth = AuthManager()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var deepLink = DeepLinkRouter()
    @StateObject private var store = ReadingStore()

    init() {
        // TODO: when wiring RevenueCat, add:
        //   Purchases.logLevel = .info
        //   Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(purchases)
                .environmentObject(deepLink)
                .environmentObject(store)
                .preferredColorScheme(.light)
                .task { await purchases.bootstrap() }
                .onOpenURL { url in deepLink.handle(url) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if !hasSeenOnboarding {
            // Step 0: Onboarding — shown to everyone before anything else.
            OnboardingView()
                .transition(.opacity)
        } else if !auth.hasAccess {
            // Step 1: Sign in or continue as guest.
            SignInView()
                .transition(.opacity)
        } else {
            // Step 2: Main app.
            ContentView()
                .transition(.opacity)
        }
    }
}
