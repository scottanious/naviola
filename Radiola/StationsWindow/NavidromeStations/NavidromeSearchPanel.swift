//
//  NavidromeSearchPanel.swift
//  Radiola
//
//  Naviola — Search/refresh panel for Navidrome browsing.
//  Parallel to InternetStationSearchPanel.swift.
//

import Cocoa

class NavidromeSearchPanel: NSControl {
    var provider: NavidromeProvider?
    private let refreshButton = NSButton(title: NSLocalizedString("Refresh", comment: "Navidrome search panel"), target: nil, action: nil)
    private let separator = Separator()

    init(provider: NavidromeProvider) {
        self.provider = provider
        super.init(frame: NSRect.zero)

        setBackgroundColor(NSColor.textBackgroundColor)

        addSubview(refreshButton)
        addSubview(separator)

        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshClicked)

        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            refreshButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            refreshButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
        ])

        separator.alignBottom(of: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        setBackgroundColor(NSColor.textBackgroundColor)
    }

    @objc private func refreshClicked() {
        guard let target = target, let action = action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }
}
