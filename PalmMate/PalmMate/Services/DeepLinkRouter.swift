import Foundation
import Combine

/// Tracks where an incoming deep link should drop the user.
/// Set from `.onOpenURL` at the app root; views consume + clear it.
@MainActor
final class DeepLinkRouter: ObservableObject {
    enum Destination: Equatable {
        case compare(inviteToken: String?)   // nil = generic compare entry
    }

    @Published var pending: Destination?

    func handle(_ url: URL) {
        guard url.scheme == Config.appURLScheme || url.host == Config.appShareBaseURL.host else {
            return
        }

        // Custom scheme: palmmate://compare?invite=abc123
        // Universal link: https://palmmate.app/?invite=abc123
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = (components?.path ?? "").lowercased()
        let host = (url.host ?? "").lowercased()
        let token = components?.queryItems?.first(where: { $0.name == "invite" })?.value

        if host == "compare" || path.contains("compare") || token != nil {
            pending = .compare(inviteToken: token)
        }
    }

    func clear() {
        pending = nil
    }
}
