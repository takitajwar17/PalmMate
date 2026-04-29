import SwiftUI
import UIKit

/// Identifiable wrapper so we can present a share sheet via `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let activityItems: [Any]
}

/// UIActivityViewController bridge for SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
