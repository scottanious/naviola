//
//  NavidromeStationDelegate.swift
//  Naviola
//
//  Naviola — NSOutlineView delegate/datasource for Navidrome browsing.
//  Handles albums, artists, genres, playlists — all with expandable children.
//

import Cocoa

// MARK: - NavidromeStationDelegate

class NavidromeStationDelegate: NSObject {
    private weak var outlineView: NSOutlineView!

    var list: NavidromeAlbumList?

    init(outlineView: NSOutlineView) {
        self.outlineView = outlineView
        list = nil
    }

    @MainActor
    @objc func search() {
        guard let list = list else { return }
        Task {
            await list.fetch()
            outlineView.reloadData()
        }
    }

    /// Whether this list shows only browse items (no albums at root).
    private var showsBrowseItemsOnly: Bool {
        guard let cat = list?.provider.category else { return false }
        return cat == .artists || cat == .genres || cat == .playlists
    }

    /// Whether this list has mixed content (both albums and browseItems at root).
    private var showsMixedContent: Bool {
        guard let cat = list?.provider.category else { return false }
        return cat == .pinned || cat == .search
    }

    /// Total root items.
    private var rootItemCount: Int {
        guard let list = list else { return 0 }
        if showsMixedContent {
            return list.browseItems.count + list.items.count
        }
        return showsBrowseItemsOnly ? list.browseItems.count : list.items.count
    }

    /// Get root item at index. Mixed content: browse items first, then albums.
    private func rootItem(at index: Int) -> Any {
        guard let list = list else { return "" }
        if showsMixedContent {
            if index < list.browseItems.count {
                return list.browseItems[index]
            }
            return list.items[index - list.browseItems.count]
        }
        return showsBrowseItemsOnly ? list.browseItems[index] : list.items[index]
    }
}

// MARK: - NSOutlineViewDelegate

extension NavidromeStationDelegate: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let browseItem = item as? NavidromeBrowseItem {
            return NavidromeBrowseItemRow(item: browseItem)
        }

        if let album = item as? NavidromeAlbum {
            return NavidromeAlbumRow(album: album)
        }

        if let track = item as? NavidromeTrack {
            return NavidromeTrackRow(track: track)
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is NavidromeBrowseItem { return CGFloat(32.0) }
        if item is NavidromeAlbum { return CGFloat(48.0) }
        return CGFloat(28.0)
    }
}

// MARK: - NSOutlineViewDataSource

extension NavidromeStationDelegate: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return rootItemCount
        }

        if let browseItem = item as? NavidromeBrowseItem {
            if browseItem.itemType == .playlist && !browseItem.tracks.isEmpty {
                return browseItem.tracks.count
            }
            return browseItem.albums.count
        }

        if let album = item as? NavidromeAlbum {
            return album.tracks.count
        }

        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return rootItem(at: index)
        }

        if let browseItem = item as? NavidromeBrowseItem {
            if browseItem.itemType == .playlist && !browseItem.tracks.isEmpty {
                return browseItem.tracks[index]
            }
            return browseItem.albums[index]
        }

        if let album = item as? NavidromeAlbum {
            return album.tracks[index]
        }

        return item!
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let browseItem = item as? NavidromeBrowseItem {
            if browseItem.childrenLoaded {
                return browseItem.itemType == .playlist ? !browseItem.tracks.isEmpty : !browseItem.albums.isEmpty
            }
            return true // assume expandable until loaded
        }

        if let album = item as? NavidromeAlbum {
            return album.tracksLoaded ? !album.tracks.isEmpty : (album.songCount ?? 0) > 0
        }

        return false
    }

    func outlineViewItemWillExpand(_ notification: Notification) {
        let item = notification.userInfo?["NSObject"]

        // Expand browse item → load children (albums or tracks)
        if let browseItem = item as? NavidromeBrowseItem, !browseItem.childrenLoaded {
            Task { @MainActor in
                do {
                    try await browseItem.loadChildren()
                    outlineView.reloadItem(browseItem, reloadChildren: true)
                } catch {
                    warning("Failed to load children for \(browseItem.title): \(error)")
                }
            }
            return
        }

        // Expand album → load tracks
        if let album = item as? NavidromeAlbum, !album.tracksLoaded {
            Task { @MainActor in
                do {
                    try await album.loadTracks()
                    outlineView.reloadItem(album, reloadChildren: true)
                } catch {
                    warning("Failed to load tracks for \(album.title): \(error)")
                }
            }
        }
    }
}

// MARK: - Context Menu

extension NavidromeStationDelegate: NSMenuDelegate {
    func installContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let row = outlineView.clickedRow
        guard row >= 0 else { return }

        if let album = outlineView.item(atRow: row) as? NavidromeAlbum {
            let playItem = NSMenuItem(title: NSLocalizedString("Play Album", comment: "Context menu"), action: #selector(playAlbum(_:)), keyEquivalent: "")
            playItem.target = self
            playItem.representedObject = album
            menu.addItem(playItem)

            let pinTitle = NaviolaPinnedItemStore.shared.isPinned(subsonicId: album.navidromeId)
                ? NSLocalizedString("Unpin Album", comment: "Context menu")
                : NSLocalizedString("Pin Album", comment: "Context menu")
            let pinItem = NSMenuItem(title: pinTitle, action: #selector(togglePinAlbum(_:)), keyEquivalent: "")
            pinItem.target = self
            pinItem.representedObject = album
            menu.addItem(pinItem)
        }

        if let browseItem = outlineView.item(atRow: row) as? NavidromeBrowseItem {
            if browseItem.itemType == .group {
                // Group context menu
                let renameItem = NSMenuItem(title: NSLocalizedString("Rename Group", comment: "Context menu"), action: #selector(renameGroup(_:)), keyEquivalent: "")
                renameItem.target = self
                renameItem.representedObject = browseItem
                menu.addItem(renameItem)

                let deleteItem = NSMenuItem(title: NSLocalizedString("Delete Group", comment: "Context menu"), action: #selector(deleteGroup(_:)), keyEquivalent: "")
                deleteItem.target = self
                deleteItem.representedObject = browseItem
                menu.addItem(deleteItem)
            } else {
                let playTitle: String
                switch browseItem.itemType {
                case .playlist: playTitle = NSLocalizedString("Play Playlist", comment: "Context menu")
                case .artist: playTitle = NSLocalizedString("Play Artist", comment: "Context menu")
                case .genre: playTitle = NSLocalizedString("Play Genre", comment: "Context menu")
                default: playTitle = NSLocalizedString("Play", comment: "Context menu")
                }
                let playItem = NSMenuItem(title: playTitle, action: #selector(playBrowseItem(_:)), keyEquivalent: "")
                playItem.target = self
                playItem.representedObject = browseItem
                menu.addItem(playItem)

                let pinTitle = NaviolaPinnedItemStore.shared.isPinned(subsonicId: browseItem.navidromeId)
                    ? NSLocalizedString("Unpin", comment: "Context menu")
                    : NSLocalizedString("Pin", comment: "Context menu")
                let pinItem = NSMenuItem(title: pinTitle, action: #selector(togglePinBrowseItem(_:)), keyEquivalent: "")
                pinItem.target = self
                pinItem.representedObject = browseItem
                menu.addItem(pinItem)
            }
        }

        // Group management options (only in Pinned view)
        if list?.provider.category == .pinned {
            let clickedItem = row >= 0 ? outlineView.item(atRow: row) : nil
            menu.addItem(NSMenuItem.separator())

            // New Group
            let newGroupItem = NSMenuItem(title: NSLocalizedString("New Group", comment: "Context menu"), action: #selector(newGroup), keyEquivalent: "")
            newGroupItem.target = self
            menu.addItem(newGroupItem)

            // Move to Group (for items, not groups)
            if clickedItem != nil, !(clickedItem is NavidromeBrowseItem && (clickedItem as? NavidromeBrowseItem)?.itemType == .group) {
                let store = NaviolaPinnedItemStore.shared
                if !store.groups.isEmpty {
                    let moveMenu = NSMenu()
                    for group in store.groups {
                        let moveItem = NSMenuItem(title: group.title, action: #selector(moveToGroupAction(_:)), keyEquivalent: "")
                        moveItem.target = self
                        moveItem.representedObject = ["row": row, "groupId": group.id.uuidString]
                        moveMenu.addItem(moveItem)
                    }

                    let moveToItem = NSMenuItem(title: NSLocalizedString("Move to Group", comment: "Context menu"), action: nil, keyEquivalent: "")
                    moveToItem.submenu = moveMenu
                    menu.addItem(moveToItem)
                }
            }
        }
    }

    @objc private func playAlbum(_ sender: NSMenuItem) {
        guard let album = sender.representedObject as? NavidromeAlbum else { return }
        Task { @MainActor in
            do {
                try await album.loadTracks()
                if !album.tracks.isEmpty {
                    NaviolaPlayQueue.shared.playTracks(album.tracks)
                }
            } catch {
                warning("Failed to load tracks for \(album.title): \(error)")
            }
        }
    }

    @objc private func playBrowseItem(_ sender: NSMenuItem) {
        guard let browseItem = sender.representedObject as? NavidromeBrowseItem else { return }
        Task { @MainActor in
            do {
                try await browseItem.loadChildren()
                if browseItem.itemType == .playlist {
                    // Playlists have direct tracks
                    if !browseItem.tracks.isEmpty {
                        NaviolaPlayQueue.shared.playTracks(browseItem.tracks)
                    }
                } else {
                    // Artists/genres have albums — collect all tracks
                    var allTracks = [NavidromeTrack]()
                    for album in browseItem.albums {
                        try await album.loadTracks()
                        allTracks.append(contentsOf: album.tracks)
                    }
                    if !allTracks.isEmpty {
                        NaviolaPlayQueue.shared.playTracks(allTracks)
                    }
                }
            } catch {
                warning("Failed to load tracks for \(browseItem.title): \(error)")
            }
        }
    }

    @objc private func togglePinBrowseItem(_ sender: NSMenuItem) {
        guard let browseItem = sender.representedObject as? NavidromeBrowseItem else { return }
        let store = NaviolaPinnedItemStore.shared

        if store.isPinned(subsonicId: browseItem.navidromeId) {
            store.remove(subsonicId: browseItem.navidromeId)
        } else {
            let pinnedType: NaviolaPinnedItem.PinnedItemType
            switch browseItem.itemType {
            case .artist: pinnedType = .artist
            case .genre: pinnedType = .genre
            case .playlist: pinnedType = .playlist
            case .group: return // groups aren't pinned items
            }

            let item = NaviolaPinnedItem(
                type: pinnedType,
                title: browseItem.title,
                subtitle: browseItem.subtitle,
                subsonicId: browseItem.navidromeId,
                coverArtId: browseItem.coverArtId
            )
            store.add(item)
        }
    }

    @objc private func newGroup() {
        let _ = NaviolaPinnedItemStore.shared.addGroup(title: NSLocalizedString("New Group", comment: "Default group name"))
        Task { @MainActor in self.search() }
    }

    @objc private func renameGroup(_ sender: NSMenuItem) {
        guard let browseItem = sender.representedObject as? NavidromeBrowseItem,
              let groupId = UUID(uuidString: browseItem.navidromeId) else { return }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Rename Group", comment: "Dialog title")
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = browseItem.title
        alert.accessoryView = input
        if alert.runModal() == .alertFirstButtonReturn && !input.stringValue.isEmpty {
            NaviolaPinnedItemStore.shared.renameGroup(id: groupId, title: input.stringValue)
            Task { @MainActor in self.search() }
        }
    }

    @objc private func deleteGroup(_ sender: NSMenuItem) {
        guard let browseItem = sender.representedObject as? NavidromeBrowseItem,
              let groupId = UUID(uuidString: browseItem.navidromeId) else { return }
        NaviolaPinnedItemStore.shared.removeGroup(id: groupId)
        Task { @MainActor in self.search() }
    }

    @objc private func moveToGroupAction(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let row = info["row"] as? Int,
              let groupIdStr = info["groupId"] as? String,
              let groupId = UUID(uuidString: groupIdStr) else { return }

        // Find the pinned item ID for the clicked row
        let clickedItem = outlineView.item(atRow: row)
        var pinnedItemId: UUID?

        if let album = clickedItem as? NavidromeAlbum {
            // Find by subsonic ID in the store
            pinnedItemId = NaviolaPinnedItemStore.shared.items.first { $0.subsonicId == album.navidromeId }?.id
        } else if let browseItem = clickedItem as? NavidromeBrowseItem {
            pinnedItemId = NaviolaPinnedItemStore.shared.items.first { $0.subsonicId == browseItem.navidromeId }?.id
        }

        if let itemId = pinnedItemId {
            NaviolaPinnedItemStore.shared.moveToGroup(itemId: itemId, groupId: groupId)
            Task { @MainActor in self.search() }
        }
    }

    @objc private func togglePinAlbum(_ sender: NSMenuItem) {
        guard let album = sender.representedObject as? NavidromeAlbum else { return }
        let store = NaviolaPinnedItemStore.shared

        if store.isPinned(subsonicId: album.navidromeId) {
            store.remove(subsonicId: album.navidromeId)
        } else {
            var parts = [String]()
            if let count = album.songCount { parts.append("\(count) tracks") }
            if let year = album.year { parts.append(String(year)) }

            let item = NaviolaPinnedItem(
                type: .album,
                title: album.artist != nil ? "\(album.artist!) - \(album.title)" : album.title,
                subtitle: parts.isEmpty ? nil : parts.joined(separator: " · "),
                subsonicId: album.navidromeId,
                coverArtId: album.coverArtId
            )
            store.add(item)
        }

        outlineView.reloadData()
    }
}
