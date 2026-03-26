//
//  NavidromeSearchPanel.swift
//  Naviola
//
//  Naviola — Search/filter panel for Navidrome browsing.
//  Adapts based on category: segmented sort for Albums, search field for Search,
//  refresh button for other categories.
//

import Cocoa

class NavidromeSearchPanel: NSControl {
    var provider: NavidromeProvider?
    private let refreshButton = NSButton(title: NSLocalizedString("Refresh", comment: "Navidrome search panel"), target: nil, action: nil)
    private let searchField = NSSearchField()
    private let segmentedControl = NSSegmentedControl()
    private let separator = Separator()

    init(provider: NavidromeProvider) {
        self.provider = provider
        super.init(frame: NSRect.zero)

        setBackgroundColor(NSColor.textBackgroundColor)
        addSubview(separator)

        switch provider.category {
        case .albums:
            setupAlbumSortMode()
        case .search:
            setupSearchMode(provider: provider)
        case .artists, .genres, .playlists, .pinned:
            setupRefreshMode()
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
        if provider?.category == .search {
            return searchField.becomeFirstResponder()
        }
        return super.becomeFirstResponder()
    }

    // MARK: - Albums Sort Mode

    private func setupAlbumSortMode() {
        let modes = NavidromeProvider.AlbumSortMode.allCases
        segmentedControl.segmentCount = modes.count
        for (i, mode) in modes.enumerated() {
            segmentedControl.setLabel(mode.title, forSegment: i)
            segmentedControl.setWidth(0, forSegment: i) // auto-size
        }

        segmentedControl.selectedSegment = provider?.albumSortMode.rawValue ?? 0
        segmentedControl.segmentStyle = .automatic
        segmentedControl.target = self
        segmentedControl.action = #selector(sortModeChanged)

        addSubview(segmentedControl)
        addSubview(refreshButton)

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(actionTriggered)

        NSLayoutConstraint.activate([
            segmentedControl.centerYAnchor.constraint(equalTo: centerYAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            refreshButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            refreshButton.leadingAnchor.constraint(equalToSystemSpacingAfter: segmentedControl.trailingAnchor, multiplier: 1),
        ])
    }

    @objc private func sortModeChanged() {
        guard let provider = provider,
              let mode = NavidromeProvider.AlbumSortMode(rawValue: segmentedControl.selectedSegment) else { return }

        provider.albumSortMode = mode

        // Trigger fetch
        guard let target = target, let action = action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

    // MARK: - Refresh Mode

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

    private let searchScopeControl = NSSegmentedControl()

    private func setupSearchMode(provider: NavidromeProvider) {
        // Scope selector
        let scopes = NavidromeProvider.SearchScope.allCases
        searchScopeControl.segmentCount = scopes.count
        for (i, scope) in scopes.enumerated() {
            searchScopeControl.setLabel(scope.title, forSegment: i)
            searchScopeControl.setWidth(0, forSegment: i)
        }
        searchScopeControl.selectedSegment = provider.searchScope.rawValue
        searchScopeControl.segmentStyle = .automatic
        searchScopeControl.target = self
        searchScopeControl.action = #selector(searchFieldAction)

        addSubview(searchScopeControl)
        addSubview(searchField)

        searchField.sendsWholeSearchString = true
        searchField.controlSize = .large
        searchField.placeholderString = NSLocalizedString("Search...", comment: "Navidrome search placeholder")
        searchField.stringValue = provider.searchText
        searchField.target = self
        searchField.action = #selector(searchFieldAction)

        searchScopeControl.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchScopeControl.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchScopeControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.leadingAnchor.constraint(equalToSystemSpacingAfter: searchScopeControl.trailingAnchor, multiplier: 1),
            searchField.widthAnchor.constraint(equalToConstant: 250),
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

        if let scope = NavidromeProvider.SearchScope(rawValue: searchScopeControl.selectedSegment) {
            provider.searchScope = scope
        }

        guard !searchField.stringValue.isEmpty else { return }
        guard let target = target, let action = action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }
}
