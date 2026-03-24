//
//  NaviolaPlaybackMenu.swift
//  Radiola
//
//  Naviola — Compact playback and volume controls as a unified "Controls"
//  section in the status bar menu. Follows the VolumeMenuItem pattern.
//

import Cocoa

// MARK: - NaviolaPlaybackMenu

class NaviolaPlaybackMenu {
    /// Add consolidated controls section (playback + volume) when play queue is active.
    static func addControls(to menu: NSMenu, showVolume: Bool, showMute: Bool) {
        let queue = NaviolaPlayQueue.shared
        guard queue.isActive else { return }

        menu.addItem(NSMenuItem.separator())

        // Playback controls row: [<<] [>>] [===progress===] [2/10] [repeat] [shuffle]
        let playbackItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        playbackItem.view = NaviolaPlaybackView()
        menu.addItem(playbackItem)

        // Volume row (always shown when queue is active)
        let volumeItem = VolumeMenuItem(showMuteButton: showMute)
        menu.addItem(volumeItem)
    }
}

// MARK: - NaviolaPlaybackView

fileprivate class NaviolaPlaybackView: NSView {
    private let prevButton = ImageButton(systemSymbolName: "backward.fill", accessibilityDescription: "Previous")
    private let nextButton = ImageButton(systemSymbolName: "forward.fill", accessibilityDescription: "Next")
    private let repeatButton = ImageButton()
    private let shuffleButton = ImageButton()
    private let progressSlider = NSSlider()
    private let positionLabel = Label()

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 28))
        autoresizingMask = [.width]
        setupViews()
        refresh()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refresh),
                                               name: Notification.Name.PlayerStatusChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refresh),
                                               name: Notification.Name.PlayerMetadataChanged,
                                               object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(prevButton)
        addSubview(nextButton)
        addSubview(progressSlider)
        addSubview(repeatButton)
        addSubview(shuffleButton)
        addSubview(positionLabel)

        prevButton.target = self
        prevButton.action = #selector(prevClicked)

        nextButton.target = self
        nextButton.action = #selector(nextClicked)

        repeatButton.target = self
        repeatButton.action = #selector(repeatClicked)

        shuffleButton.target = self
        shuffleButton.action = #selector(shuffleClicked)

        // Progress slider — display-only for now (seek requires FFPlayer changes)
        progressSlider.controlSize = .small
        progressSlider.minValue = 0
        progressSlider.maxValue = 1
        progressSlider.doubleValue = 0
        progressSlider.isEnabled = false // Display-only until seek is implemented
        progressSlider.isContinuous = true

        positionLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        positionLabel.textColor = .secondaryLabelColor
        positionLabel.alignment = .center

        for v in [prevButton, nextButton, repeatButton, shuffleButton, progressSlider, positionLabel] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        let btnSize: CGFloat = 12

        NSLayoutConstraint.activate([
            prevButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            prevButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: btnSize),
            prevButton.heightAnchor.constraint(equalToConstant: btnSize),

            nextButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 10),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: btnSize),
            nextButton.heightAnchor.constraint(equalToConstant: btnSize),

            progressSlider.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 10),
            progressSlider.centerYAnchor.constraint(equalTo: centerYAnchor),

            positionLabel.leadingAnchor.constraint(equalTo: progressSlider.trailingAnchor, constant: 4),
            positionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            positionLabel.widthAnchor.constraint(equalToConstant: 30),

            repeatButton.leadingAnchor.constraint(equalTo: positionLabel.trailingAnchor, constant: 6),
            repeatButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            repeatButton.widthAnchor.constraint(equalToConstant: btnSize),
            repeatButton.heightAnchor.constraint(equalToConstant: btnSize),

            shuffleButton.leadingAnchor.constraint(equalTo: repeatButton.trailingAnchor, constant: 8),
            shuffleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            shuffleButton.widthAnchor.constraint(equalToConstant: btnSize),
            shuffleButton.heightAnchor.constraint(equalToConstant: btnSize),
            shuffleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])
    }

    @objc private func refresh() {
        let queue = NaviolaPlayQueue.shared

        prevButton.isEnabled = queue.currentIndex > 0
        nextButton.isEnabled = queue.currentIndex + 1 < queue.tracks.count || queue.repeatMode != .off

        // Repeat icon
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

        shuffleButton.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "Shuffle")
        shuffleButton.contentTintColor = queue.shuffleEnabled ? .controlAccentColor : .tertiaryLabelColor

        // Position
        if queue.isActive {
            positionLabel.stringValue = "\(queue.currentIndex + 1)/\(queue.tracks.count)"
        } else {
            positionLabel.stringValue = ""
        }

        // Progress
        if let track = queue.currentTrack, let duration = track.duration, duration > 0,
           let startTime = queue.trackStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            progressSlider.doubleValue = min(elapsed / Double(duration), 1.0)
        } else {
            progressSlider.doubleValue = 0
        }
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
