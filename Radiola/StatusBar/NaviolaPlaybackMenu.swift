//
//  NaviolaPlaybackMenu.swift
//  Radiola
//
//  Naviola — Skip/back and repeat/shuffle menu items for the status bar.
//

import Cocoa

class NaviolaPlaybackMenu {
    /// Add playback controls to the menu when a play queue is active.
    static func addPlaybackControls(to menu: NSMenu) {
        let queue = NaviolaPlayQueue.shared
        guard queue.isActive else { return }

        menu.addItem(NSMenuItem.separator())

        // Track position: "Track 3 of 10"
        let positionItem = NSMenuItem(
            title: String(format: NSLocalizedString("Track %d of %d", comment: "Playback position"),
                          queue.currentIndex + 1, queue.tracks.count),
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(positionItem)

        // Previous track
        let prevItem = NSMenuItem(
            title: NSLocalizedString("Previous Track", comment: "Playback menu item"),
            action: #selector(previousTrack),
            keyEquivalent: ""
        )
        prevItem.target = self
        prevItem.isEnabled = queue.currentIndex > 0
        menu.addItem(prevItem)

        // Next track
        let nextItem = NSMenuItem(
            title: NSLocalizedString("Next Track", comment: "Playback menu item"),
            action: #selector(nextTrack),
            keyEquivalent: ""
        )
        nextItem.target = self
        nextItem.isEnabled = queue.currentIndex + 1 < queue.tracks.count || queue.repeatMode != .off
        menu.addItem(nextItem)

        menu.addItem(NSMenuItem.separator())

        // Repeat toggle
        let repeatTitle: String
        switch queue.repeatMode {
        case .off: repeatTitle = NSLocalizedString("Repeat: Off", comment: "Playback menu item")
        case .all: repeatTitle = NSLocalizedString("Repeat: All", comment: "Playback menu item")
        case .one: repeatTitle = NSLocalizedString("Repeat: One", comment: "Playback menu item")
        }
        let repeatItem = NSMenuItem(
            title: repeatTitle,
            action: #selector(toggleRepeat),
            keyEquivalent: ""
        )
        repeatItem.target = self
        menu.addItem(repeatItem)

        // Shuffle toggle
        let shuffleItem = NSMenuItem(
            title: queue.shuffleEnabled ?
                NSLocalizedString("Shuffle: On", comment: "Playback menu item") :
                NSLocalizedString("Shuffle: Off", comment: "Playback menu item"),
            action: #selector(toggleShuffle),
            keyEquivalent: ""
        )
        shuffleItem.target = self
        menu.addItem(shuffleItem)
    }

    @objc private static func previousTrack() {
        NaviolaPlayQueue.shared.previous()
    }

    @objc private static func nextTrack() {
        NaviolaPlayQueue.shared.next()
    }

    @objc private static func toggleRepeat() {
        let queue = NaviolaPlayQueue.shared
        switch queue.repeatMode {
        case .off: queue.repeatMode = .all
        case .all: queue.repeatMode = .one
        case .one: queue.repeatMode = .off
        }
    }

    @objc private static func toggleShuffle() {
        NaviolaPlayQueue.shared.shuffleEnabled.toggle()
    }
}
