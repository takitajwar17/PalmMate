import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var showingPaywall = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header bar
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundStyle(P.ink)
                            }
                            Spacer()
                            EyebrowText(text: "Account")
                            Spacer()
                            Color.clear.frame(width: 20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                        HairlineRule()
                            .padding(.horizontal, 20)

                        VStack(spacing: 22) {
                            // The Reader block
                            settingsBlock(label: "The Reader") {
                                // Name row
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let name = auth.displayName, !name.isEmpty {
                                            Text(name)
                                                .font(F.display(22))
                                                .foregroundStyle(P.ink)
                                        } else {
                                            Text(auth.isGuest ? "Guest Reader" : "Apple Sign In")
                                                .font(F.display(22, italic: true))
                                                .foregroundStyle(P.inkMuted)
                                        }
                                        EyebrowText(text: auth.isGuest ? "Guest mode" : "Apple ID · \(purchases.isSubscribed ? "Pro Subscriber" : "Free")")
                                    }
                                    Spacer()
                                    if purchases.isSubscribed {
                                        StampBadge(text: "Pro")
                                    }
                                }
                                .padding(.vertical, 12)
                                .overlay(alignment: .bottom) {
                                    Rectangle().frame(height: 0.5).foregroundStyle(P.ruleSoft)
                                }

                                settingsRow(k: "Readings kept",
                                            v: "\(purchases.isSubscribed ? "∞" : "\(max(0, AuthManager.freeReadingLimit - auth.freeReadingsUsed))") credit\(auth.freeReadingsUsed == 1 ? "" : "s") remaining")
                            }

                            // Subscription block
                            settingsBlock(label: "Subscription") {
                                if purchases.isSubscribed {
                                    settingsRow(k: "Plan", v: "Pro · Yearly")
                                    settingsRow(k: "Manage", v: "App Store ›", isLink: true) {
                                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                } else {
                                    settingsRow(k: "Status", v: "Free")
                                    Button {
                                        showingPaywall = true
                                    } label: {
                                        HStack {
                                            EyebrowText(text: "Upgrade to Pro", color: P.vermillion)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10, weight: .light))
                                                .foregroundStyle(P.vermillion)
                                        }
                                        .padding(.vertical, 10)
                                    }
                                }
                                Button { Task { await purchases.restore() } } label: {
                                    HStack {
                                        EyebrowText(text: "Restore Purchases")
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                }
                            }

                            // The House block
                            settingsBlock(label: "The House") {
                                settingsRow(k: "Privacy", v: "palmistry.app ›", isLink: true) {
                                    if let url = URL(string: "https://palmistry.app/privacy") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                settingsRow(k: "Terms", v: "palmistry.app ›", isLink: true) {
                                    if let url = URL(string: "https://palmistry.app/terms") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                settingsRow(k: "Version", v: appVersion)
                            }

                            #if DEBUG
                            settingsBlock(label: "Developer") {
                                Button("Toggle Pro (debug)") {
                                    purchases.debugToggleSubscribed()
                                }
                                .font(F.mono(11)).foregroundStyle(P.inkMuted).padding(.vertical, 8)
                                Button("Reset purchases (debug)") {
                                    purchases.debugReset()
                                }
                                .font(F.mono(11)).foregroundStyle(P.vermillion).padding(.vertical, 8)
                            }
                            #endif

                            // Redo onboarding
                            Button {
                                hasSeenOnboarding = false
                                dismiss()
                            } label: {
                                Text("View Onboarding Again")
                                    .font(F.mono(11))
                                    .tracking(2)
                                    .foregroundStyle(P.inkMuted)
                            }
                            .padding(.top, 4)

                            // Sign out
                            if auth.hasAccess {
                                Button {
                                    auth.signOut()
                                    dismiss()
                                } label: {
                                    Text(auth.isGuest ? "Exit Guest Mode" : "Sign Out")
                                        .font(F.mono(11))
                                        .tracking(2)
                                        .foregroundStyle(P.vermillion)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 50)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsBlock<Content: View>(label: String,
                                              @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            OrnamentRule(label: label)
                .padding(.bottom, 6)
            content()
        }
    }

    private func settingsRow(k: String, v: String, isLink: Bool = false,
                              action: (() -> Void)? = nil) -> some View {
        let row = HStack {
            Text(k.uppercased())
                .font(F.mono(10))
                .foregroundStyle(P.inkMuted)
            Spacer()
            Text(v)
                .font(F.body(14))
                .foregroundStyle(isLink ? P.vermillion : P.ink)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 0.5).foregroundStyle(P.ruleSoft)
        }

        if let action {
            return AnyView(Button(action: action) { row })
        } else {
            return AnyView(row)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
