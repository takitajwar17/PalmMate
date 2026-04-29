import SwiftUI

struct MatchResultView: View {
    let match: PalmMatchReading
    let leftPhoto: UIImage
    let rightPhoto: UIImage
    let diagram: UIImage?
    let shareURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: ShareItem?

    init(match: PalmMatchReading,
         leftPhoto: UIImage,
         rightPhoto: UIImage,
         diagram: UIImage?,
         shareURL: URL? = nil) {
        self.match = match
        self.leftPhoto = leftPhoto
        self.rightPhoto = rightPhoto
        self.diagram = diagram
        self.shareURL = shareURL
    }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    titleBlock
                    scoreCard
                    photosCard
                    diagramCard
                    atAGlanceCard
                    sectionDivider("THE DYNAMICS")
                    dynamicsGrid
                    adviceCard
                    closing
                    shareButton
                }
                .padding(20)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("‹ Done")
                        .font(F.mono(11))
                        .foregroundStyle(P.ink)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.activityItems)
        }
    }

    // MARK: - Pieces

    private var titleBlock: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                EyebrowText(text: "Compatibility reading", color: P.vermillion)
                Text(match.title)
                    .font(F.display(40))
                    .foregroundStyle(P.ink)
                    .lineSpacing(-2)
                Text(match.subtitle)
                    .font(F.body(15, italic: true))
                    .foregroundStyle(P.inkMuted)
                    .padding(.top, 2)
            }
            Spacer()
            StarSealView(size: 40)
        }
    }

    private var scoreCard: some View {
        EditorialCard {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .strokeBorder(EditorialPaper.gold.opacity(0.45), lineWidth: 1)
                    VStack(spacing: 0) {
                        Text("\(match.compatibilityScore)")
                            .font(.system(size: 38, weight: .regular, design: .serif))
                            .foregroundStyle(EditorialPaper.ink)
                        Text("/ 100")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(EditorialPaper.inkMuted)
                    }
                }
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 4) {
                    Text(match.scoreLabel.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(EditorialPaper.gold)
                    Text(match.scoreSummary)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(EditorialPaper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var photosCard: some View {
        HStack(spacing: 12) {
            photoTile(image: leftPhoto, label: match.leftLabel)
            photoTile(image: rightPhoto, label: match.rightLabel)
        }
    }

    private func photoTile(image: UIImage, label: String) -> some View {
        VStack(spacing: 6) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(EditorialPaper.cardStroke, lineWidth: 0.6)
                )
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(EditorialPaper.inkMuted)
        }
    }

    private var diagramCard: some View {
        EditorialCard {
            VStack(spacing: 8) {
                Text("YOUR PALMS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(EditorialPaper.inkMuted)
                if let diagram {
                    Image(uiImage: diagram)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                } else {
                    HStack(spacing: 28) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 50, weight: .ultraLight))
                            .foregroundStyle(EditorialPaper.inkMuted)
                        Image(systemName: "hand.raised")
                            .font(.system(size: 50, weight: .ultraLight))
                            .foregroundStyle(EditorialPaper.inkMuted)
                            .scaleEffect(x: -1, y: 1)
                    }
                    .frame(height: 160)
                }
            }
        }
    }

    private var atAGlanceCard: some View {
        EditorialCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sun.max")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(EditorialPaper.gold)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("AT A GLANCE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(EditorialPaper.inkMuted)
                    Text(match.atAGlance)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(EditorialPaper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func sectionDivider(_ title: String) -> some View {
        HStack(spacing: 12) {
            Rectangle().frame(height: 0.5).foregroundStyle(EditorialPaper.rule)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(EditorialPaper.ink)
            Rectangle().frame(height: 0.5).foregroundStyle(EditorialPaper.rule)
        }
    }

    private var dynamicsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            dynamicsCard(icon: "heart",            title: "LOVE",            body: match.dynamics.love)
            dynamicsCard(icon: "bubble.left.and.bubble.right", title: "COMMUNICATION", body: match.dynamics.communication)
            dynamicsCard(icon: "bolt",             title: "ENERGY",          body: match.dynamics.energy)
            dynamicsCard(icon: "location.north.line", title: "DIRECTION",    body: match.dynamics.direction)
            dynamicsCard(icon: "sparkles",         title: "SHARED STRENGTHS", body: match.dynamics.sharedStrengths)
            dynamicsCard(icon: "triangle",         title: "FRICTION",        body: match.dynamics.frictionPoints)
        }
    }

    private func dynamicsCard(icon: String, title: String, body: String) -> some View {
        EditorialCard {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(EditorialPaper.ink)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(EditorialPaper.rule, lineWidth: 0.6))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(EditorialPaper.ink)
                Text(body)
                    .font(.system(size: 11, design: .serif))
                    .foregroundStyle(EditorialPaper.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var adviceCard: some View {
        EditorialCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "compass.drawing")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(EditorialPaper.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADVICE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(EditorialPaper.ink)
                    Text(match.advice)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(EditorialPaper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var closing: some View {
        Text(match.closingNote)
            .font(.system(.body, design: .serif).italic())
            .foregroundStyle(EditorialPaper.inkMuted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    private var shareButton: some View {
        Button {
            if let img = ImageExporter.makeMatchShareImage(left: leftPhoto,
                                                            right: rightPhoto,
                                                            diagram: diagram,
                                                            match: match) {
                let url = shareURL ?? Config.appShareBaseURL
                let text = "I just compared our palms with \(Config.appDisplayName) — see your match: \(url.absoluteString)"
                shareItem = ShareItem(activityItems: [img, text])
            }
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Send to Your Match")
                    .font(.system(.headline, design: .serif))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(EditorialPaper.ink)
            .foregroundStyle(EditorialPaper.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
