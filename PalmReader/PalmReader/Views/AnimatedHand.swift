import SwiftUI

/// Animated palm engraving — subtle float animation.
struct AnimatedHand: View {
    var size: CGFloat = 110
    @State private var float = false

    var body: some View {
        PalmEngraving(size: size, strokeColor: P.ink, lineColor: P.vermillion)
            .offset(y: float ? -6 : 6)
            .animation(
                .easeInOut(duration: 3.2).repeatForever(autoreverses: true),
                value: float
            )
            .onAppear { float = true }
    }
}
