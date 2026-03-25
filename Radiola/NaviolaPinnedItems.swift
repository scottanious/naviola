//
//  NaviolaPinnedItems.swift
//  Radiola
//
//  Naviola — Pinned items with group organization and JSON persistence.
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

// MARK: - NaviolaPinnedGroup

struct NaviolaPinnedGroup: Codable, Identifiable {
    let id: UUID
    var title: String
    var items: [NaviolaPinnedItem]

    init(title: String, items: [NaviolaPinnedItem] = []) {
        self.id = UUID()
        self.title = title
        self.items = items
    }
}

// MARK: - Persistence Container

/// Top-level JSON structure. Backward-compatible: if loading the old flat
/// array format fails, falls back to decoding as [NaviolaPinnedItem].
struct NaviolaPinnedData: Codable {
    var ungrouped: [NaviolaPinnedItem]
    var groups: [NaviolaPinnedGroup]
}

// MARK: - NaviolaPinnedItemStore

class NaviolaPinnedItemStore: ObservableObject {
    static let shared = NaviolaPinnedItemStore()

    @Published var ungrouped: [NaviolaPinnedItem] = []
    @Published var groups: [NaviolaPinnedGroup] = []

    /// Flat list of ALL items (ungrouped + all group members). For backward compat.
    var items: [NaviolaPinnedItem] {
        ungrouped + groups.flatMap { $0.items }
    }

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
        ungrouped.append(item)
        save()
    }

    func remove(id: UUID) {
        ungrouped.removeAll { $0.id == id }
        for i in groups.indices {
            groups[i].items.removeAll { $0.id == id }
        }
        save()
    }

    func remove(subsonicId: String) {
        ungrouped.removeAll { $0.subsonicId == subsonicId }
        for i in groups.indices {
            groups[i].items.removeAll { $0.subsonicId == subsonicId }
        }
        save()
    }

    func isPinned(subsonicId: String) -> Bool {
        return items.contains { $0.subsonicId == subsonicId }
    }

    func item(forSubsonicId id: String) -> NaviolaPinnedItem? {
        return items.first { $0.subsonicId == id }
    }

    // MARK: - Group Operations

    func addGroup(title: String) -> NaviolaPinnedGroup {
        let group = NaviolaPinnedGroup(title: title)
        groups.append(group)
        save()
        return group
    }

    func removeGroup(id: UUID) {
        if let idx = groups.firstIndex(where: { $0.id == id }) {
            // Move group's items to ungrouped
            ungrouped.append(contentsOf: groups[idx].items)
            groups.remove(at: idx)
            save()
        }
    }

    func renameGroup(id: UUID, title: String) {
        if let idx = groups.firstIndex(where: { $0.id == id }) {
            groups[idx].title = title
            save()
        }
    }

    func moveToGroup(itemId: UUID, groupId: UUID) {
        // Find and remove item from wherever it is
        var item: NaviolaPinnedItem?
        if let idx = ungrouped.firstIndex(where: { $0.id == itemId }) {
            item = ungrouped.remove(at: idx)
        } else {
            for gi in groups.indices {
                if let idx = groups[gi].items.firstIndex(where: { $0.id == itemId }) {
                    item = groups[gi].items.remove(at: idx)
                    break
                }
            }
        }

        // Add to target group
        if let item = item, let gi = groups.firstIndex(where: { $0.id == groupId }) {
            groups[gi].items.append(item)
            save()
        }
    }

    func moveToUngrouped(itemId: UUID) {
        for gi in groups.indices {
            if let idx = groups[gi].items.firstIndex(where: { $0.id == itemId }) {
                let item = groups[gi].items.remove(at: idx)
                ungrouped.append(item)
                save()
                return
            }
        }
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)

            // Try new format first
            if let pinData = try? JSONDecoder().decode(NaviolaPinnedData.self, from: data) {
                ungrouped = pinData.ungrouped
                groups = pinData.groups
                return
            }

            // Fall back to old flat array format
            if let flatItems = try? JSONDecoder().decode([NaviolaPinnedItem].self, from: data) {
                ungrouped = flatItems
                groups = []
                // Re-save in new format
                save()
                return
            }

            warning("Failed to decode pinned items in any format")
        } catch {
            warning("Failed to load pinned items: \(error)")
        }
    }

    func save() {
        do {
            let pinData = NaviolaPinnedData(ungrouped: ungrouped, groups: groups)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(pinData)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            warning("Failed to save pinned items: \(error)")
        }
    }
}
