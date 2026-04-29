import Foundation

enum SkillLoader {
    /// Bundled palm-reading system prompt for solo readings.
    static func loadPalmReadingSkill() -> String {
        loadResource(named: "PalmReadingSkill",
                     fallback: "You are a master palmist. Give a detailed, compassionate palm reading for the photo provided.")
    }

    /// Bundled palm-compare system prompt for two-palm readings.
    static func loadPalmCompareSkill() -> String {
        loadResource(named: "PalmCompareSkill",
                     fallback: "You are a master palmist. Compare two palms and produce a structured compatibility reading.")
    }

    private static func loadResource(named name: String, fallback: String) -> String {
        if let url = Bundle.main.url(forResource: name, withExtension: "md"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return fallback
    }
}
