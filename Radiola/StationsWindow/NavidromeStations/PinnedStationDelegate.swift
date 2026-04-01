//
//  PinnedStationDelegate.swift
//  Naviola
//
//  Naviola — Delegate for the Pinned sidebar view.
//  Mirrors LocalStationDelegate patterns: drag-drop, toolbox, groups.
//  All pinned items render as album-style rows (flat within groups).
//

import Cocoa

fileprivate let PinnedItemPasteboardType = NSPasteboard.PasteboardType(rawValue: "Naviola.PinnedItem")

// MARK: - PinnedStationDelegate

class PinnedStationDelegate: NSObject {
    private weak var outlineView: NSOutlineView!
    private let store = NaviolaPinnedItemStore.shared

    init(outlineView: NSOutlineView) {
        self.outlineView = outlineView
    }

    func refresh() {
        debug("[Pinned] Refreshing: \(store.ungrouped.count) ungrouped, \(store.groups.count) groups")
        outlineView?.reloadData()
        outlineView?.expandItem(nil, expandChildren: true)
    }

    /// All root-level displayable items: ungrouped items + groups.
    private var rootItems: [Any] {
        var result: [Any] = store.ungrouped.map { $0 as Any }
        result.append(contentsOf: store.groups.map { $0 as Any })
        return result
    }
}

// MARK: - NSOutlineViewDelegate

extension PinnedStationDelegate: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let group = item as? NaviolaPinnedGroup {
            return PinnedGroupRow(group: group, store: store)
        }

        if let pin = item as? NaviolaPinnedItem {
            return PinnedItemRow(item: pin, store: store) { [weak self] in
                self?.refresh()
            }
        }

        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is NaviolaPinnedGroup { return CGFloat(32.0) }
        return CGFloat(48.0)
    }
}

// MARK: - NSOutlineViewDataSource

extension PinnedStationDelegate: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return store.ungrouped.count + store.groups.count
        }

        if let group = item as? NaviolaPinnedGroup {
            return group.items.count
        }

        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            if index < store.ungrouped.count {
                return store.ungrouped[index]
            }
            return store.groups[index - store.ungrouped.count]
        }

        if let group = item as? NaviolaPinnedGroup {
            return group.items[index]
        }

        return ""
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is NaviolaPinnedGroup
    }

    // MARK: - Drag & Drop

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        outlineView.registerForDraggedTypes([PinnedItemPasteboardType])

        let pb = NSPasteboardItem()
        if let pin = item as? NaviolaPinnedItem {
            pb.setString("item:\(pin.id.uuidString)", forType: PinnedItemPasteboardType)
            return pb
        }
        if let group = item as? NaviolaPinnedGroup {
            pb.setString("group:\(group.id.uuidString)", forType: PinnedItemPasteboardType)
            return pb
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if info.draggingSource as? NSOutlineView != outlineView { return [] }

        // Don't allow dropping ON an item (only between/into groups)
        if item is NaviolaPinnedItem && index == NSOutlineViewDropOnItemIndex { return [] }

        return .move
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let pbItems = info.draggingPasteboard.pasteboardItems else { return false }

        for pbItem in pbItems {
            guard let str = pbItem.string(forType: PinnedItemPasteboardType) else { continue }

            if str.hasPrefix("item:"), let id = UUID(uuidString: String(str.dropFirst(5))) {
                if let group = item as? NaviolaPinnedGroup {
                    store.moveToGroup(itemId: id, groupId: group.id)
                } else if item == nil {
                    store.moveToUngrouped(itemId: id)
                    // Reorder within ungrouped
                    if index >= 0, let idx = store.ungrouped.firstIndex(where: { $0.id == id }), idx != index {
                        let pin = store.ungrouped.remove(at: idx)
                        let insertAt = min(index, store.ungrouped.count)
                        store.ungrouped.insert(pin, at: insertAt)
                        store.save()
                    }
                }
            }
        }

        refresh()
        return true
    }

    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItems draggedItems: [Any]) {
        outlineView.draggingDestinationFeedbackStyle = .regular
    }

    func outlineView(_ outlineView: NSOutlineView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        outlineView.draggingDestinationFeedbackStyle = .none
    }
}

// MARK: - Toolbox Actions

extension PinnedStationDelegate {
    func addGroup(title: String) {
        let _ = store.addGroup(title: title)
        refresh()
    }

    func removeSelected(indexes: IndexSet) {
        for index in indexes {
            let item = outlineView.item(atRow: index)
            if let pin = item as? NaviolaPinnedItem {
                store.remove(id: pin.id)
            } else if let group = item as? NaviolaPinnedGroup {
                store.removeGroup(id: group.id)
            }
        }
        refresh()
    }
}

// MARK: - PinnedGroupRow

class PinnedGroupRow: NSView {
    private let group: NaviolaPinnedGroup
    private let store: NaviolaPinnedItemStore
    private let nameEdit = TextField()

    init(group: NaviolaPinnedGroup, store: NaviolaPinnedItemStore) {
        self.group = group
        self.store = store
        super.init(frame: NSRect())

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Group")
        icon.image?.isTemplate = true

        nameEdit.placeholderString = NSLocalizedString("Group name", comment: "Pinned group placeholder")
        nameEdit.isBordered = false
        nameEdit.drawsBackground = false
        nameEdit.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        nameEdit.stringValue = group.title
        nameEdit.isEditable = true
        nameEdit.target = self
        nameEdit.action = #selector(nameEdited(sender:))

        let countLabel = Label()
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .tertiaryLabelColor
        countLabel.stringValue = "\(group.items.count) items"
        countLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let separator = Separator()

        addSubview(icon)
        addSubview(nameEdit)
        addSubview(countLabel)
        addSubview(separator)

        icon.translatesAutoresizingMaskIntoConstraints = false
        nameEdit.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            nameEdit.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            nameEdit.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameEdit.trailingAnchor.constraint(equalTo: countLabel.leadingAnchor, constant: -6),

            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        separator.alignBottom(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc func nameEdited(sender: NSTextField) {
        let newTitle = sender.stringValue.trimmingCharacters(in: .whitespaces)
        if newTitle.isEmpty {
            sender.stringValue = group.title
            return
        }
        store.renameGroup(id: group.id, title: newTitle)
    }
}

// MARK: - PinnedItemRow

/// Renders ANY pinned item as an album-style row with cover art, title, and unpin button.
class PinnedItemRow: NSView {
    private let item: NaviolaPinnedItem
    private let store: NaviolaPinnedItemStore
    private var onUnpin: (() -> Void)?
    private let pinButton = ImageButton()

    private let pinIcons = [
        false: NSImage(systemSymbolName: NSImage.Name("pin"), accessibilityDescription: "Pin")?.tint(color: .lightGray),
        true: NSImage(systemSymbolName: NSImage.Name("pin.fill"), accessibilityDescription: "Pinned")?.tint(color: .systemYellow),
    ]

    init(item: NaviolaPinnedItem, store: NaviolaPinnedItemStore, onUnpin: (() -> Void)? = nil) {
        self.item = item
        self.store = store
        self.onUnpin = onUnpin
        super.init(frame: NSRect())

        let coverImageView = NSImageView()
        coverImageView.imageScaling = .scaleProportionallyUpOrDown
        coverImageView.wantsLayer = true
        coverImageView.layer?.cornerRadius = 3

        let placeholderName: String
        switch item.type {
        case .album: placeholderName = "music.note"
        case .artist: placeholderName = "music.mic"
        case .genre: placeholderName = "guitars"
        case .playlist: placeholderName = "music.note.list"
        case .track: placeholderName = "music.note"
        }
        coverImageView.image = NSImage(systemSymbolName: placeholderName, accessibilityDescription: nil)

        if let coverArtId = item.coverArtId {
            NavidromeCoverArtCache.shared.image(forCoverArtId: coverArtId, size: 80) { image in
                if let image = image { coverImageView.image = image }
            }
        }

        let nameLabel = Label()
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.stringValue = item.title

        let detailLabel = Label()
        detailLabel.font = NSFont.systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.stringValue = item.subtitle ?? item.type.rawValue.capitalized

        pinButton.target = self
        pinButton.action = #selector(pinClicked(sender:))
        pinButton.image = pinIcons[true]!
        pinButton.toolTip = NSLocalizedString("Unpin", comment: "Unpin button tooltip")

        let separator = Separator()

        addSubview(coverImageView)
        addSubview(nameLabel)
        addSubview(detailLabel)
        addSubview(pinButton)
        addSubview(separator)

        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        pinButton.translatesAutoresizingMaskIntoConstraints = false

        let artSize: CGFloat = 36

        NSLayoutConstraint.activate([
            coverImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            coverImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            coverImageView.widthAnchor.constraint(equalToConstant: artSize),
            coverImageView.heightAnchor.constraint(equalToConstant: artSize),

            pinButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            pinButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            pinButton.widthAnchor.constraint(equalToConstant: 16),
            pinButton.heightAnchor.constraint(equalToConstant: 16),

            nameLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: pinButton.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
        ])

        separator.alignBottom(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func pinClicked(sender: NSButton) {
        store.remove(id: item.id)
        onUnpin?()
    }
}
