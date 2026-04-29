import SwiftUI
import UIKit

/// Renders shareable images for both solo and match readings.
enum ImageExporter {

    enum SoloStyle {
        /// Subscriber's full editorial poster (the long page).
        case full
        /// Free user's teaser card — photo + diagram + at-a-glance + CTA.
        case teaser
    }

    @MainActor
    static func makeShareImage(photo: UIImage,
                               diagram: UIImage?,
                               reading: PalmReading,
                               style: SoloStyle) -> UIImage? {
        let view: AnyView
        let frame: CGSize
        switch style {
        case .full:
            view = AnyView(FullSoloPoster(photo: photo, diagram: diagram, reading: reading))
            frame = CGSize(width: 1200, height: 1800)
        case .teaser:
            view = AnyView(TeaserSoloPoster(photo: photo, diagram: diagram, reading: reading))
            frame = CGSize(width: 1080, height: 1350)
        }
        let renderer = ImageRenderer(content: view.frame(width: frame.width, height: frame.height))
        renderer.scale = 2
        return renderer.uiImage
    }

    @MainActor
    static func makeMatchShareImage(left: UIImage,
                                    right: UIImage,
                                    diagram: UIImage?,
                                    match: PalmMatchReading) -> UIImage? {
        let view = MatchPoster(left: left, right: right, diagram: diagram, match: match)
            .frame(width: 1080, height: 1350)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }
}

// MARK: - Full subscriber poster (existing layout)

private struct FullSoloPoster: View {
    let photo: UIImage
    let diagram: UIImage?
    let reading: PalmReading

    var body: some View {
        ZStack {
            EditorialPaper.paper

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reading.title.uppercased())
                            .font(.system(size: 56, weight: .regular, design: .serif))
                            .foregroundStyle(EditorialPaper.ink)
                        Text(reading.subtitle)
                            .font(.system(size: 20, design: .serif).italic())
                            .foregroundStyle(EditorialPaper.inkMuted)
                        Rectangle().frame(width: 60, height: 1).foregroundStyle(EditorialPaper.gold)
                    }
                    Spacer()
                    ConstellationMark(size: 64)
                }

                posterCard {
                    HStack(alignment: .top, spacing: 18) {
                        Image(systemName: "sun.max")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(EditorialPaper.gold)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AT A GLANCE")
                                .font(.system(size: 16, weight: .semibold))
                                .tracking(3)
                                .foregroundStyle(EditorialPaper.ink)
                            Text(reading.atAGlance)
                                .font(.system(size: 22, design: .serif))
                                .foregroundStyle(EditorialPaper.ink)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 18) {
                    posterCard(padding: 0) {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 540, height: 480)
                            .clipped()
                    }
                    posterCard {
                        VStack(spacing: 8) {
                            Text("YOUR PALM LINES")
                                .font(.system(size: 16, weight: .semibold))
                                .tracking(3)
                                .foregroundStyle(EditorialPaper.inkMuted)
                            Group {
                                if let diagram {
                                    Image(uiImage: diagram)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: "hand.raised")
                                        .font(.system(size: 160, weight: .ultraLight))
                                        .foregroundStyle(EditorialPaper.inkMuted)
                                }
                            }
                            .frame(height: 320)

                            VStack(alignment: .leading, spacing: 6) {
                                line("HEART LINE", reading.palmLines.heartLine)
                                line("HEAD LINE",  reading.palmLines.headLine)
                                line("LIFE LINE",  reading.palmLines.lifeLine)
                                line("FATE LINE",  reading.palmLines.fateLine)
                                line("SUN LINE",   reading.palmLines.sunLine)
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    ForEach(Array(reading.majorLines.ordered.enumerated()), id: \.offset) { _, item in
                        lineCard(name: item.key, card: item.card)
                    }
                }

                Spacer()
                BrandFooter()
            }
            .padding(56)
        }
        .frame(width: 1200, height: 1800)
    }

    private func line(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(key).font(.system(size: 12, weight: .semibold)).tracking(1.6)
                .foregroundStyle(EditorialPaper.inkMuted)
                .frame(width: 110, alignment: .leading)
            Text(value).font(.system(size: 14, design: .serif)).foregroundStyle(EditorialPaper.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func lineCard(name: String, card: PalmReading.LineCard) -> some View {
        posterCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: iconFor(line: name))
                    .font(.system(size: 16, weight: .light))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(EditorialPaper.rule, lineWidth: 0.6))
                Text(name.uppercased())
                    .font(.system(size: 12, weight: .semibold)).tracking(1.6)
                    .foregroundStyle(EditorialPaper.ink)
                Text(card.subtitle)
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundStyle(EditorialPaper.inkMuted)
                ForEach(card.bullets, id: \.self) { b in
                    HStack(alignment: .top, spacing: 4) {
                        Text("•").foregroundStyle(EditorialPaper.inkMuted)
                        Text(b).font(.system(size: 11, design: .serif)).foregroundStyle(EditorialPaper.ink)
                    }
                }
                Text(card.summary)
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundStyle(EditorialPaper.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func iconFor(line: String) -> String {
        switch line {
        case "Heart Line": return "heart"
        case "Head Line":  return "brain.head.profile"
        case "Life Line":  return "shield"
        case "Fate Line":  return "flag"
        case "Sun Line":   return "sun.max"
        default: return "sparkles"
        }
    }
}

// MARK: - Free user teaser (no locked content shown)

private struct TeaserSoloPoster: View {
    let photo: UIImage
    let diagram: UIImage?
    let reading: PalmReading

    var body: some View {
        ZStack {
            EditorialPaper.paper

            VStack(spacing: 28) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PALM READING")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(3)
                            .foregroundStyle(EditorialPaper.gold)
                        Text("I read my palm.")
                            .font(.system(size: 56, weight: .regular, design: .serif))
                            .foregroundStyle(EditorialPaper.ink)
                    }
                    Spacer()
                    ConstellationMark(size: 56)
                }
                .padding(.horizontal, 56)
                .padding(.top, 56)

                HStack(spacing: 18) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 420, height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Group {
                        if let diagram {
                            Image(uiImage: diagram)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 200, weight: .ultraLight))
                                .foregroundStyle(EditorialPaper.inkMuted)
                        }
                    }
                    .frame(width: 420, height: 420)
                    .background(EditorialPaper.cardFill)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(EditorialPaper.cardStroke, lineWidth: 0.8)
                    )
                }
                .padding(.horizontal, 56)

                Text(reading.atAGlance)
                    .font(.system(size: 26, design: .serif).italic())
                    .foregroundStyle(EditorialPaper.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 90)

                Spacer()

                VStack(spacing: 6) {
                    Text("Read yours →")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(EditorialPaper.ink)
                    Text("palmistry.app")
                        .font(.system(size: 18, design: .serif).italic())
                        .foregroundStyle(EditorialPaper.inkMuted)
                }

                BrandFooter()
                    .padding(.horizontal, 56)
                    .padding(.bottom, 56)
            }
        }
        .frame(width: 1080, height: 1350)
    }
}

// MARK: - Match poster

private struct MatchPoster: View {
    let left: UIImage
    let right: UIImage
    let diagram: UIImage?
    let match: PalmMatchReading

    var body: some View {
        ZStack {
            EditorialPaper.paper

            VStack(spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PALM MATCH")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(3)
                            .foregroundStyle(EditorialPaper.gold)
                        Text(match.scoreLabel)
                            .font(.system(size: 56, weight: .regular, design: .serif))
                            .foregroundStyle(EditorialPaper.ink)
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(match.compatibilityScore)")
                            .font(.system(size: 60, weight: .regular, design: .serif))
                            .foregroundStyle(EditorialPaper.ink)
                        Text("/ 100")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(EditorialPaper.inkMuted)
                    }
                    .padding(20)
                    .overlay(
                        Circle().strokeBorder(EditorialPaper.gold.opacity(0.5), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 56)
                .padding(.top, 56)

                HStack(spacing: 16) {
                    palmTile(image: left, label: match.leftLabel)
                    palmTile(image: right, label: match.rightLabel)
                }
                .padding(.horizontal, 56)

                Text(match.atAGlance)
                    .font(.system(size: 22, design: .serif).italic())
                    .foregroundStyle(EditorialPaper.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 90)

                if let diagram {
                    Image(uiImage: diagram)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .padding(.horizontal, 56)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("Compare your palms with your match →")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(EditorialPaper.ink)
                    Text("palmistry.app")
                        .font(.system(size: 16, design: .serif).italic())
                        .foregroundStyle(EditorialPaper.inkMuted)
                }

                BrandFooter()
                    .padding(.horizontal, 56)
                    .padding(.bottom, 56)
            }
        }
        .frame(width: 1080, height: 1350)
    }

    private func palmTile(image: UIImage, label: String) -> some View {
        VStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 460, height: 460)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(EditorialPaper.cardStroke, lineWidth: 0.8)
                )
            Text(label.uppercased())
                .font(.system(size: 14, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(EditorialPaper.inkMuted)
        }
    }
}

// MARK: - Shared

private struct BrandFooter: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.raised.fingers.spread.fill")
                .font(.system(size: 30))
                .foregroundStyle(EditorialPaper.ink)
            VStack(alignment: .leading, spacing: 1) {
                Text("PALMISTRY")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .tracking(2)
                    .foregroundStyle(EditorialPaper.ink)
                Text("Read your palm with AI")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundStyle(EditorialPaper.inkMuted)
            }
            Spacer()
            ConstellationMark(size: 32)
        }
    }
}

private func posterCard<Content: View>(padding: CGFloat = 18,
                                       @ViewBuilder _ content: () -> Content) -> some View {
    content()
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(EditorialPaper.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(EditorialPaper.cardStroke, lineWidth: 0.8)
        )
}
