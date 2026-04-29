import Foundation
import UIKit

/// Persists palm readings to disk so the History screen can show past
/// scrolls. One reading = one folder under Documents/readings/<id>/
/// containing reading.json + photo.jpg + (optional) diagram.png.
@MainActor
final class ReadingStore: ObservableObject {
    @Published private(set) var saved: [SavedReading] = []

    init() {
        load()
    }

    // MARK: - Public API

    /// Persist a brand-new reading. Caller passes in the same `id` they
    /// gave to ResultView so the saved row matches.
    func save(reading: PalmReading,
              photo: UIImage,
              diagram: UIImage?,
              id: UUID) async {
        let dir = ReadingStore.directory(for: id)
        do {
            try FileManager.default.createDirectory(at: dir,
                                                    withIntermediateDirectories: true)

            let readingData = try JSONEncoder().encode(reading)
            try readingData.write(to: dir.appendingPathComponent("reading.json"))

            if let jpeg = photo.jpegData(compressionQuality: 0.85) {
                try jpeg.write(to: dir.appendingPathComponent("photo.jpg"))
            }
            if let diagram, let png = diagram.pngData() {
                try png.write(to: dir.appendingPathComponent("diagram.png"))
            }

            let entry = SavedReading(id: id,
                                     date: Date(),
                                     title: reading.title,
                                     atAGlance: reading.atAGlance)
            saved.insert(entry, at: 0)
            writeIndex()
        } catch {
            // Storage is best-effort; failure shouldn't block the user.
            print("ReadingStore.save failed: \(error)")
        }
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: ReadingStore.directory(for: id))
        saved.removeAll { $0.id == id }
        writeIndex()
    }

    /// Hydrate a full reading from disk for display.
    func load(_ id: UUID) -> LoadedReading? {
        let dir = ReadingStore.directory(for: id)
        guard let readingData = try? Data(contentsOf: dir.appendingPathComponent("reading.json")),
              let reading = try? JSONDecoder().decode(PalmReading.self, from: readingData),
              let photoData = try? Data(contentsOf: dir.appendingPathComponent("photo.jpg")),
              let photo = UIImage(data: photoData) else {
            return nil
        }
        let diagramData = try? Data(contentsOf: dir.appendingPathComponent("diagram.png"))
        let diagram = diagramData.flatMap(UIImage.init(data:))
        return LoadedReading(id: id, reading: reading, photo: photo, diagram: diagram)
    }

    // MARK: - Index (manifest of saved readings)

    private func writeIndex() {
        let url = ReadingStore.indexURL()
        do {
            let data = try JSONEncoder().encode(saved)
            try data.write(to: url)
        } catch {
            print("ReadingStore.writeIndex failed: \(error)")
        }
    }

    private func load() {
        let url = ReadingStore.indexURL()
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([SavedReading].self, from: data) else {
            return
        }
        saved = entries
    }

    // MARK: - Paths

    private static func documents() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func readingsRoot() -> URL {
        let dir = documents().appendingPathComponent("readings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func directory(for id: UUID) -> URL {
        readingsRoot().appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private static func indexURL() -> URL {
        readingsRoot().appendingPathComponent("index.json")
    }
}

/// Lightweight row stored in the index. The full reading lives in its
/// per-id folder and is loaded lazily.
struct SavedReading: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let title: String
    let atAGlance: String
}

/// In-memory, fully-hydrated reading for ResultView re-display.
struct LoadedReading {
    let id: UUID
    let reading: PalmReading
    let photo: UIImage
    let diagram: UIImage?
}
