//
//  NavidromeStationRows.swift
//  Naviola
//
//  Naviola — Row views for Navidrome albums and tracks.
//  Parallel to InternetStationRows.swift.
//

import Cocoa

// MARK: - NavidromeAlbumRow

class NavidromeAlbumRow: NSView {
    private let album: NavidromeAlbum

    private let coverImageView = NSImageView()
    private let nameLabel = TextField()
    private let detailLabel = Label()
    private let pinButton = ImageButton()
    private let separator = Separator()

    private static let placeholderImage = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Album")

    private let pinIcons = [
        false: NSImage(systemSymbolName: NSImage.Name("pin"), accessibilityDescription: "Pin album")?.tint(color: .lightGray),
        true: NSImage(systemSymbolName: NSImage.Name("pin.fill"), accessibilityDescription: "Pinned")?.tint(color: .systemYellow),
    ]

    init(album: NavidromeAlbum) {
        self.album = album
        super.init(frame: NSRect())

        addSubview(coverImageView)
        addSubview(nameLabel)
        addSubview(detailLabel)
        addSubview(pinButton)
        addSubview(separator)

        // Cover art
        coverImageView.image = Self.placeholderImage
        coverImageView.imageScaling = .scaleProportionallyUpOrDown
        coverImageView.wantsLayer = true
        coverImageView.layer?.cornerRadius = 3

        NavidromeCoverArtCache.shared.image(forCoverArtId: album.coverArtId, size: 80) { [weak self] image in
            if let image = image {
                self?.coverImageView.image = image
            }
        }

        // Name
        nameLabel.isBordered = false
        nameLabel.drawsBackground = false
        nameLabel.isEditable = false
        if let font = nameLabel.font {
            nameLabel.font = NSFont.systemFont(ofSize: font.pointSize, weight: .medium)
        }
        nameLabel.stringValue = album.title

        // Detail line: artist, year, song count
        detailLabel.font = NSFont.systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.stringValue = albumDetailString()

        // Pin button
        pinButton.target = self
        pinButton.action = #selector(pinButtonClicked)
        refreshPinButton()

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

            nameLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 5),

            detailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            detailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),

            pinButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            pinButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            pinButton.widthAnchor.constraint(equalToConstant: 16),
            pinButton.heightAnchor.constraint(equalToConstant: 16),
        ])

        separator.alignBottom(of: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func albumDetailString() -> String {
        var parts = [String]()
        if let artist = album.artist { parts.append(artist) }
        if let year = album.year { parts.append(String(year)) }
        if let count = album.songCount { parts.append("\(count) tracks") }
        return parts.joined(separator: " · ")
    }

    @objc private func pinButtonClicked() {
        let store = NaviolaPinnedItemStore.shared
        if store.isPinned(subsonicId: album.navidromeId) {
            store.remove(subsonicId: album.navidromeId)
        } else {
            var subtitle = ""
            var parts = [String]()
            if let count = album.songCount { parts.append("\(count) tracks") }
            if let year = album.year { parts.append(String(year)) }
            subtitle = parts.joined(separator: " · ")

            let item = NaviolaPinnedItem(
                type: .album,
                title: albumDisplayTitle(),
                subtitle: subtitle.isEmpty ? nil : subtitle,
                subsonicId: album.navidromeId,
                coverArtId: album.coverArtId
            )
            store.add(item)
        }
        refreshPinButton()
    }

    private func albumDisplayTitle() -> String {
        if let artist = album.artist {
            return "\(artist) - \(album.title)"
        }
        return album.title
    }

    private func isPinned() -> Bool {
        return NaviolaPinnedItemStore.shared.isPinned(subsonicId: album.navidromeId)
    }

    private func refreshPinButton() {
        let pinned = isPinned()
        pinButton.image = pinIcons[pinned]!
        pinButton.toolTip = pinned ?
            NSLocalizedString("Pinned — click to unpin", comment: "Pin button tooltip") :
            NSLocalizedString("Pin album", comment: "Pin button tooltip")
    }
}

// MARK: - NavidromeTrackRow

class NavidromeTrackRow: NSView {
    private let track: NavidromeTrack

    private let trackLabel = Label()
    private let durationLabel = Label()
    private let separator = Separator()

    init(track: NavidromeTrack) {
        self.track = track
        super.init(frame: NSRect())

        addSubview(trackLabel)
        addSubview(durationLabel)
        addSubview(separator)

        trackLabel.font = NSFont.systemFont(ofSize: 12)
        trackLabel.stringValue = trackDisplayString()

        durationLabel.font = NSFont.systemFont(ofSize: 11)
        durationLabel.textColor = .secondaryLabelColor
        durationLabel.alignment = .right
        durationLabel.stringValue = formatDuration(track.duration)

        trackLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            trackLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            trackLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            trackLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),

            durationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            durationLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 45),
        ])

        separator.alignBottom(of: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func trackDisplayString() -> String {
        if let num = track.trackNumber {
            return "\(num). \(track.title)"
        }
        return track.title
    }

    private func formatDuration(_ seconds: Int?) -> String {
        guard let seconds = seconds, seconds > 0 else { return "" }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - NavidromeBrowseItemRow

class NavidromeBrowseItemRow: NSView {
    private let item: NavidromeBrowseItem

    private let nameLabel = Label()
    private let detailLabel = Label()
    private let pinButton = ImageButton()
    private let separator = Separator()

    private let pinIcons = [
        false: NSImage(systemSymbolName: NSImage.Name("pin"), accessibilityDescription: "Pin")?.tint(color: .lightGray),
        true: NSImage(systemSymbolName: NSImage.Name("pin.fill"), accessibilityDescription: "Pinned")?.tint(color: .systemYellow),
    ]

    init(item: NavidromeBrowseItem) {
        self.item = item
        super.init(frame: NSRect())

        addSubview(nameLabel)
        addSubview(detailLabel)
        addSubview(pinButton)
        addSubview(separator)

        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.stringValue = item.title

        detailLabel.font = NSFont.systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.stringValue = item.subtitle ?? ""

        pinButton.target = self
        pinButton.action = #selector(pinButtonClicked)
        refreshPinButton()

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        pinButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            detailLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: nameLabel.trailingAnchor, multiplier: 1),
            detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: pinButton.leadingAnchor, constant: -8),

            pinButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            pinButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            pinButton.widthAnchor.constraint(equalToConstant: 16),
            pinButton.heightAnchor.constraint(equalToConstant: 16),
        ])

        separator.alignBottom(of: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func pinButtonClicked() {
        let store = NaviolaPinnedItemStore.shared
        if store.isPinned(subsonicId: item.navidromeId) {
            store.remove(subsonicId: item.navidromeId)
        } else {
            let pinnedType: NaviolaPinnedItem.PinnedItemType
            switch item.itemType {
            case .artist: pinnedType = .artist
            case .genre: pinnedType = .genre
            case .playlist: pinnedType = .playlist
            case .group: return
            }

            let pinnedItem = NaviolaPinnedItem(
                type: pinnedType,
                title: item.title,
                subtitle: item.subtitle,
                subsonicId: item.navidromeId,
                coverArtId: item.coverArtId
            )
            store.add(pinnedItem)
        }
        refreshPinButton()
    }

    private func refreshPinButton() {
        let pinned = NaviolaPinnedItemStore.shared.isPinned(subsonicId: item.navidromeId)
        pinButton.image = pinIcons[pinned]!
        pinButton.toolTip = pinned
            ? NSLocalizedString("Pinned — click to unpin", comment: "Pin button tooltip")
            : NSLocalizedString("Pin", comment: "Pin button tooltip")
    }
}
