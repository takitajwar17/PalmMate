import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AuthManager: NSObject, ObservableObject {
    @Published private(set) var userID: String?
    @Published private(set) var displayName: String?
    @Published private(set) var identityToken: String?
    @Published private(set) var isGuest: Bool = false
    @Published private(set) var freeReadingsUsed: Int = 0

    private let userIDKey = "auth.appleUserID"
    private let nameKey = "auth.displayName"
    private let identityTokenKey = "auth.identityToken"
    private let guestKey = "auth.isGuest"
    private let freeReadingsKey = "auth.freeReadingsUsed"

    /// How many free palm readings any user (guest OR signed-in non-Pro)
    /// gets before being asked to subscribe.
    static let freeReadingLimit = 1

    /// True only when signed in with Apple.
    var isSignedIn: Bool { userID != nil }

    /// True when the user can enter the app — Apple-signed OR in guest mode.
    /// (Per-reading paywall gate is computed at the call site, since it
    /// also depends on PurchaseManager.)
    var hasAccess: Bool { isSignedIn || isGuest }

    /// True when the user has free reads remaining. Pro check is layered on
    /// top of this at the call site (see ContentView.canMakeReading).
    var hasFreeReadingAvailable: Bool {
        freeReadingsUsed < Self.freeReadingLimit
    }

    override init() {
        super.init()
        userID = UserDefaults.standard.string(forKey: userIDKey)
        displayName = UserDefaults.standard.string(forKey: nameKey)
        identityToken = UserDefaults.standard.string(forKey: identityTokenKey)
        isGuest = UserDefaults.standard.bool(forKey: guestKey)
        freeReadingsUsed = UserDefaults.standard.integer(forKey: freeReadingsKey)
        // Verify the credential is still valid on launch.
        if let id = userID {
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { [weak self] state, _ in
                if state != .authorized {
                    Task { @MainActor in self?.signOut() }
                }
            }
        }
    }

    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        userID = credential.user
        UserDefaults.standard.set(credential.user, forKey: userIDKey)
        if let tokenData = credential.identityToken,
           let token = String(data: tokenData, encoding: .utf8),
           !token.isEmpty {
            identityToken = token
            UserDefaults.standard.set(token, forKey: identityTokenKey)
        }
        if let name = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let formatted = formatter.string(from: name)
            if !formatted.isEmpty {
                displayName = formatted
                UserDefaults.standard.set(formatted, forKey: nameKey)
            }
        }
        // Once signed in, drop guest mode (counter persists — same gate).
        if isGuest {
            isGuest = false
            UserDefaults.standard.set(false, forKey: guestKey)
        }
    }

    func enterGuestMode() {
        isGuest = true
        UserDefaults.standard.set(true, forKey: guestKey)
    }

    func markFreeReadingUsed() {
        freeReadingsUsed += 1
        UserDefaults.standard.set(freeReadingsUsed, forKey: freeReadingsKey)
    }

    func signOut() {
        userID = nil
        displayName = nil
        identityToken = nil
        isGuest = false
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: nameKey)
        UserDefaults.standard.removeObject(forKey: identityTokenKey)
        UserDefaults.standard.set(false, forKey: guestKey)
        // Intentionally NOT clearing `freeReadingsUsed` so the gate can't
        // be bypassed by signing out and re-entering.
    }
}
