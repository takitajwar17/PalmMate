import SwiftUI

struct LockedSection<Content: View>: View {
    let isLocked: Bool
    let onUnlockRequested: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()
                .blur(radius: isLocked ? 5 : 0)
                .allowsHitTesting(!isLocked)

            if isLocked {
                SealOverlay(onTap: onUnlockRequested)
            }
        }
    }
}

private struct SealOverlay: View {
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            StampBadge(text: "Sealed · Vol I")

            Text("The rest is\nunder seal.")
                .font(F.display(22))
                .foregroundStyle(P.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(-1)

            Text("Major lines · features · your path")
                .font(F.body(12, italic: true))
                .foregroundStyle(P.inkMuted)

            Button(action: onTap) {
                Text("Break the seal".uppercased())
                    .font(F.mono(11))
                    .tracking(2)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(P.vermillion)
                    .foregroundStyle(P.paperBright)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .background(P.paperBright)
        .overlay(Rectangle().stroke(P.ink, lineWidth: 0.8))
        .shadow(color: P.ink.opacity(0.10), radius: 16, y: 4)
        .padding(.horizontal, 20)
    }
}
