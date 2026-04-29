import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var page = 0

    private let pages: [(roman: String, label: String, title: String, body: String)] = [
        ("I", "The Hand",
         "Read the lines\nyou carry.",
         "Take a photo of your palm. Our model studies your major lines, mounts, and finger shapes the way a palm reader would — then writes you an editorial reading you'll actually want to keep."),
        ("II", "The Method",
         "Your palm,\nredrawn as an atlas.",
         "We pair vision intelligence with engraved illustration — the diagram you'd find in an old occult textbook, but for your hand."),
        ("III", "The Circle",
         "Refer friends,\nread for free.",
         "Send a friend a Compare invite. When they take their photo, you both get a free reading credit on us. Keep going as long as you keep sharing."),
    ]

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                // Top spacer (no skip — must go through all three pages)
                Color.clear.frame(height: 56)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
                        OnboardPage(roman: p.roman, label: p.label,
                                    title: p.title, copy: p.body)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle()
                            .frame(width: i == page ? 24 : 24, height: 2)
                            .foregroundStyle(i == page ? P.vermillion : P.rule)
                            .animation(.easeInOut(duration: 0.2), value: page)
                    }
                }
                .padding(.bottom, 22)

                // Continue button
                InkButton(
                    title: page < 2 ? "Continue" : "Get Started",
                    style: .primary,
                    action: {
                        if page < 2 {
                            withAnimation { page += 1 }
                        } else {
                            hasSeenOnboarding = true
                        }
                    }
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
    }
}

private struct OnboardPage: View {
    let roman: String
    let label: String
    let title: String
    let copy: String

    var body: some View {
        VStack(spacing: 0) {
            // Folio band
            HStack {
                HStack(spacing: 6) {
                    Text(roman)
                        .font(F.display(13, italic: true))
                        .foregroundStyle(P.vermillion)
                    EyebrowText(text: "of three")
                }
                Spacer()
                EyebrowText(text: label, color: P.vermillion)
            }
            .padding(.horizontal, 32)
            .padding(.top, 10)

            HairlineRule()
                .padding(.horizontal, 32)
                .padding(.top, 10)

            // Visual
            visualArea
                .padding(.top, 28)

            // Copy
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(F.display(38))
                    .foregroundStyle(P.ink)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(copy)
                    .font(F.body(16))
                    .foregroundStyle(P.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Spacer()
        }
    }

    @ViewBuilder
    private var visualArea: some View {
        switch roman {
        case "I":
            PalmEngraving(size: 130, strokeColor: P.ink, lineColor: P.vermillion)
                .frame(height: 160)
        case "II":
            OnboardPhotoTransform()
                .frame(height: 160)
                .padding(.horizontal, 32)
        default:
            OnboardReferralVisual()
                .frame(height: 160)
                .padding(.horizontal, 32)
        }
    }
}

private struct OnboardPhotoTransform: View {
    var body: some View {
        HStack(spacing: 0) {
            // Photo half
            ZStack {
                P.paperDeep
                PalmEngraving(size: 130, strokeColor: P.inkMuted, lineColor: P.inkMuted, showLines: false)
                    .opacity(0.5)
                VStack {
                    EyebrowText(text: "Photo")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    Spacer()
                }
            }
            .border(P.rule, width: 0.5)

            // Arrow divider
            ZStack {
                Rectangle().frame(width: 0.5).foregroundStyle(P.rule)
                Text("→")
                    .font(F.mono(11))
                    .foregroundStyle(P.vermillion)
                    .padding(4)
                    .background(P.paper)
            }

            // Engraving half
            ZStack {
                P.paperBright
                PalmEngraving(size: 130, strokeColor: P.ink, lineColor: P.vermillion)
                VStack {
                    EyebrowText(text: "Engraving")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    Spacer()
                }
            }
            .border(P.rule, width: 0.5)
        }
        .overlay(Rectangle().stroke(P.ink, lineWidth: 0.8))
    }
}

private struct OnboardReferralVisual: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Arc connecting two hands
            Path { path in
                path.move(to: CGPoint(x: 40, y: 120))
                path.addQuadCurve(to: CGPoint(x: 260, y: 120),
                                  control: CGPoint(x: 150, y: 20))
            }
            .stroke(P.vermillion, style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
            .opacity(pulse ? 0.9 : 0.3)
            .frame(height: 140)

            HStack(spacing: 0) {
                PalmEngraving(size: 70, strokeColor: P.ink, lineColor: P.vermillion)
                Spacer()
                PalmEngraving(size: 70, strokeColor: P.ink, lineColor: P.vermillion, mirror: true)
            }

            // Center mark
            ZStack {
                Circle()
                    .fill(P.paper)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(P.vermillion, lineWidth: 0.8))
                Text("∞")
                    .font(F.display(13))
                    .foregroundStyle(P.vermillion)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
