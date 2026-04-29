import SwiftUI

struct PaywallView: View {
    let readingID: UUID?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchases: PurchaseManager

    init(readingID: UUID? = nil) {
        self.readingID = readingID
    }

    var body: some View {
        ZStack {
            PaperBackground()

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(P.ink)
                    }
                    .padding(.trailing, 22)
                    .padding(.top, 20)
                }
                Spacer()
            }

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 10) {
                        StampBadge(text: "One hand at a time")
                            .padding(.top, 60)

                        VStack(spacing: 0) {
                            Text("Read more")
                                .font(F.display(50))
                                .foregroundStyle(P.ink)
                            Text("hands.")
                                .font(F.display(50, italic: true))
                                .foregroundStyle(P.vermillion)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)

                        Text("3 credits = 3 full readings.\nNo subscription. No catch.")
                            .font(F.body(15, italic: true))
                            .foregroundStyle(P.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }

                    // ─── Credit pack — the main CTA ───
                    creditPackCard
                        .padding(.horizontal, 22)
                        .padding(.top, 28)

                    // Current balance
                    if purchases.credits > 0 {
                        HStack(spacing: 8) {
                            Circle().fill(P.vermillion).frame(width: 6, height: 6)
                            Text("You have \(purchases.credits) credit\(purchases.credits == 1 ? "" : "s") left")
                                .font(F.body(13, italic: true))
                                .foregroundStyle(P.inkSoft)
                        }
                        .padding(.top, 14)
                    }

                    // Divider
                    HStack(spacing: 10) {
                        Rectangle().frame(height: 0.5).foregroundStyle(P.rule)
                        Text("or")
                            .font(F.body(12, italic: true))
                            .foregroundStyle(P.inkFaded)
                        Rectangle().frame(height: 0.5).foregroundStyle(P.rule)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 28)

                    // ─── Subscription (smaller, below) ───
                    VStack(spacing: 10) {
                        subRow(title: "Monthly", sub: "Unlimited reads",
                               price: SubscriptionProduct.monthly.fallbackPriceLabel,
                               product: .monthly)
                        subRow(title: "Yearly", sub: "Unlimited reads · save 44%",
                               price: SubscriptionProduct.yearly.fallbackPriceLabel,
                               product: .yearly, bestValue: true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    // Restore + legal
                    VStack(spacing: 10) {
                        HStack(spacing: 20) {
                            Button { Task { await purchases.restore() } } label: {
                                Text("Restore")
                                    .font(F.mono(9))
                                    .tracking(2)
                                    .foregroundStyle(P.inkFaded)
                            }
                            Link("Terms", destination: Config.termsURL)
                                .font(F.mono(9))
                                .foregroundStyle(P.inkFaded)
                            Link("Privacy", destination: Config.privacyURL)
                                .font(F.mono(9))
                                .foregroundStyle(P.inkFaded)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Credit pack card

    private var creditPackCard: some View {
        Button {
            Task {
                await purchases.purchaseCreditPack()
                if let id = readingID {
                    _ = purchases.spendCredit(on: id)
                }
                dismiss()
            }
        } label: {
            VStack(spacing: 0) {
                // Top: badge
                HStack {
                    StampBadge(text: "Best for you")
                    Spacer()
                    Text(Config.creditPackPriceFallback)
                        .font(F.display(28))
                        .foregroundStyle(P.paperBright)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

                // Hands visual: 3 credits, 3 hands
                HStack(spacing: 18) {
                    PalmEngraving(size: 56, strokeColor: P.paperBright,
                                  lineColor: P.vermillion, hatch: false)
                    PalmEngraving(size: 56, strokeColor: P.paperBright,
                                  lineColor: P.vermillion, hatch: false)
                    PalmEngraving(size: 56, strokeColor: P.paperBright,
                                  lineColor: P.vermillion, hatch: false)
                }
                .padding(.bottom, 14)

                // Title
                Text("Buy 3 More Credits")
                    .font(F.display(28))
                    .foregroundStyle(P.paperBright)
                    .padding(.bottom, 4)

                Text("3 hands · \(Config.creditPackPriceFallback) · ~\(perReadingPrice) per read")
                    .font(F.body(13, italic: true))
                    .foregroundStyle(P.paperBright.opacity(0.75))
                    .padding(.bottom, 20)

                // CTA inside card
                HStack {
                    Spacer()
                    if purchases.isPurchasing {
                        ProgressView().tint(P.paperBright)
                    } else {
                        Text("Tap to unlock".uppercased())
                            .font(F.mono(11))
                            .tracking(2)
                            .foregroundStyle(P.paperBright)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(P.paperBright)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(P.vermillion.darker())
            }
            .background(P.vermillion)
        }
        .disabled(purchases.isPurchasing)
        .buttonStyle(.plain)
    }

    private var perReadingPrice: String {
        let pack = 4.49
        let per = pack / Double(PurchaseManager.creditPackSize)
        return String(format: "$%.2f", per)
    }

    // MARK: - Subscription row

    private func subRow(title: String, sub: String, price: String,
                         product: SubscriptionProduct, bestValue: Bool = false) -> some View {
        Button {
            Task {
                await purchases.purchaseSubscription(product)
                dismiss()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(F.display(20))
                            .foregroundStyle(P.ink)
                        if bestValue {
                            Text("BEST VALUE")
                                .font(F.mono(8))
                                .tracking(1.5)
                                .foregroundStyle(P.paperBright)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(P.vermillion)
                        }
                    }
                    Text(sub)
                        .font(F.body(11, italic: true))
                        .foregroundStyle(P.inkMuted)
                }
                Spacer()
                Text(price)
                    .font(F.display(18))
                    .foregroundStyle(P.ink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(Rectangle().stroke(P.rule, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(purchases.isPurchasing)
    }
}

// MARK: - Color helper

private extension Color {
    func darker(by amount: Double = 0.15) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: max(0, r - amount), green: max(0, g - amount), blue: max(0, b - amount), opacity: Double(a))
    }
}
