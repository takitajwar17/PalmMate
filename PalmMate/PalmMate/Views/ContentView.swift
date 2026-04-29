import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var deepLink: DeepLinkRouter
    @EnvironmentObject private var store: ReadingStore

    @State private var selectedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var showingCompare = false
    @State private var compareInviteToken: String?
    @State private var showingPaywall = false
    @State private var showingSignInPrompt = false

    @State private var isAnalyzing = false
    @State private var analyzePhase = 0
    @State private var factIndex = 0
    @State private var factTimer: Timer?
    @State private var errorMessage: String?

    @State private var resultReading: PalmReading?
    @State private var resultDiagram: UIImage?
    @State private var resultID: UUID = UUID()
    @State private var showingResult = false

    private let openAI = OpenAIService()

    private var canMakeReading: Bool {
        purchases.isSubscribed || auth.hasFreeReadingAvailable || purchases.credits > 0
    }

    private var shouldUseFreeReading: Bool {
        !purchases.isSubscribed && auth.hasFreeReadingAvailable
    }

    private var shouldUseCredit: Bool {
        !purchases.isSubscribed && !auth.hasFreeReadingAvailable && purchases.credits > 0
    }

    private var analyzeHelperText: String {
        if purchases.isSubscribed { return "" }
        if auth.hasFreeReadingAvailable { return "1 free scan remaining" }
        if purchases.credits > 0 {
            return "\(purchases.credits) credit\(purchases.credits == 1 ? "" : "s") available"
        }
        return ""
    }

    private let analyzePhases = [
        "Tracing major lines…",
        "Reading mounts & shape…",
        "Drawing your engraving…",
        "Composing the guide…",
    ]

    private let palmFacts: [(eyebrow: String, fact: String)] = [
        ("Origin · 3000 BCE", "Palmistry began in ancient India over 5,000 years ago — the Vedic tradition called it Hast Samudrika Shastra."),
        ("Greek lineage", "Aristotle wrote a treatise on chiromancy after finding one on an altar to Hermes. He sent his findings to Alexander the Great."),
        ("The two hands", "The non-dominant hand shows what you were born with. The dominant hand shows what you've made of it."),
        ("Heart Line", "The line that runs across the top of your palm tells of how you love — generously, carefully, or all at once."),
        ("Head Line", "The middle line speaks to the shape of your mind: practical, dreaming, or restless between the two."),
        ("Life Line", "A short Life Line never meant a short life. It means a life lived with intent, in fewer chapters."),
        ("Fate Line", "Not every hand has one. When it appears late, it belongs to a late bloomer — someone who grew into their path."),
        ("Mount of Venus", "The fleshy pad at the base of your thumb is the Mount of Venus — it governs warmth and your capacity for love."),
        ("Mount of Jupiter", "Beneath the index finger sits the Mount of Jupiter — ambition, leadership, the will to be seen."),
        ("Cheiro", "The Irish palmist Cheiro read for Mark Twain, Thomas Edison, Oscar Wilde, and Sarah Bernhardt — predicting most of their lives correctly."),
        ("No two alike", "No two palms are identical — not even on identical twins. Your hand is a fingerprint with a story."),
        ("The thumb alone", "A traditional palmist could read your willpower and reasoning from your thumb alone — its length, flexibility, and shape."),
        ("The Sun Line", "When present, the Sun Line marks talent — and, more importantly, the recognition that follows."),
        ("Finger spacing", "How widely your fingers naturally splay tells how open you are to new people and ideas."),
        ("Modern science", "In dermatoglyphics, palm patterns form in the womb at 13 weeks. They never change."),
    ]

    var body: some View {
        ZStack {
            if isAnalyzing {
                analyzingOverlay
            } else {
                homeContent
            }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: $showingHistory) { HistoryView() }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
        .sheet(isPresented: $showingSignInPrompt) {
            SignInPromptSheet(onSignedIn: {
                if !canMakeReading { showingPaywall = true }
            })
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $selectedImage).ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingCompare, onDismiss: {
            compareInviteToken = nil
        }) {
            CompareView(inviteToken: compareInviteToken)
        }
        .fullScreenCover(isPresented: $showingResult) {
            if let reading = resultReading, let photo = selectedImage {
                NavigationStack {
                    ResultView(palmPhoto: photo, reading: reading,
                               diagram: resultDiagram, readingID: resultID)
                }
            }
        }
        .onChange(of: photoPickerItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    selectedImage = img
                }
            }
        }
        .onAppear { handlePendingDeepLink() }
        .onChange(of: deepLink.pending) { _ in handlePendingDeepLink() }
        .onChange(of: purchases.isSubscribed) { isSubscribed in
            if isSubscribed, compareInviteToken != nil {
                showingPaywall = false
                showingCompare = true
            }
        }
    }

    // MARK: - Home

    private var homeContent: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button { showingHistory = true } label: {
                        Canvas { ctx, size in
                            var p = Path()
                            p.move(to: CGPoint(x: 3, y: 3)); p.addLine(to: CGPoint(x: 3, y: 17))
                            p.addLine(to: CGPoint(x: 12, y: 17)); p.addLine(to: CGPoint(x: 12, y: 3))
                            p.addLine(to: CGPoint(x: 21, y: 3)); p.addLine(to: CGPoint(x: 21, y: 17))
                            ctx.stroke(p, with: .color(P.ink), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
                        }
                        .frame(width: 24, height: 20)
                    }

                    Spacer()

                    EyebrowText(text: "Today · Mercury Waxing", color: P.inkMuted)

                    Spacer()

                    Button { showingSettings = true } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(P.ink)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)

                HairlineRule()
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                // Masthead
                VStack(spacing: 4) {
                    Text(Config.appDisplayName.uppercased())
                        .font(F.display(52))
                        .foregroundStyle(P.ink)
                        .tracking(2)
                    Text("\(Config.appSubtitle) · \(Config.appSlogan)")
                        .font(F.body(13, italic: true))
                        .foregroundStyle(P.inkMuted)
                }
                .padding(.top, 16)

                // Thick + dot rule
                HStack(spacing: 8) {
                    Rectangle().frame(height: 1).foregroundStyle(P.ink)
                    Circle().frame(width: 4, height: 4).foregroundStyle(P.vermillion)
                    Rectangle().frame(height: 1).foregroundStyle(P.ink)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Camera frame
                captureFrame
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                Spacer(minLength: 0)

                // Bottom actions
                VStack(spacing: 8) {
                    analyzeButton
                    compareCTA

                    if let msg = errorMessage {
                        Text(msg)
                            .font(F.body(12, italic: true))
                            .foregroundStyle(P.vermillion)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Capture frame

    private var captureFrame: some View {
        ZStack {
            // Frame border
            Rectangle()
                .stroke(P.ink, lineWidth: 0.8)
                .background(P.paperBright)

            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: frameHeight)
                    .clipped()
            } else {
                VStack(spacing: 10) {
                    PalmEngraving(size: 110, strokeColor: P.inkFaded,
                                  lineColor: P.inkFaded, showLines: false)
                    EyebrowText(text: "Place hand here")
                    Text("Bright light. Open palm. Centered frame.")
                        .font(F.body(13, italic: true))
                        .foregroundStyle(P.inkFaded)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }

            // Corner bracket overlay
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let len: CGFloat = 14
                ForEach(["tl", "tr", "bl", "br"], id: \.self) { c in
                    let x = c.contains("l") ? 0.0 : w - len
                    let y = c.contains("t") ? 0.0 : h - len
                    Path { path in
                        if c == "tl" {
                            path.move(to: CGPoint(x: x + len, y: y))
                            path.addLine(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x, y: y + len))
                        } else if c == "tr" {
                            path.move(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x + len, y: y))
                            path.addLine(to: CGPoint(x: x + len, y: y + len))
                        } else if c == "bl" {
                            path.move(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x, y: y + len))
                            path.addLine(to: CGPoint(x: x + len, y: y + len))
                        } else {
                            path.move(to: CGPoint(x: x, y: y + len))
                            path.addLine(to: CGPoint(x: x + len, y: y + len))
                            path.addLine(to: CGPoint(x: x + len, y: y))
                        }
                    }
                    .stroke(P.vermillion, style: StrokeStyle(lineWidth: 2))
                }
            }
        }
        .frame(height: frameHeight)
    }

    private var frameHeight: CGFloat {
        let h = UIScreen.main.bounds.height
        return h > 800 ? 280 : 220
    }

    // MARK: - Camera / library buttons inline with frame

    private var captureButtons: some View {
        HStack(spacing: 10) {
            Button { showingCamera = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera")
                        .font(.system(size: 13, weight: .light))
                    Text("Camera".uppercased())
                        .font(F.mono(11))
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(P.ink)
                .foregroundStyle(P.paperBright)
            }

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 13, weight: .light))
                    Text("Library".uppercased())
                        .font(F.mono(11))
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(.clear)
                .foregroundStyle(P.ink)
                .overlay(Rectangle().stroke(P.ink, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    // MARK: - Analyze button

    private var analyzeButton: some View {
        VStack(spacing: 0) {
            // Camera + library first if no image
            if selectedImage == nil {
                captureButtons
                    .padding(.bottom, 10)
            }

            Button {
                if selectedImage == nil { return }
                if canMakeReading {
                    Task { await analyze() }
                } else if !auth.isSignedIn {
                    showingSignInPrompt = true
                } else {
                    showingPaywall = true
                }
            } label: {
                HStack {
                    Text(analyzeLabel.uppercased())
                        .font(F.mono(12))
                        .tracking(2)
                    Spacer()
                    if canMakeReading && selectedImage != nil {
                        if !analyzeHelperText.isEmpty {
                            Text(analyzeHelperText)
                                .font(F.body(12, italic: true))
                                .foregroundStyle(P.paperBright.opacity(0.75))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(analyzeBackground)
                .foregroundStyle(P.paperBright)
            }
            .disabled(selectedImage == nil)
            .opacity(selectedImage == nil ? 0.45 : 1)

            if selectedImage != nil {
                captureButtons
                    .padding(.top, 0)
            }
        }
    }

    private var analyzeLabel: String {
        if selectedImage == nil { return "Read This Palm" }
        if !canMakeReading {
            return auth.isSignedIn ? "Get More Reads" : "Sign In to Read More"
        }
        if shouldUseCredit { return "Use 1 Credit to Read" }
        return "Read This Palm"
    }

    private var analyzeBackground: Color {
        if !canMakeReading { return P.inkFaded }
        return P.vermillion
    }

    // MARK: - Compare CTA

    private var compareCTA: some View {
        Button {
            compareInviteToken = nil
            if purchases.isSubscribed { showingCompare = true }
            else { showingPaywall = true }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    EyebrowText(text: "Pro · Compare Palms", color: P.vermillion)
                    Text("Compare your story with theirs")
                        .font(F.display(17))
                        .foregroundStyle(P.ink)
                }
                Spacer()
                if !purchases.isSubscribed {
                    Image(systemName: "lock")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(P.ink)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(Rectangle().stroke(P.rule, lineWidth: 0.8))
        }
    }

    // MARK: - Analyzing overlay

    private var analyzingOverlay: some View {
        ZStack {
            NightBackground()

            VStack(spacing: 0) {
                Color.clear.frame(height: 60)

                // Top: hand with rotating compass marks
                ZStack {
                    Circle()
                        .stroke(P.vermillion.opacity(0.5),
                                style: StrokeStyle(lineWidth: 0.7, dash: [2, 4]))
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(Double(analyzePhase) * 90))
                        .animation(.easeInOut(duration: 1.6), value: analyzePhase)

                    Circle()
                        .stroke(P.moonlight.opacity(0.3), lineWidth: 0.4)
                        .frame(width: 175, height: 175)

                    PalmEngraving(size: 130,
                                  strokeColor: P.moonlight,
                                  lineColor: P.vermillion)
                }

                EyebrowText(text: "· · · Reading · · ·", color: P.vermillion)
                    .padding(.top, 18)

                Text("Consulting the lines.")
                    .font(F.display(26, italic: true))
                    .foregroundStyle(P.moonlight)
                    .padding(.top, 6)

                Spacer()

                // Middle: rotating fun fact
                VStack(spacing: 14) {
                    OrnamentRule(label: "Did you know")
                        .padding(.horizontal, 32)

                    if factIndex < palmFacts.count {
                        let fact = palmFacts[factIndex]
                        VStack(spacing: 10) {
                            Text(fact.eyebrow.uppercased())
                                .font(F.mono(10))
                                .tracking(2)
                                .foregroundStyle(P.vermillion)

                            Text(fact.fact)
                                .font(F.body(16, italic: true))
                                .foregroundStyle(P.moonlight)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.horizontal, 28)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .id(factIndex)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .frame(minHeight: 200)

                Spacer()

                // Bottom: phase steps (compact)
                VStack(spacing: 8) {
                    ForEach(Array(analyzePhases.enumerated()), id: \.offset) { i, phase in
                        HStack(spacing: 10) {
                            ZStack {
                                Rectangle()
                                    .stroke(i <= analyzePhase
                                            ? P.vermillion : P.moonlight.opacity(0.25),
                                            lineWidth: 0.7)
                                    .frame(width: 14, height: 14)
                                if i < analyzePhase {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundStyle(P.vermillion)
                                }
                            }
                            Text(phase)
                                .font(i == analyzePhase
                                      ? F.body(12, italic: true) : F.body(12))
                                .foregroundStyle(i <= analyzePhase
                                                 ? P.moonlight : P.moonlight.opacity(0.3))
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: 280)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 24)
        }
        .onAppear { startFactRotation() }
        .onDisappear { factTimer?.invalidate() }
    }

    private func startFactRotation() {
        factIndex = Int.random(in: 0..<palmFacts.count)
        factTimer?.invalidate()
        factTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                factIndex = (factIndex + 1) % palmFacts.count
            }
        }
    }

    // MARK: - Logic

    private func analyze() async {
        guard let image = selectedImage else { return }
        let shouldSpendCreditForReading = shouldUseCredit
        let shouldMarkFreeReadingUsed = shouldUseFreeReading
        errorMessage = nil
        isAnalyzing = true
        analyzePhase = 0
        defer { isAnalyzing = false }

        do {
            analyzePhase = 1
            let reading = try await openAI.analyzePalm(image: image,
                                                       identityToken: auth.identityToken)
            analyzePhase = 2

            var diagram: UIImage? = nil
            do {
                diagram = try await openAI.generateDiagram(prompt: reading.imagePrompt,
                                                           identityToken: auth.identityToken)
            } catch { }
            analyzePhase = 3

            resultReading = reading
            resultDiagram = diagram
            let newResultID = UUID()
            resultID = newResultID
            if shouldSpendCreditForReading {
                _ = purchases.spendCredit(on: newResultID)
            } else if shouldMarkFreeReadingUsed {
                auth.markFreeReadingUsed()
            }
            showingResult = true
            await store.save(reading: reading, photo: image,
                             diagram: diagram, id: newResultID)
        } catch OpenAIService.ServiceError.missingAPIKey {
            errorMessage = "Configuration issue — OpenAI key missing."
        } catch {
            errorMessage = "Reading failed: \(error.localizedDescription)"
        }
    }

    private func handlePendingDeepLink() {
        guard let dest = deepLink.pending else { return }
        if case .compare(let inviteToken) = dest {
            compareInviteToken = inviteToken
            if purchases.isSubscribed { showingCompare = true }
            else { showingPaywall = true }
        }
        deepLink.clear()
    }
}
