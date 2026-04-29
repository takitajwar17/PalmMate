import SwiftUI
import AuthenticationServices

/// Sheet presented when a guest exhausts their free reading.
/// After successful Apple Sign-In, dismisses and fires `onSignedIn`.
struct SignInPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager

    var onSignedIn: () -> Void = {}

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Maybe later")
                            .font(F.mono(11))
                            .foregroundStyle(P.inkFaded)
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 20)
                }

                Spacer()

                VStack(spacing: 20) {
                    PalmEngraving(size: 110,
                                  strokeColor: P.ink,
                                  lineColor: P.vermillion)

                    VStack(spacing: 8) {
                        StampBadge(text: "Reading Complete")

                        Text("Sign in to\nread more.")
                            .font(F.display(48))
                            .foregroundStyle(P.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(-3)

                        Text("Your first reading was on the house.\nSign in with Apple to keep going.")
                            .font(F.body(15, italic: true))
                            .foregroundStyle(P.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    OrnamentRule(label: "Continue")
                        .padding(.horizontal, 24)

                    SignInWithAppleButton(.signIn,
                        onRequest: { $0.requestedScopes = [.fullName] },
                        onCompletion: { result in
                            if case .success(let authorization) = result {
                                Task { @MainActor in
                                    auth.handleAuthorization(authorization)
                                    dismiss()
                                    try? await Task.sleep(nanoseconds: 350_000_000)
                                    onSignedIn()
                                }
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .padding(.horizontal, 24)

                    Button { dismiss() } label: {
                        Text("Maybe later")
                            .font(F.body(13, italic: true))
                            .foregroundStyle(P.inkFaded)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.large])
    }
}
