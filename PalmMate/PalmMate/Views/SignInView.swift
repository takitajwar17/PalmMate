import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                // Top frame brackets
                folioBrackets

                // Folio header
                HStack {
                    EyebrowText(text: Config.appDisplayName)
                    Spacer()
                    EyebrowText(text: "Volume I", color: P.vermillion)
                    Spacer()
                    EyebrowText(text: "No. 001")
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer()

                // Hero
                VStack(spacing: 16) {
                    PalmEngraving(size: 160, strokeColor: P.ink, lineColor: P.vermillion)

                    VStack(spacing: 4) {
                        Text("Show me")
                            .font(F.display(60))
                            .foregroundStyle(P.ink)
                            .lineSpacing(-4)
                        Text("your hand.")
                            .font(F.display(60, italic: true))
                            .foregroundStyle(P.vermillion)
                    }
                    .multilineTextAlignment(.center)
                    .lineSpacing(-4)

                    Text("Scan your palm. Compare your story.\nWritten in the manner of the old guides.")
                        .font(F.body(16, italic: true))
                        .foregroundStyle(P.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                // Sign-in block
                VStack(spacing: 0) {
                    OrnamentRule(label: "Begin")
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    // Apple Sign In — wrapped in an InkButton style
                    SignInWithAppleButton(.signIn,
                        onRequest: { $0.requestedScopes = [.fullName] },
                        onCompletion: { result in
                            if case .success(let auth) = result {
                                Task { @MainActor in self.auth.handleAuthorization(auth) }
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .padding(.horizontal, 24)

                    Button {
                        auth.enterGuestMode()
                    } label: {
                        Text("Try one as a guest")
                            .font(F.body(15, italic: true))
                            .foregroundStyle(P.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .overlay(Rectangle().stroke(P.ink, lineWidth: 0.8))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    Text("Your first reading is on the house.")
                        .font(F.body(12, italic: true))
                        .foregroundStyle(P.inkFaded)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
            }
        }
    }

    private var folioBrackets: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                // Top hairline
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(P.rule)
                    .padding(.horizontal, 22)
                    .padding(.top, 72)

                // Corner marks
                Group {
                    cornerMark(tl: true)
                        .padding(.leading, 22)
                        .padding(.top, 68)
                    cornerMark(tl: false)
                        .padding(.trailing, 22)
                        .padding(.top, 68)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .frame(height: 80)
    }

    private func cornerMark(tl: Bool) -> some View {
        ZStack(alignment: tl ? .topLeading : .topTrailing) {
            Rectangle()
                .frame(width: 8, height: 1)
                .foregroundStyle(P.rule)
                .frame(width: 8, height: 8, alignment: tl ? .topLeading : .topTrailing)
        }
    }
}
