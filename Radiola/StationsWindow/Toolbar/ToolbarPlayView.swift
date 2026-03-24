//
//  ToolbarPlayView.swift
//  Radiola
//
//  Created by Aleksandr Sokolov on 30.08.2023.
//

import Cocoa

class ToolbarPlayView: NSViewController {
    @IBOutlet var playButton: NSButton!
    @IBOutlet var songLabel: NSTextField!
    @IBOutlet var stationLabel: NSTextField!
    private let onlyStationLabel = Label()

    // Naviola: skip/back buttons
    private let prevButton = NSButton()
    private let nextButton = NSButton()

    /* ****************************************
     *
     * ****************************************/
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(onlyStationLabel)
        onlyStationLabel.textColor = stationLabel.textColor
        onlyStationLabel.lineBreakMode = .byClipping
        onlyStationLabel.font = NSFont.systemFont(ofSize: 14)
        onlyStationLabel.setFontWeight(.semibold)
        onlyStationLabel.lineBreakMode = .byTruncatingTail
        onlyStationLabel.usesSingleLineMode = true
        onlyStationLabel.translatesAutoresizingMaskIntoConstraints = false

        onlyStationLabel.leadingAnchor.constraint(equalTo: stationLabel.leadingAnchor).isActive = true
        onlyStationLabel.trailingAnchor.constraint(equalTo: stationLabel.trailingAnchor).isActive = true
        onlyStationLabel.centerYAnchor.constraint(equalTo: playButton.centerYAnchor).isActive = true

        songLabel.lineBreakMode = .byTruncatingMiddle
        songLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        songLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        songLabel.menu = ContextMenu(textField: songLabel)

        stationLabel.lineBreakMode = .byTruncatingMiddle
        stationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stationLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stationLabel.menu = ContextMenu(textField: stationLabel)

        playButton.setContentHuggingPriority(NSLayoutConstraint.Priority(240) /* .defaultLow */, for: NSLayoutConstraint.Orientation.horizontal)
        playButton.bezelStyle = NSButton.BezelStyle.regularSquare
        playButton.setButtonType(NSButton.ButtonType.momentaryPushIn)
        playButton.imagePosition = NSControl.ImagePosition.imageOnly
        playButton.alignment = NSTextAlignment.center
        playButton.lineBreakMode = NSLineBreakMode.byTruncatingTail
        playButton.state = NSControl.StateValue.on
        playButton.isBordered = false
        playButton.imageScaling = NSImageScaling.scaleNone
        playButton.font = NSFont.systemFont(ofSize: 24)
        playButton.image?.isTemplate = true
        playButton.target = self
        playButton.action = #selector(togglePlay)
        playButton.keyEquivalent = " "
        playButton.keyEquivalentModifierMask = []

        // Naviola: skip/back buttons
        setupSkipButtons()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refresh),
                                               name: Notification.Name.PlayerStatusChanged,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refresh),
                                               name: Notification.Name.PlayerMetadataChanged,
                                               object: nil)

        refresh()
    }

    // Naviola: set up skip/back buttons
    private func setupSkipButtons() {
        for btn in [prevButton, nextButton] {
            view.addSubview(btn)
            btn.bezelStyle = NSButton.BezelStyle.regularSquare
            btn.setButtonType(NSButton.ButtonType.momentaryPushIn)
            btn.imagePosition = NSControl.ImagePosition.imageOnly
            btn.isBordered = false
            btn.imageScaling = NSImageScaling.scaleNone
            btn.translatesAutoresizingMaskIntoConstraints = false
        }

        prevButton.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "Previous")
        prevButton.target = self
        prevButton.action = #selector(previousTrack)

        nextButton.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Next")
        nextButton.target = self
        nextButton.action = #selector(nextTrack)

        NSLayoutConstraint.activate([
            prevButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            prevButton.trailingAnchor.constraint(equalTo: playButton.leadingAnchor, constant: -4),
            prevButton.widthAnchor.constraint(equalToConstant: 20),
            prevButton.heightAnchor.constraint(equalToConstant: 20),

            nextButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            nextButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 4),
            nextButton.widthAnchor.constraint(equalToConstant: 20),
            nextButton.heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    /* ****************************************
     *
     * ****************************************/
    @objc private func refresh() {
        switch player.status {
            case Player.Status.paused:
                stationLabel.stringValue = player.stationName
                songLabel.stringValue = ""

            case Player.Status.connecting:
                stationLabel.stringValue = player.stationName
                songLabel.stringValue = NSLocalizedString("Connecting…", comment: "Station label text")

            case Player.Status.playing:
                // Naviola: show structured metadata for Navidrome tracks
                if let track = player.station as? NavidromeTrack {
                    songLabel.stringValue = track.title
                    var detail = [String]()
                    if let artist = track.artist { detail.append(artist) }
                    if let album = track.albumTitle { detail.append(album) }
                    stationLabel.stringValue = detail.joined(separator: " — ")
                } else {
                    stationLabel.stringValue = player.stationName
                    songLabel.stringValue = player.songTitle
                }
        }

        stationLabel.toolTip = stationLabel.stringValue
        songLabel.toolTip = songLabel.stringValue

        switch player.status {
            case Player.Status.paused:
                playButton.image = NSImage(named: NSImage.Name("NSTouchBarPlayTemplate"))
                playButton.image?.isTemplate = true
                playButton.toolTip = NSLocalizedString("Play", comment: "Toolbar button toolTip")

            case Player.Status.connecting:
                playButton.image = NSImage(named: NSImage.Name("NSTouchBarPauseTemplate"))
                playButton.image?.isTemplate = true
                playButton.toolTip = NSLocalizedString("Pause", comment: "Toolbar button toolTip")

            case Player.Status.playing:
                playButton.image = NSImage(named: NSImage.Name("NSTouchBarPauseTemplate"))
                playButton.image?.isTemplate = true
                playButton.toolTip = NSLocalizedString("Pause", comment: "Toolbar button toolTip")
        }

        onlyStationLabel.stringValue = stationLabel.stringValue
        onlyStationLabel.isVisible = songLabel.stringValue.isEmpty
        songLabel.isVisible = !onlyStationLabel.isVisible
        stationLabel.isVisible = !onlyStationLabel.isVisible

        // Naviola: update skip button state
        let queue = NaviolaPlayQueue.shared
        prevButton.isHidden = !queue.isActive
        nextButton.isHidden = !queue.isActive
        prevButton.isEnabled = queue.currentIndex > 0
        nextButton.isEnabled = queue.currentIndex + 1 < queue.tracks.count || queue.repeatMode != .off
    }

    /* ****************************************
     *
     * ****************************************/
    @objc private func togglePlay() {
        player.toggle()
    }

    // Naviola: skip/back actions
    @objc private func previousTrack() {
        NaviolaPlayQueue.shared.previous()
    }

    @objc private func nextTrack() {
        NaviolaPlayQueue.shared.next()
    }
}
