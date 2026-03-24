//
//  NaviolaPinnedItems.swift
//  Radiola
//
//  Naviola — Generalized pinned items with JSON persistence.
//  Replaces OPML-based pin approach. Stores Subsonic IDs,
//  resolves to tracks at play time.
//

import Foundation

// MARK: - NaviolaPinnedItem

struct NaviolaPinnedItem: Codable, Identifiable {
    let id: UUID
    let type: PinnedItemType
    let title: String
    let subtitle: String?
    let subsonicId: String
    let coverArtId: String?
    let dateAdded: Date

    enum PinnedItemType: String, Codable {
        case album
        case artist
        case genre
        case track
        case playlist
    }

    init(type: PinnedItemType, title: String, subtitle: String? = nil, subsonicId: String, coverArtId: String? = nil) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.subsonicId = subsonicId
        self.coverArtId = coverArtId
        self.dateAdded = Date()
    }
}

// MARK: - NaviolaPinnedItemStore

class NaviolaPinnedItemStore: ObservableObject {
    static let shared = NaviolaPinnedItemStore()

    @Published var items: [NaviolaPinnedItem] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.naviola", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        fileURL = dir.appendingPathComponent("pinned.json")
        load()
    }

    /// Init with explicit file URL (for testing).
    init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    // MARK: - CRUD

    func add(_ item: NaviolaPinnedItem) {
        guard !isPinned(subsonicId: item.subsonicId) else { return }
        items.append(item)
        save()
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func remove(subsonicId: String) {
        items.removeAll { $0.subsonicId == subsonicId }
        save()
    }

    func isPinned(subsonicId: String) -> Bool {
        return items.contains { $0.subsonicId == subsonicId }
    }

    func item(forSubsonicId id: String) -> NaviolaPinnedItem? {
        return items.first { $0.subsonicId == id }
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([NaviolaPinnedItem].self, from: data)
        } catch {
            warning("Failed to load pinned items: \(error)")
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            warning("Failed to save pinned items: \(error)")
        }
    }
}
