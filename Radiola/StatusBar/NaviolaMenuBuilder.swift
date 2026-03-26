//
//  NaviolaMenuBuilder.swift
//  Radiola
//
//  Naviola — Builds menu items for pinned Navidrome content.
//  Supports groups as submenus.
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

        // Ungrouped items
        for item in store.ungrouped {
            menu.addItem(createMenuItem(for: item))
        }

        // Groups as labeled sections (like radio station groups)
        for group in store.groups {
            guard !group.items.isEmpty else { continue }

            let groupLabel = NSMenuItem(title: group.title, action: nil, keyEquivalent: "")
            menu.addItem(groupLabel)

            for item in group.items {
                menu.addItem(createMenuItem(for: item))
            }
        }
    }

    private static func createMenuItem(for item: NaviolaPinnedItem, indent: Bool = true) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: (indent ? "  " : "") + item.title,
            action: #selector(pinnedItemClicked(_:)),
            keyEquivalent: ""
        )
        menuItem.target = self
        menuItem.representedObject = item

        if let subtitle = item.subtitle {
            menuItem.toolTip = subtitle
        }

        return menuItem
    }

    @objc private static func pinnedItemClicked(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? NaviolaPinnedItem else { return }
        NaviolaPlayQueue.shared.play(item: item)
    }
}
