//
//  PinnedToolBox.swift
//  Radiola
//
//  Naviola — Toolbox for the Pinned view, mirroring LocalStationToolBox.
//

import Cocoa

class PinnedToolBox: NSView {
    let addGroupButton = NSButton()
    let delButton = NSButton()

    init() {
        super.init(frame: NSRect.zero)
        addSubview(addGroupButton)
        addSubview(delButton)

        addGroupButton.bezelStyle = .smallSquare
        addGroupButton.setButtonType(.momentaryPushIn)
        addGroupButton.title = NSLocalizedString("Add group", comment: "Button title")
        addGroupButton.image = NSImage(systemSymbolName: NSImage.Name("plus.circle"), accessibilityDescription: addGroupButton.title)
        addGroupButton.imagePosition = .imageLeft
        addGroupButton.image?.isTemplate = true
        addGroupButton.isBordered = false

        delButton.bezelStyle = .smallSquare
        delButton.setButtonType(.momentaryPushIn)
        delButton.title = NSLocalizedString("Remove", comment: "Button title")
        delButton.image = NSImage(systemSymbolName: NSImage.Name("minus.circle"), accessibilityDescription: delButton.title)
        delButton.imagePosition = .imageLeft
        delButton.image?.isTemplate = true
        delButton.isBordered = false

        addGroupButton.translatesAutoresizingMaskIntoConstraints = false
        delButton.translatesAutoresizingMaskIntoConstraints = false

        addGroupButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        delButton.heightAnchor.constraint(equalTo: addGroupButton.heightAnchor).isActive = true

        addGroupButton.topAnchor.constraint(equalTo: topAnchor, constant: 6).isActive = true
        delButton.topAnchor.constraint(equalTo: addGroupButton.topAnchor).isActive = true

        addGroupButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
        delButton.leadingAnchor.constraint(equalToSystemSpacingAfter: addGroupButton.trailingAnchor, multiplier: 3).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
