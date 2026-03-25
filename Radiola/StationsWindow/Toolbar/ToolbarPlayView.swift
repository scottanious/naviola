//
//  ToolbarPlayView.swift
//  Radiola
//
//  Naviola — Fully programmatic toolbar with play controls, skip buttons,
//  and track info. Replaces XIB-based layout for full control.
//

import Cocoa

class ToolbarPlayView: NSViewController {
    private let playButton = NSButton()
    private let prevButton = NSButton()
    private let nextButton = NSButton()
    private let songLabel = Label()
    private let stationLabel = Label()
    private let onlyStationLabel = Label()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 52))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Play button
        view.addSubview(playButton)
        playButton.bezelStyle = .regularSquare
        playButton.setButtonType(.momentaryPushIn)
        playButton.imagePosition = .imageOnly
        playButton.isBordered = false
        playButton.imageScaling = .scaleNone
        playButton.target = self
        playButton.action = #selector(togglePlay)
        playButton.keyEquivalent = " "
        playButton.keyEquivalentModifierMask = []

        // Skip buttons
        for btn in [prevButton, nextButton] {
            view.addSubview(btn)
            btn.bezelStyle = .regularSquare
            btn.setButtonType(.momentaryPushIn)
            btn.imagePosition = .imageOnly
            btn.isBordered = false
            btn.imageScaling = .scaleProportionallyDown
        }

        prevButton.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "Previous")
        prevButton.image?.isTemplate = true
        prevButton.target = self
        prevButton.action = #selector(previousTrack)

        nextButton.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Next")
        nextButton.image?.isTemplate = true
        nextButton.target = self
        nextButton.action = #selector(nextTrack)

        // Song label (primary)
        view.addSubview(songLabel)
        songLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        songLabel.textColor = .labelColor
        songLabel.lineBreakMode = .byTruncatingTail
        songLabel.usesSingleLineMode = true

        // Station/artist label (secondary)
        view.addSubview(stationLabel)
        stationLabel.font = NSFont.systemFont(ofSize: 11)
        stationLabel.textColor = .secondaryLabelColor
        stationLabel.lineBreakMode = .byTruncatingTail
        stationLabel.usesSingleLineMode = true

        // Only-station label (when no song playing)
        view.addSubview(onlyStationLabel)
        onlyStationLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        onlyStationLabel.textColor = .labelColor
        onlyStationLabel.lineBreakMode = .byTruncatingTail
        onlyStationLabel.usesSingleLineMode = true

        // Layout
        playButton.translatesAutoresizingMaskIntoConstraints = false
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        songLabel.translatesAutoresizingMaskIntoConstraints = false
        stationLabel.translatesAutoresizingMaskIntoConstraints = false
        onlyStationLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Play: 28x28, leading
            playButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            playButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 28),
            playButton.heightAnchor.constraint(equalToConstant: 28),

            // Prev: 14x14
            prevButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 6),
            prevButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 14),
            prevButton.heightAnchor.constraint(equalToConstant: 14),

            // Next: 14x14
            nextButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 6),
            nextButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 14),
            nextButton.heightAnchor.constraint(equalToConstant: 14),

            // Song label: after skip buttons, top half
            songLabel.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 10),
            songLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -8),
            songLabel.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -1),

            // Station label: below song label
            stationLabel.leadingAnchor.constraint(equalTo: songLabel.leadingAnchor),
            stationLabel.trailingAnchor.constraint(equalTo: songLabel.trailingAnchor),
            stationLabel.topAnchor.constraint(equalTo: view.centerYAnchor, constant: 2),

            // Only-station label: centered vertically, same leading
            onlyStationLabel.leadingAnchor.constraint(equalTo: songLabel.leadingAnchor),
            onlyStationLabel.trailingAnchor.constraint(equalTo: songLabel.trailingAnchor),
            onlyStationLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        songLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        onlyStationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: Notification.Name.PlayerStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: Notification.Name.PlayerMetadataChanged, object: nil)
        refresh()
    }

    @objc private func refresh() {
        // Play/pause icon
        switch player.status {
        case .paused:
            playButton.image = NSImage(named: NSImage.Name("NSTouchBarPlayTemplate"))
            playButton.image?.isTemplate = true
        case .connecting, .playing:
            playButton.image = NSImage(named: NSImage.Name("NSTouchBarPauseTemplate"))
            playButton.image?.isTemplate = true
        }

        // Song/station text
        switch player.status {
        case .paused:
            songLabel.stringValue = ""
            stationLabel.stringValue = player.stationName
        case .connecting:
            songLabel.stringValue = NSLocalizedString("Connecting…", comment: "")
            stationLabel.stringValue = player.stationName
        case .playing:
            if let track = player.station as? NavidromeTrack {
                songLabel.stringValue = track.title
                var detail = [String]()
                if let artist = track.artist { detail.append(artist) }
                if let album = track.albumTitle { detail.append(album) }
                stationLabel.stringValue = detail.joined(separator: " — ")
            } else {
                songLabel.stringValue = player.songTitle
                stationLabel.stringValue = player.stationName
            }
        }

        // Toggle between two-line and single-line display
        let hasSong = !songLabel.stringValue.isEmpty
        onlyStationLabel.stringValue = stationLabel.stringValue
        onlyStationLabel.isHidden = hasSong
        songLabel.isHidden = !hasSong
        stationLabel.isHidden = !hasSong

        // Skip buttons: show only when queue is active
        let queue = NaviolaPlayQueue.shared
        prevButton.isHidden = !queue.isActive
        nextButton.isHidden = !queue.isActive
        prevButton.isEnabled = queue.currentIndex > 0
        nextButton.isEnabled = queue.currentIndex + 1 < queue.tracks.count || queue.repeatMode != .off
    }

    @objc private func togglePlay() {
        if player.isPlaying { NaviolaPlayQueue.shared.userPause() }
        player.toggle()
    }

    @objc private func previousTrack() {
        NaviolaPlayQueue.shared.previous()
    }

    @objc private func nextTrack() {
        NaviolaPlayQueue.shared.next()
    }
}
