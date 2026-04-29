import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ReadingStore

    @State private var openReading: LoadedReading?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()

                VStack(spacing: 0) {
                    // Header bar
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(P.ink)
                        }
                        Spacer()
                        EyebrowText(text: "Archive")
                        Spacer()
                        Color.clear.frame(width: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    HairlineRule()
                        .padding(.horizontal, 20)

                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowText(text: "Your Scrolls", color: P.vermillion)
                            .padding(.top, 20)
                        Text(scrollsTitle)
                            .font(F.display(44))
                            .foregroundStyle(P.ink)
                            .lineSpacing(-2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    if store.saved.isEmpty {
                        emptyState
                    } else {
                        scrollList
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(item: $openReading) { loaded in
            NavigationStack {
                ResultView(palmPhoto: loaded.photo,
                           reading: loaded.reading,
                           diagram: loaded.diagram,
                           readingID: loaded.id)
            }
        }
    }

    private var scrollsTitle: String {
        let n = store.saved.count
        if n == 0 { return "No readings\nyet." }
        let words = ["Zero", "One", "Two", "Three", "Four", "Five",
                     "Six", "Seven", "Eight", "Nine", "Ten"]
        let word = n < words.count ? words[n] : "\(n)"
        return "\(word)\nreading\(n == 1 ? "" : "s"), kept."
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            PalmEngraving(size: 80, strokeColor: P.inkFaded,
                          lineColor: P.inkFaded, showLines: false)
            Text("No readings yet")
                .font(F.display(24, italic: true))
                .foregroundStyle(P.inkMuted)
            Text("Take your first palm photo and\nyour reading will land here.")
                .font(F.body(15, italic: true))
                .foregroundStyle(P.inkFaded)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var scrollList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.saved.enumerated()), id: \.element.id) { i, entry in
                    Button {
                        openReading = store.load(entry.id)
                    } label: {
                        HistoryRow(entry: entry, index: i)
                    }
                    .buttonStyle(.plain)
                    .background(i == 0 ? P.vermillion.opacity(0.03) : .clear)

                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(P.ruleSoft)
                        .padding(.leading, 24)
                }
            }
            .padding(.top, 20)
        }
    }
}

private struct HistoryRow: View {
    let entry: SavedReading
    let index: Int

    private var readingNumber: String {
        String(format: "%04d", index + 1)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left icon / number
            PalmEngraving(size: 42, strokeColor: P.ink, lineColor: P.vermillion, hatch: false)
                .frame(width: 44, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("№ \(readingNumber)")
                        .font(F.mono(9))
                        .foregroundStyle(P.vermillion)
                    Spacer()
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(F.mono(9))
                        .foregroundStyle(P.inkFaded)
                }

                Text(entry.title)
                    .font(F.display(19))
                    .foregroundStyle(P.ink)
                    .lineSpacing(-1)
                    .multilineTextAlignment(.leading)

                Text(entry.atAGlance)
                    .font(F.body(13, italic: true))
                    .foregroundStyle(P.inkMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

extension LoadedReading: Identifiable {}
