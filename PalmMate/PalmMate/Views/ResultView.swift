import SwiftUI

struct ResultView: View {
    let palmPhoto: UIImage
    let reading: PalmReading
    let diagram: UIImage?
    let readingID: UUID

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchases: PurchaseManager

    @State private var shareItem: ShareItem?
    @State private var showingPaywall = false

    private var isUnlocked: Bool {
        purchases.isUnlocked(readingID: readingID)
    }

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(spacing: 22) {
                    // Top bar
                    HStack {
                        Button { dismiss() } label: {
                            Text("‹ Done")
                                .font(F.mono(11))
                                .foregroundStyle(P.ink)
                                .tracking(2)
                        }
                        Spacer()
                        EyebrowText(text: "Reading № 0001")
                        Spacer()
                        Button { share() } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(P.ink)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    HairlineRule().padding(.horizontal, 20)

                    // Title — compact
                    VStack(alignment: .leading, spacing: 4) {
                        EyebrowText(text: "An editorial reading", color: P.vermillion)
                        Text(reading.title)
                            .font(F.display(38))
                            .foregroundStyle(P.ink)
                            .lineSpacing(-2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(reading.subtitle)
                            .font(F.body(14, italic: true))
                            .foregroundStyle(P.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // Photo + Diagram side by side, same size, centered
                    HStack(spacing: 10) {
                        // Photo
                        ZStack(alignment: .topLeading) {
                            GeometryReader { geo in
                                Image(uiImage: palmPhoto)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                            EyebrowText(text: "Plate I", color: .white.opacity(0.85))
                                .padding(8)
                        }
                        .aspectRatio(0.78, contentMode: .fit)
                        .overlay(Rectangle().stroke(P.ink, lineWidth: 0.8))

                        // Diagram
                        ZStack(alignment: .topLeading) {
                            P.paperBright
                            if let diagram {
                                Image(uiImage: diagram)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(6)
                            } else {
                                PalmEngraving(size: 110, strokeColor: P.ink, lineColor: P.vermillion)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            EyebrowText(text: "Plate II")
                                .padding(8)
                        }
                        .aspectRatio(0.78, contentMode: .fit)
                        .overlay(Rectangle().stroke(P.ink, lineWidth: 0.8))
                    }
                    .padding(.horizontal, 20)

                    // ─── Free preview (~40%) ─────────────────────
                    VStack(alignment: .leading, spacing: 18) {
                        // At a glance
                        atAGlanceBlock

                        // Index of Lines
                        VStack(alignment: .leading, spacing: 0) {
                            OrnamentRule(label: "Index of Lines")
                                .padding(.bottom, 4)
                            lineRow("Heart", reading.palmLines.heartLine, divider: true)
                            lineRow("Head",  reading.palmLines.headLine,  divider: true)
                            lineRow("Life",  reading.palmLines.lifeLine,  divider: true)
                            lineRow("Fate",  reading.palmLines.fateLine,  divider: false)
                        }
                    }
                    .padding(.horizontal, 20)

                    // ─── Sealed section (~60%) ───────────────────
                    if isUnlocked {
                        unlockedContent
                            .padding(.horizontal, 20)
                    } else {
                        sealedTeaser
                            .padding(.horizontal, 20)
                    }

                    // Share
                    shareButton
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Color.clear.frame(height: 30)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $shareItem) { ShareSheet(items: $0.activityItems) }
        .sheet(isPresented: $showingPaywall) { PaywallView(readingID: readingID) }
    }

    // MARK: - Free preview pieces

    private var atAGlanceBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().frame(height: 1).foregroundStyle(P.ink)
            HStack(alignment: .top, spacing: 14) {
                StarSealView(size: 36).padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    EyebrowText(text: "At a glance")
                    Text(reading.atAGlance)
                        .font(F.body(15))
                        .foregroundStyle(P.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 14)
            Rectangle().frame(height: 0.5).foregroundStyle(P.rule)
        }
    }

    private func lineRow(_ key: String, _ value: String, divider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(key.uppercased())
                    .font(F.mono(10))
                    .foregroundStyle(P.vermillion)
                    .tracking(2)
                    .frame(width: 50, alignment: .leading)
                    .padding(.top, 3)
                Text(value)
                    .font(F.body(13))
                    .foregroundStyle(P.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 7)
            if divider {
                HStack(spacing: 4) {
                    ForEach(0..<60, id: \.self) { _ in
                        Circle().fill(P.rule).frame(width: 1, height: 1)
                    }
                }
                .frame(height: 1, alignment: .center)
                .clipped()
            }
        }
    }

    // MARK: - Unlocked (full reading)

    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Major lines — 2-col grid, simplified
            VStack(alignment: .leading, spacing: 10) {
                OrnamentRule(label: "The Major Lines")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(reading.majorLines.ordered.enumerated()), id: \.offset) { _, item in
                        majorLineCard(name: item.key, card: item.card)
                    }
                }
            }

            // Palm features
            VStack(alignment: .leading, spacing: 10) {
                OrnamentRule(label: "Palm Features")
                featureLine("Shape",   reading.palmFeatures.palmShape)
                featureLine("Fingers", reading.palmFeatures.fingers)
                featureLine("Thumb",   reading.palmFeatures.thumb)
                featureLine("Mounts",  reading.palmFeatures.mounts)
            }

            // What this means for you
            VStack(alignment: .leading, spacing: 10) {
                OrnamentRule(label: "What This Means For You")
                featureLine("Strengths",  reading.whatThisMeansForYou.strengths)
                featureLine("Challenges", reading.whatThisMeansForYou.challenges)
                featureLine("Love",       reading.whatThisMeansForYou.love)
                featureLine("Career",     reading.whatThisMeansForYou.career)
                featureLine("Guidance",   reading.whatThisMeansForYou.guidance)
            }

            // Your Path
            VStack(alignment: .leading, spacing: 8) {
                OrnamentRule(label: "Your Path")
                Text(reading.yourPath)
                    .font(F.body(14))
                    .foregroundStyle(P.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(reading.closingNote)
                    .font(F.body(13, italic: true))
                    .foregroundStyle(P.inkMuted)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func majorLineCard(name: String, card: PalmReading.LineCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(text: name, color: P.vermillion)
            Text(card.subtitle)
                .font(F.body(12, italic: true))
                .foregroundStyle(P.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(card.summary)
                .font(F.body(12))
                .foregroundStyle(P.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(P.paperBright)
        .overlay(Rectangle().stroke(P.rule, lineWidth: 0.5))
    }

    private func featureLine(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key.uppercased())
                .font(F.mono(10))
                .foregroundStyle(P.vermillion)
                .tracking(2)
                .frame(width: 70, alignment: .leading)
                .padding(.top, 3)
            Text(value)
                .font(F.body(13))
                .foregroundStyle(P.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sealed teaser (one big locked block, one CTA)

    private var sealedTeaser: some View {
        ZStack {
            // The blurred preview behind
            VStack(alignment: .leading, spacing: 16) {
                OrnamentRule(label: "The Major Lines")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            Rectangle().fill(P.inkMuted).frame(height: 10).frame(width: 80)
                            Rectangle().fill(P.rule).frame(height: 6)
                            Rectangle().fill(P.rule).frame(height: 6)
                            Rectangle().fill(P.rule).frame(height: 6).frame(maxWidth: 100)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .frame(height: 110)
                        .background(P.paperBright)
                        .overlay(Rectangle().stroke(P.rule, lineWidth: 0.5))
                    }
                }

                OrnamentRule(label: "What This Means For You")
                ForEach(0..<3, id: \.self) { _ in
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle().fill(P.vermillion).frame(width: 60, height: 8)
                        VStack(alignment: .leading, spacing: 3) {
                            Rectangle().fill(P.rule).frame(height: 6)
                            Rectangle().fill(P.rule).frame(height: 6).frame(maxWidth: 200)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .blur(radius: 6)
            .allowsHitTesting(false)

            // Single overlay seal
            VStack(spacing: 14) {
                StampBadge(text: "Sealed · Vol I")
                Text("The rest is\nunder seal.")
                    .font(F.display(28))
                    .foregroundStyle(P.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)
                Text("Major lines · palm features ·\nwhat it means · your path")
                    .font(F.body(13, italic: true))
                    .foregroundStyle(P.inkMuted)
                    .multilineTextAlignment(.center)

                Button {
                    showingPaywall = true
                } label: {
                    Text("Break the Seal".uppercased())
                        .font(F.mono(11))
                        .tracking(2)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(P.vermillion)
                        .foregroundStyle(P.paperBright)
                }
                .padding(.top, 4)
            }
            .padding(28)
            .background(P.paperBright)
            .overlay(Rectangle().stroke(P.ink, lineWidth: 1))
            .shadow(color: P.ink.opacity(0.15), radius: 20, y: 8)
            .padding(.horizontal, 12)
        }
    }

    // MARK: - Share

    private func share() {
        let url = Config.soloShareURL(displayName: nil)
        let text: String
        let image: UIImage?
        if isUnlocked {
            text = "I just read my palm with \(Config.appDisplayName) — here's what it said. Read yours: \(url.absoluteString)"
            image = ImageExporter.makeShareImage(photo: palmPhoto, diagram: diagram,
                                                  reading: reading, style: .full)
        } else {
            text = "I just read my palm with \(Config.appDisplayName). Read yours: \(url.absoluteString)"
            image = ImageExporter.makeShareImage(photo: palmPhoto, diagram: diagram,
                                                  reading: reading, style: .teaser)
        }
        if let image { shareItem = ShareItem(activityItems: [image, text]) }
    }

    private var shareButton: some View {
        Button { share() } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .light))
                Text((isUnlocked ? "Share My Reading" : "Share the Teaser").uppercased())
                    .font(F.mono(11))
                    .tracking(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(P.ink)
            .foregroundStyle(P.paperBright)
        }
    }
}
