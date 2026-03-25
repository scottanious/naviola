//
//  NavidromeStationDelegate.swift
//  Radiola
//
//  Naviola — NSOutlineView delegate/datasource for Navidrome album browsing.
//  Parallel to InternetStationDelegate.swift.
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
}

// MARK: - NSOutlineViewDelegate

extension NavidromeStationDelegate: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let album = item as? NavidromeAlbum {
            return NavidromeAlbumRow(album: album)
        }

        if let track = item as? NavidromeTrack {
            return NavidromeTrackRow(track: track)
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is NavidromeAlbum {
            return CGFloat(48.0)
        }
        return CGFloat(28.0)
    }
}

// MARK: - Context Menu

extension NavidromeStationDelegate: NSMenuDelegate {
    /// Set up the context menu on the outline view.
    func installContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu
    }

    /// Dynamically populate the menu based on the clicked row.
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

// MARK: - NSOutlineViewDataSource

extension NavidromeStationDelegate: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        // Root: show albums
        if item == nil {
            return list?.items.count ?? 0
        }

        // Album: show tracks (if loaded)
        if let album = item as? NavidromeAlbum {
            return album.tracks.count
        }

        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return list?.items[index] ?? ""
        }

        if let album = item as? NavidromeAlbum {
            return album.tracks[index]
        }

        return item!
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let album = item as? NavidromeAlbum {
            return album.tracksLoaded ? !album.tracks.isEmpty : (album.songCount ?? 0) > 0
        }
        return false
    }

    /// Called when user expands an album — fetch tracks if needed.
    func outlineViewItemWillExpand(_ notification: Notification) {
        guard let album = notification.userInfo?["NSObject"] as? NavidromeAlbum else { return }

        if !album.tracksLoaded {
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
