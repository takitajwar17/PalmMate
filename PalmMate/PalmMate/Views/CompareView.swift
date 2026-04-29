import SwiftUI
import PhotosUI

struct CompareView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthManager

    let inviteToken: String?

    @State private var leftImage: UIImage?
    @State private var rightImage: UIImage?
    @State private var leftLabel: String = "You"
    @State private var rightLabel: String = ""

    @State private var leftPickerItem: PhotosPickerItem?
    @State private var rightPickerItem: PhotosPickerItem?
    @State private var showingCamera: Side?

    @State private var isAnalyzing = false
    @State private var isCreatingInvite = false
    @State private var errorMessage: String?
    @State private var inviteShareItem: ShareItem?

    @State private var match: PalmMatchReading?
    @State private var diagram: UIImage?
    @State private var matchShareURL: URL?
    @State private var showingResult = false

    private let openAI = OpenAIService()

    enum Side: Identifiable { case left, right; var id: Self { self } }

    init(inviteToken: String? = nil) {
        self.inviteToken = inviteToken
    }

    private var isJoiningInvite: Bool { inviteToken != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                VStack(spacing: 0) {
                    // Header bar
                    HStack {
                        Button { dismiss() } label: {
                            Text("‹ Cancel")
                                .font(F.mono(11))
                                .foregroundStyle(P.ink)
                        }
                        Spacer()
                        EyebrowText(text: "Pro", color: P.vermillion)
                        Spacer()
                        Color.clear.frame(width: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    HairlineRule().padding(.horizontal, 20)

                    ScrollView {
                        VStack(spacing: 0) {
                            titleBlock

                            photoPair
                                .frame(height: 240)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)

                            nameFields
                                .padding(.horizontal, 20)
                                .padding(.top, 16)

                            if let msg = errorMessage {
                                Text(msg)
                                    .font(F.body(12, italic: true))
                                    .foregroundStyle(P.vermillion)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 12)
                            }

                            inviteHint

                            if !isJoiningInvite {
                                inviteLinkButton
                            }

                            compareButton
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $showingCamera) { side in
                CameraPicker(image: side == .left ? $leftImage : $rightImage)
                    .ignoresSafeArea()
            }
            .sheet(item: $inviteShareItem) { item in
                ShareSheet(items: item.activityItems)
            }
            .fullScreenCover(isPresented: $showingResult) {
                if let match, let left = leftImage, let right = rightImage {
                    NavigationStack {
                        MatchResultView(match: match,
                                        leftPhoto: left,
                                        rightPhoto: right,
                                        diagram: diagram,
                                        shareURL: matchShareURL)
                    }
                }
            }
            .onChange(of: leftPickerItem) { item in
                Task { if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) { leftImage = img } }
            }
            .onChange(of: rightPickerItem) { item in
                Task { if let d = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: d) { rightImage = img } }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(text: isJoiningInvite ? "Join Compare" : "Compare Palms")
            Text(isJoiningInvite ? "Their hand," : "Two hands,")
                .font(F.display(36))
                .foregroundStyle(P.ink)
            Text(isJoiningInvite ? "your rhythm." : "one rhythm.")
                .font(F.display(36, italic: true))
                .foregroundStyle(P.vermillion)
            Text(isJoiningInvite
                 ? "Your match is waiting. Add your palm to reveal the comparison."
                 : "Snap your palm and theirs. We'll read how they speak to each other.")
                .font(F.body(14, italic: true))
                .foregroundStyle(P.inkMuted)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var photoPair: some View {
        HStack(spacing: 10) {
            if isJoiningInvite {
                inviteHostSlot
            } else {
                photoSlot(image: leftImage,
                          label: leftLabel.isEmpty ? "You" : leftLabel,
                          pickerItem: $leftPickerItem,
                          cameraSide: .left)
            }

            ZStack {
                Rectangle().frame(width: 0.5).foregroundStyle(P.rule)
                ZStack {
                    Circle().fill(P.paper).frame(width: 28, height: 28)
                    Circle().stroke(P.vermillion, lineWidth: 0.8).frame(width: 28, height: 28)
                    Text("&")
                        .font(F.display(16, italic: true))
                        .foregroundStyle(P.vermillion)
                }
            }

            photoSlot(image: rightImage,
                      label: isJoiningInvite ? "You" : (rightLabel.isEmpty ? "Them" : rightLabel),
                      pickerItem: $rightPickerItem,
                      cameraSide: .right)
        }
    }

    private var nameFields: some View {
        Group {
            if isJoiningInvite {
                nameField(title: "Your name", text: $rightLabel, placeholder: "Add a name")
            } else {
                HStack(spacing: 10) {
                    nameField(title: "Your name", text: $leftLabel)
                    nameField(title: "Their name", text: $rightLabel, placeholder: "Add a name")
                }
            }
        }
    }

    private var inviteHint: some View {
        HStack(spacing: 8) {
            Circle().fill(P.vermillion).frame(width: 6, height: 6)
            Text(isJoiningInvite
                 ? "This invite links your palm to the scan they already shared."
                 : "Send an invite link instead — they scan on their phone and get the same match flow.")
                .font(F.body(12, italic: true))
                .foregroundStyle(P.inkSoft)
        }
        .padding(14)
        .background(P.paperDeep)
        .overlay(Rectangle().stroke(P.rule, lineWidth: 0.5))
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var inviteLinkButton: some View {
        Button {
            Task { await createInviteLink() }
        } label: {
            HStack(spacing: 8) {
                if isCreatingInvite { ProgressView().tint(P.ink) }
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .light))
                Text(isCreatingInvite ? "Preparing Invite…" : "Send Invite Link")
                    .font(F.mono(11))
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .overlay(Rectangle().stroke(canCreateInvite ? P.ink : P.inkFaded, lineWidth: 0.8))
            .foregroundStyle(canCreateInvite ? P.ink : P.inkFaded)
        }
        .disabled(!canCreateInvite || isCreatingInvite)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var compareButton: some View {
        Button {
            Task { await runCompare() }
        } label: {
            HStack(spacing: 8) {
                if isAnalyzing { ProgressView().tint(P.paperBright) }
                Text(compareButtonTitle)
                    .font(F.mono(12))
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(canCompare ? P.ink : P.inkFaded)
            .foregroundStyle(P.paperBright)
        }
        .disabled(!canCompare || isAnalyzing)
    }

    private var compareButtonTitle: String {
        if isAnalyzing { return "Reading both hands…" }
        return isJoiningInvite ? "Join & Compare Palms" : "Compare Palms"
    }

    private var inviteHostSlot: some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle().stroke(P.ink, lineWidth: 0.8).background(P.paperBright)
                VStack(spacing: 8) {
                    PalmEngraving(size: 70, strokeColor: P.rule, lineColor: P.rule, showLines: false)
                    Text("Their palm")
                        .font(F.body(12, italic: true))
                        .foregroundStyle(P.inkFaded)
                    Text("Already attached")
                        .font(F.mono(8))
                        .tracking(1.4)
                        .foregroundStyle(P.vermillion)
                }
                .frame(height: 180)

                VStack { EyebrowText(text: "Them").padding(8); Spacer() }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 180)

            Text("Invite")
                .font(F.mono(9))
                .tracking(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(Rectangle().stroke(P.inkFaded, lineWidth: 0.8))
                .foregroundStyle(P.inkFaded)
        }
    }

    private func photoSlot(image: UIImage?,
                           label: String,
                           pickerItem: Binding<PhotosPickerItem?>,
                           cameraSide: Side) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle().stroke(P.ink, lineWidth: 0.8).background(P.paperBright)

                if let image {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 180).clipped()
                } else {
                    VStack(spacing: 8) {
                        PalmEngraving(size: 70, strokeColor: P.rule, lineColor: P.rule, showLines: false)
                        Text(label).font(F.body(12, italic: true)).foregroundStyle(P.inkFaded)
                    }
                    .frame(height: 180)
                }

                // corner brackets
                GeometryReader { g in
                    let len: CGFloat = 10
                    ForEach(["tl","tr","bl","br"], id: \.self) { c in
                        Path { p in
                            let x = c.contains("l") ? 0.0 : g.size.width - len
                            let y = c.contains("t") ? 0.0 : g.size.height - len
                            if c == "tl" { p.move(to:.init(x:x+len,y:y)); p.addLine(to:.init(x:x,y:y)); p.addLine(to:.init(x:x,y:y+len)) }
                            else if c == "tr" { p.move(to:.init(x:x,y:y)); p.addLine(to:.init(x:x+len,y:y)); p.addLine(to:.init(x:x+len,y:y+len)) }
                            else if c == "bl" { p.move(to:.init(x:x,y:y)); p.addLine(to:.init(x:x,y:y+len)); p.addLine(to:.init(x:x+len,y:y+len)) }
                            else { p.move(to:.init(x:x,y:y+len)); p.addLine(to:.init(x:x+len,y:y+len)); p.addLine(to:.init(x:x+len,y:y)) }
                        }.stroke(P.vermillion, style: StrokeStyle(lineWidth: 1.5))
                    }
                }

                VStack { EyebrowText(text: label).padding(8); Spacer() }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 180)

            HStack(spacing: 6) {
                Button { showingCamera = cameraSide } label: {
                    Text("Camera".uppercased()).font(F.mono(9)).tracking(2)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(P.ink).foregroundStyle(P.paperBright)
                }
                PhotosPicker(selection: pickerItem, matching: .images) {
                    Text("Library".uppercased()).font(F.mono(9)).tracking(2)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .overlay(Rectangle().stroke(P.ink, lineWidth: 0.8))
                        .foregroundStyle(P.ink)
                }.buttonStyle(.plain)
            }
        }
    }

    private func nameField(title: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowText(text: title)
            TextField(placeholder, text: text)
                .font(F.display(22))
                .foregroundStyle(P.ink)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().frame(height: 0.8).foregroundStyle(P.ink)
                }
        }
    }

    private var canCreateInvite: Bool {
        !isJoiningInvite && leftImage != nil
    }

    private var canCompare: Bool {
        isJoiningInvite ? rightImage != nil : (leftImage != nil && rightImage != nil)
    }

    private func createInviteLink() async {
        guard let left = leftImage else { return }
        errorMessage = nil
        isCreatingInvite = true
        defer { isCreatingInvite = false }

        do {
            let label = leftLabel.isEmpty ? "You" : leftLabel
            let invite = try await openAI.createCompareInvite(left: left,
                                                              leftLabel: label,
                                                              identityToken: auth.identityToken)
            let text = "Compare your palm with mine in \(Config.appDisplayName): \(invite.shareURL.absoluteString)"
            inviteShareItem = ShareItem(activityItems: [text, invite.shareURL])
        } catch {
            errorMessage = "Invite failed: \(error.localizedDescription)"
        }
    }

    private func runCompare() async {
        errorMessage = nil
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            if let inviteToken {
                try await joinInviteAndCompare(inviteToken)
            } else {
                try await compareBothLocalPhotos()
            }
        } catch {
            errorMessage = "Comparison failed: \(error.localizedDescription)"
        }
    }

    private func compareBothLocalPhotos() async throws {
        guard let left = leftImage, let right = rightImage else { return }
        let lLabel = leftLabel.isEmpty ? "You" : leftLabel
        let rLabel = rightLabel.isEmpty ? "Them" : rightLabel
        let result = try await openAI.analyzeMatch(left: left,
                                                   right: right,
                                                   leftLabel: lLabel,
                                                   rightLabel: rLabel,
                                                   identityToken: auth.identityToken)
        var img: UIImage? = nil
        do {
            img = try await openAI.generateDiagram(prompt: result.imagePrompt,
                                                   size: "1536x1024",
                                                   identityToken: auth.identityToken)
        } catch { }
        match = result
        diagram = img
        matchShareURL = nil
        showingResult = true
    }

    private func joinInviteAndCompare(_ token: String) async throws {
        guard let right = rightImage else { return }
        let rLabel = rightLabel.isEmpty ? "You" : rightLabel
        let result = try await openAI.joinCompareInvite(token: token,
                                                        right: right,
                                                        rightLabel: rLabel,
                                                        identityToken: auth.identityToken)
        var img: UIImage? = nil
        do {
            img = try await openAI.generateDiagram(prompt: result.match.imagePrompt,
                                                   size: "1536x1024",
                                                   identityToken: auth.identityToken)
        } catch { }
        leftImage = result.leftPhoto ?? right
        match = result.match
        diagram = img
        matchShareURL = result.shareURL
        showingResult = true
    }
}
