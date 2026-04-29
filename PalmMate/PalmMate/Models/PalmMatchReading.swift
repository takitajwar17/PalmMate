import Foundation

/// Result of a "Compare Palms" reading. Distinct from `PalmReading` because
/// the artifact is fundamentally different (compatibility, dynamics).
struct PalmMatchReading: Codable, Hashable {
    let title: String           // "Palm Match"
    let subtitle: String        // "How your hands speak to each other."
    let leftLabel: String       // "You"
    let rightLabel: String      // partner / friend label

    let atAGlance: String       // 2–3 sentence headline of the match

    let compatibilityScore: Int // 0–100
    let scoreLabel: String      // "Cosmic Match", "Slow Burn", "Twin Flames"…
    let scoreSummary: String

    let dynamics: Dynamics
    let advice: String
    let closingNote: String

    let imagePrompt: String     // two-palm contour artwork prompt

    struct Dynamics: Codable, Hashable {
        let love: String              // heart-line interplay
        let communication: String     // head-line interplay
        let energy: String            // life-line interplay
        let direction: String         // fate / sun lines
        let sharedStrengths: String
        let frictionPoints: String
    }
}

extension PalmMatchReading {
    static func parse(_ raw: String) -> PalmMatchReading? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if s.hasSuffix("```") { s.removeLast(3) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PalmMatchReading.self, from: data)
    }
}
