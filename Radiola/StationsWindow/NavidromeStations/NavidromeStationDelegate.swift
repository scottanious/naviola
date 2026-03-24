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
            return CGFloat(44.0)
        }
        return CGFloat(28.0)
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
