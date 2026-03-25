//
//  NaviolaPlaybackMenu.swift
//  Radiola
//
//  Naviola — Compact playback and volume controls as a unified section
//  in the status bar menu.
//

import Cocoa

// MARK: - NaviolaPlaybackMenu

class NaviolaPlaybackMenu {
    static func addControls(to menu: NSMenu, showVolume: Bool, showMute: Bool) {
        let queue = NaviolaPlayQueue.shared
        guard queue.isActive else { return }

        menu.addItem(NSMenuItem.separator())

        // Playback row: [<<] [>>] [0:45/3:12] [2/15] [repeat] [shuffle]
        let playbackItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        playbackItem.view = NaviolaPlaybackView()
        menu.addItem(playbackItem)

        // Volume row
        let volumeItem = VolumeMenuItem(showMuteButton: showMute)
        menu.addItem(volumeItem)
    }
}

// MARK: - NaviolaPlaybackView

fileprivate class NaviolaPlaybackView: NSView {
    private let prevButton = ControlButton(systemSymbolName: "backward.fill")
    private let nextButton = ControlButton(systemSymbolName: "forward.fill")
    private let timeLabel = Label()
    private let positionLabel = Label()
    private let repeatButton = ControlButton(systemSymbolName: "repeat")
    private let shuffleButton = ControlButton(systemSymbolName: "shuffle")
    private var updateTimer: Timer?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        autoresizingMask = [.width]

        for v in [prevButton, nextButton, timeLabel, positionLabel, repeatButton, shuffleButton] {
            addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        prevButton.target = self
        prevButton.action = #selector(prevClicked)
        nextButton.target = self
        nextButton.action = #selector(nextClicked)
        repeatButton.target = self
        repeatButton.action = #selector(repeatClicked)
        shuffleButton.target = self
        shuffleButton.action = #selector(shuffleClicked)

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.alignment = .center
        timeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        positionLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        positionLabel.textColor = .tertiaryLabelColor
        positionLabel.alignment = .center
        positionLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let iconSize: CGFloat = 10

        NSLayoutConstraint.activate([
            // Left group: skip buttons
            prevButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            prevButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: iconSize),
            prevButton.heightAnchor.constraint(equalToConstant: iconSize),

            nextButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 14),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: iconSize),
            nextButton.heightAnchor.constraint(equalToConstant: iconSize),

            // Center: time + position — pinned to horizontal midline
            positionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: centerXAnchor, constant: -2),
            positionLabel.leadingAnchor.constraint(equalTo: centerXAnchor, constant: 2),

            // Right group: repeat + shuffle
            repeatButton.leadingAnchor.constraint(greaterThanOrEqualTo: positionLabel.trailingAnchor, constant: 8),
            repeatButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            repeatButton.widthAnchor.constraint(equalToConstant: iconSize),
            repeatButton.heightAnchor.constraint(equalToConstant: iconSize),

            shuffleButton.leadingAnchor.constraint(equalTo: repeatButton.trailingAnchor, constant: 14),
            shuffleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            shuffleButton.widthAnchor.constraint(equalToConstant: iconSize),
            shuffleButton.heightAnchor.constraint(equalToConstant: iconSize),
            shuffleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
        ])

        refresh()

        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: Notification.Name.PlayerStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: Notification.Name.PlayerMetadataChanged, object: nil)

        // Update time display every second while visible
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshTime()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        updateTimer?.invalidate()
    }

    @objc private func refresh() {
        let queue = NaviolaPlayQueue.shared

        prevButton.isEnabled = queue.currentIndex > 0
        nextButton.isEnabled = queue.currentIndex + 1 < queue.tracks.count || queue.repeatMode != .off

        refreshTime()

        // Position: "2/15"
        if queue.isActive {
            positionLabel.stringValue = "\(queue.currentIndex + 1)/\(queue.tracks.count)"
        } else {
            positionLabel.stringValue = ""
        }

        // Repeat
        switch queue.repeatMode {
        case .off:
            repeatButton.image = NSImage(systemSymbolName: "repeat", accessibilityDescription: "Repeat off")
            repeatButton.contentTintColor = .tertiaryLabelColor
        case .all:
            repeatButton.image = NSImage(systemSymbolName: "repeat", accessibilityDescription: "Repeat all")
            repeatButton.contentTintColor = .controlAccentColor
        case .one:
            repeatButton.image = NSImage(systemSymbolName: "repeat.1", accessibilityDescription: "Repeat one")
            repeatButton.contentTintColor = .controlAccentColor
        }

        // Shuffle
        shuffleButton.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "Shuffle")
        shuffleButton.contentTintColor = queue.shuffleEnabled ? .controlAccentColor : .tertiaryLabelColor
    }

    private func refreshTime() {
        let queue = NaviolaPlayQueue.shared
        if let track = queue.currentTrack, let duration = track.duration, duration > 0,
           let startTime = queue.trackStartTime {
            let elapsed = min(Int(Date().timeIntervalSince(startTime)), duration)
            timeLabel.stringValue = "\(formatTime(elapsed)) / \(formatTime(duration))"
        } else if let track = queue.currentTrack, let duration = track.duration, duration > 0 {
            timeLabel.stringValue = "0:00 / \(formatTime(duration))"
        } else {
            timeLabel.stringValue = ""
        }
        // Force NSMenu to redraw this custom view
        needsDisplay = true
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    @objc private func prevClicked() { NaviolaPlayQueue.shared.previous() }
    @objc private func nextClicked() { NaviolaPlayQueue.shared.next() }

    @objc private func repeatClicked() {
        let q = NaviolaPlayQueue.shared
        switch q.repeatMode {
        case .off: q.repeatMode = .all
        case .all: q.repeatMode = .one
        case .one: q.repeatMode = .off
        }
        refresh()
    }

    @objc private func shuffleClicked() {
        NaviolaPlayQueue.shared.shuffleEnabled.toggle()
        refresh()
    }
}

// MARK: - ControlButton

/// Tiny icon button with consistent sizing for the playback row.
fileprivate class ControlButton: NSButton {
    init(systemSymbolName: String) {
        super.init(frame: NSRect())
        self.image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)
        self.image?.isTemplate = true
        bezelStyle = .shadowlessSquare
        isBordered = false
        setButtonType(.momentaryPushIn)
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseUp(with event: NSEvent) {
        // Block event propagation to prevent menu from closing
        sendAction(action, to: target)
    }
}
