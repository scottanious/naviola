//
//  NavidromeSearchPanel.swift
//  Radiola
//
//  Naviola — Search/refresh panel for Navidrome browsing.
//  Adapts based on lens type: refresh button for Recently Added, search field for Search.
//

import Cocoa

class NavidromeSearchPanel: NSControl {
    var provider: NavidromeProvider?
    private let refreshButton = NSButton(title: NSLocalizedString("Refresh", comment: "Navidrome search panel"), target: nil, action: nil)
    private let searchField = NSSearchField()
    private let separator = Separator()

    init(provider: NavidromeProvider) {
        self.provider = provider
        super.init(frame: NSRect.zero)

        setBackgroundColor(NSColor.textBackgroundColor)
        addSubview(separator)

        switch provider.lensType {
        case .recentlyAdded:
            setupRefreshMode()
        case .search:
            setupSearchMode(provider: provider)
        }

        separator.alignBottom(of: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        setBackgroundColor(NSColor.textBackgroundColor)
    }

    override func becomeFirstResponder() -> Bool {
        if provider?.lensType == .search {
            return searchField.becomeFirstResponder()
        }
        return super.becomeFirstResponder()
    }

    // MARK: - Refresh Mode (Recently Added)

    private func setupRefreshMode() {
        addSubview(refreshButton)
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(actionTriggered)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            refreshButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            refreshButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
        ])
    }

    // MARK: - Search Mode

    private func setupSearchMode(provider: NavidromeProvider) {
        addSubview(searchField)
        searchField.sendsWholeSearchString = true
        searchField.controlSize = .large
        searchField.placeholderString = NSLocalizedString("Search albums...", comment: "Navidrome search placeholder")
        searchField.stringValue = provider.searchText
        searchField.target = self
        searchField.action = #selector(searchFieldAction)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            searchField.widthAnchor.constraint(equalToConstant: 400),
        ])
    }

    // MARK: - Actions

    @objc private func actionTriggered() {
        guard let target = target, let action = action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    @objc private func searchFieldAction() {
        guard let provider = provider else { return }
        provider.searchText = searchField.stringValue

        guard !searchField.stringValue.isEmpty else { return }
        guard let target = target, let action = action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }
}
