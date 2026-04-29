import Foundation

/// Editorial palm-reading guide. Mirrors the schema in PalmReadingSkill.md.
struct PalmReading: Codable, Hashable {
    let title: String
    let subtitle: String
    let dominantHand: String?

    let atAGlance: String

    let palmLines: PalmLines

    let majorLines: MajorLines

    let palmFeatures: PalmFeatures

    let whatThisMeansForYou: WhatThisMeansForYou

    let yourPath: String
    let closingNote: String

    let imagePrompt: String

    struct PalmLines: Codable, Hashable {
        let heartLine: String
        let headLine: String
        let lifeLine: String
        let fateLine: String
        let sunLine: String
    }

    struct LineCard: Codable, Hashable {
        let subtitle: String
        let bullets: [String]
        let summary: String
    }

    struct MajorLines: Codable, Hashable {
        let heartLine: LineCard
        let headLine: LineCard
        let lifeLine: LineCard
        let fateLine: LineCard
        let sunLine: LineCard

        var ordered: [(key: String, card: LineCard)] {
            [
                ("Heart Line", heartLine),
                ("Head Line", headLine),
                ("Life Line", lifeLine),
                ("Fate Line", fateLine),
                ("Sun Line", sunLine)
            ]
        }
    }

    struct PalmFeatures: Codable, Hashable {
        let palmShape: String
        let fingers: String
        let thumb: String
        let mounts: String
    }

    struct WhatThisMeansForYou: Codable, Hashable {
        let strengths: String
        let challenges: String
        let love: String
        let career: String
        let guidance: String
    }
}

extension PalmReading {
    /// Best-effort parse. The model is asked to return raw JSON; we strip
    /// fences if anything sneaks them in.
    static func parse(_ raw: String) -> PalmReading? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if s.hasSuffix("```") { s.removeLast(3) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PalmReading.self, from: data)
    }
}
