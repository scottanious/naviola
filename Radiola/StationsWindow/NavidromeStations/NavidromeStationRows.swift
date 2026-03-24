//
//  NavidromeStationRows.swift
//  Radiola
//
//  Naviola — Row views for Navidrome albums and tracks.
//  Parallel to InternetStationRows.swift.
//

import Cocoa

// MARK: - NavidromeAlbumRow

class NavidromeAlbumRow: NSView {
    private let album: NavidromeAlbum

    private let nameLabel = TextField()
    private let detailLabel = Label()
    private let pinButton = ImageButton()
    private let separator = Separator()

    private let pinIcons = [
        false: NSImage(systemSymbolName: NSImage.Name("pin"), accessibilityDescription: "Pin album")?.tint(color: .lightGray),
        true: NSImage(systemSymbolName: NSImage.Name("pin.fill"), accessibilityDescription: "Pinned")?.tint(color: .systemYellow),
    ]

    init(album: NavidromeAlbum) {
        self.album = album
        super.init(frame: NSRect())

        addSubview(nameLabel)
        addSubview(detailLabel)
        addSubview(pinButton)
        addSubview(separator)

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

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        pinButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),

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
        Task { @MainActor in
            do {
                try await album.loadTracks()
                pinAlbumToLocal()
                refreshPinButton()
            } catch {
                warning("Failed to load tracks for pinning: \(error)")
            }
        }
    }

    private func pinAlbumToLocal() {
        guard let list = AppState.shared.localStations.first else { return }

        // Check if already pinned (by matching group title)
        let groupTitle = albumGroupTitle()
        if list.firstGroup(where: { $0.title == groupTitle }) != nil { return }

        let group = list.createGroup(title: groupTitle)
        for track in album.tracks {
            let trackTitle: String
            if let num = track.trackNumber {
                trackTitle = "\(num). \(track.title)"
            } else {
                trackTitle = track.title
            }
            let station = list.createStation(title: trackTitle, url: track.url)
            station.isFavorite = true
            group.append(station)
        }
        list.append(group)
        list.trySave()
    }

    private func albumGroupTitle() -> String {
        if let artist = album.artist {
            return "\(artist) - \(album.title)"
        }
        return album.title
    }

    private func isPinned() -> Bool {
        guard let list = AppState.shared.localStations.first else { return false }
        return list.firstGroup(where: { $0.title == albumGroupTitle() }) != nil
    }

    private func refreshPinButton() {
        let pinned = isPinned()
        pinButton.image = pinIcons[pinned]!
        pinButton.toolTip = pinned ?
            NSLocalizedString("Album pinned to My lists", comment: "Pin button tooltip") :
            NSLocalizedString("Pin album to My lists", comment: "Pin button tooltip")
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
