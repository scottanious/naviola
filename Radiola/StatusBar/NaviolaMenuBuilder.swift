//
//  NaviolaMenuBuilder.swift
//  Radiola
//
//  Naviola — Builds menu items for pinned Navidrome content.
//

import Cocoa

class NaviolaMenuBuilder {
    /// Add pinned items section to the given menu.
    static func addPinnedItems(to menu: NSMenu) {
        let store = NaviolaPinnedItemStore.shared
        guard !store.items.isEmpty else { return }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: NSLocalizedString("Pinned", comment: "Status bar menu section"),
            action: nil,
            keyEquivalent: ""
        ))

        for item in store.items {
            let menuItem = NSMenuItem(
                title: "  " + item.title,
                action: #selector(pinnedItemClicked(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = item

            if let subtitle = item.subtitle {
                menuItem.toolTip = subtitle
            }

            menu.addItem(menuItem)
        }
    }

    @objc private static func pinnedItemClicked(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? NaviolaPinnedItem else { return }
        NaviolaPlayQueue.shared.play(item: item)
    }
}
