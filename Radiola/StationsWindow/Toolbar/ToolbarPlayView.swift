//
//  ToolbarPlayView.swift
//  Radiola
//
//  Naviola — Programmatic toolbar with transport controls, track info,
//  repeat/shuffle toggles, and live progress bar.
//

import Cocoa

class ToolbarPlayView: NSViewController {
    // Transport controls
    private let prevButton = NSButton()
    private let playButton = NSButton()
    private let nextButton = NSButton()

    // Track info
    private let songLabel = Label()
    private let stationLabel = Label()
    private let onlyStationLabel = Label()

    // Repeat/shuffle
    private let repeatButton = NSButton()
    private let shuffleButton = NSButton()

    // Progress (seekable slider)
    private let progressSlider = NSSlider()
    private let timeLabel = Label()
    private var isSeeking = false

    private var progressTimer: Timer?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 72))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTransportControls()
        setupTrackLabels()
        setupModeControls()
        setupProgressBar()
        setupLayout()

        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: Notification.Name.PlayerStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: Notification.Name.PlayerMetadataChanged, object: nil)

        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshProgress()
        }

        refresh()
    }

    deinit {
        progressTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupTransportControls() {
        // Play button — larger, prominent
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

        // Skip buttons — medium size
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
    }

    private func setupTrackLabels() {
        view.addSubview(songLabel)
        songLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        songLabel.textColor = .labelColor
        songLabel.lineBreakMode = .byTruncatingTail
        songLabel.usesSingleLineMode = true

        view.addSubview(stationLabel)
        stationLabel.font = NSFont.systemFont(ofSize: 11)
        stationLabel.textColor = .secondaryLabelColor
        stationLabel.lineBreakMode = .byTruncatingTail
        stationLabel.usesSingleLineMode = true

        view.addSubview(onlyStationLabel)
        onlyStationLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        onlyStationLabel.textColor = .labelColor
        onlyStationLabel.lineBreakMode = .byTruncatingTail
        onlyStationLabel.usesSingleLineMode = true
    }

    private func setupModeControls() {
        for btn in [repeatButton, shuffleButton] {
            view.addSubview(btn)
            btn.bezelStyle = .regularSquare
            btn.setButtonType(.momentaryPushIn)
            btn.imagePosition = .imageOnly
            btn.isBordered = false
            btn.imageScaling = .scaleProportionallyDown
        }

        repeatButton.target = self
        repeatButton.action = #selector(toggleRepeat)

        shuffleButton.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "Shuffle")
        shuffleButton.image?.isTemplate = true
        shuffleButton.target = self
        shuffleButton.action = #selector(toggleShuffle)
    }

    private func setupProgressBar() {
        view.addSubview(progressSlider)
        progressSlider.controlSize = .small
        progressSlider.minValue = 0
        progressSlider.maxValue = 1
        progressSlider.doubleValue = 0
        progressSlider.isContinuous = true
        progressSlider.target = self
        progressSlider.action = #selector(seekSliderChanged)

        view.addSubview(timeLabel)
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.alignment = .right
    }

    private func setupLayout() {
        let allViews: [NSView] = [prevButton, playButton, nextButton,
                                   songLabel, stationLabel, onlyStationLabel,
                                   repeatButton, shuffleButton,
                                   progressSlider, timeLabel]
        for v in allViews {
            v.translatesAutoresizingMaskIntoConstraints = false
            v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        // Fixed sizes for buttons
        prevButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        playButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        nextButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        repeatButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        shuffleButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        let btnSize: CGFloat = 22
        let smallBtnSize: CGFloat = 16

        NSLayoutConstraint.activate([
            // Row 1: [prev] [play] [next]  Song Title  [repeat] [shuffle]
            //         Artist — Album

            // Play button — center-left
            playButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            playButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            playButton.widthAnchor.constraint(equalToConstant: 32),
            playButton.heightAnchor.constraint(equalToConstant: 32),

            // Prev
            prevButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 4),
            prevButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: btnSize),
            prevButton.heightAnchor.constraint(equalToConstant: btnSize),

            // Next
            nextButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 4),
            nextButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: btnSize),
            nextButton.heightAnchor.constraint(equalToConstant: btnSize),

            // Song label
            songLabel.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 10),
            songLabel.bottomAnchor.constraint(equalTo: playButton.centerYAnchor, constant: -1),

            // Station label
            stationLabel.leadingAnchor.constraint(equalTo: songLabel.leadingAnchor),
            stationLabel.topAnchor.constraint(equalTo: playButton.centerYAnchor, constant: 2),

            // Only-station label
            onlyStationLabel.leadingAnchor.constraint(equalTo: songLabel.leadingAnchor),
            onlyStationLabel.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),

            // Shuffle (rightmost)
            shuffleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            shuffleButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            shuffleButton.widthAnchor.constraint(equalToConstant: smallBtnSize),
            shuffleButton.heightAnchor.constraint(equalToConstant: smallBtnSize),

            // Repeat
            repeatButton.trailingAnchor.constraint(equalTo: shuffleButton.leadingAnchor, constant: -8),
            repeatButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            repeatButton.widthAnchor.constraint(equalToConstant: smallBtnSize),
            repeatButton.heightAnchor.constraint(equalToConstant: smallBtnSize),

            // Labels trail before mode buttons
            songLabel.trailingAnchor.constraint(lessThanOrEqualTo: repeatButton.leadingAnchor, constant: -10),
            stationLabel.trailingAnchor.constraint(equalTo: songLabel.trailingAnchor),
            onlyStationLabel.trailingAnchor.constraint(equalTo: songLabel.trailingAnchor),

            // Row 2: Seekable slider + time label (below transport)
            progressSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            progressSlider.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 6),
            progressSlider.heightAnchor.constraint(equalToConstant: 14),

            timeLabel.leadingAnchor.constraint(equalTo: progressSlider.trailingAnchor, constant: 4),
            timeLabel.centerYAnchor.constraint(equalTo: progressSlider.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            progressSlider.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -4),
        ])
    }

    // MARK: - Refresh

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

        let hasSong = !songLabel.stringValue.isEmpty
        onlyStationLabel.stringValue = stationLabel.stringValue
        onlyStationLabel.isHidden = hasSong
        songLabel.isHidden = !hasSong
        stationLabel.isHidden = !hasSong

        // Skip buttons
        let queue = NaviolaPlayQueue.shared
        prevButton.isHidden = !queue.isActive
        nextButton.isHidden = !queue.isActive
        prevButton.isEnabled = queue.currentIndex > 0
        nextButton.isEnabled = queue.currentIndex + 1 < queue.tracks.count || queue.repeatMode != .off

        // Repeat/shuffle
        repeatButton.isHidden = !queue.isActive
        shuffleButton.isHidden = !queue.isActive

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

        shuffleButton.contentTintColor = queue.shuffleEnabled ? .controlAccentColor : .tertiaryLabelColor

        // Progress slider visibility
        progressSlider.isHidden = !queue.isActive
        timeLabel.isHidden = !queue.isActive

        refreshProgress()
    }

    private func refreshProgress() {
        // Don't update slider while user is dragging
        guard !isSeeking else { return }

        let avp = NaviolaAVPlayer.shared
        let current = avp.getCurrentTime()
        let dur = avp.duration

        if dur > 0 {
            progressSlider.doubleValue = current / dur
            timeLabel.stringValue = "\(formatTime(Int(current))) / \(formatTime(Int(dur)))"
        } else {
            progressSlider.doubleValue = 0
            timeLabel.stringValue = ""
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Actions

    @objc private func togglePlay() {
        if player.isPlaying { NaviolaPlayQueue.shared.userPause() }
        player.toggle()
    }

    @objc private func previousTrack() { NaviolaPlayQueue.shared.previous() }
    @objc private func nextTrack() { NaviolaPlayQueue.shared.next() }

    @objc private func seekSliderChanged() {
        let avp = NaviolaAVPlayer.shared
        guard avp.duration > 0 else { return }

        // While dragging, update time label but don't seek yet
        let targetTime = progressSlider.doubleValue * avp.duration
        timeLabel.stringValue = "\(formatTime(Int(targetTime))) / \(formatTime(Int(avp.duration)))"

        // Detect drag vs click: NSSlider sends continuous events while dragging
        if let event = NSApp.currentEvent {
            isSeeking = (event.type == .leftMouseDragged)
            if event.type == .leftMouseUp {
                // Drag ended or click — perform the seek
                isSeeking = false
                avp.seek(to: targetTime)

                // Update play queue's trackStartTime to account for the seek
                NaviolaPlayQueue.shared.trackStartTime = Date().addingTimeInterval(-targetTime)
            }
        }
    }

    @objc private func toggleRepeat() {
        let q = NaviolaPlayQueue.shared
        switch q.repeatMode {
        case .off: q.repeatMode = .all
        case .all: q.repeatMode = .one
        case .one: q.repeatMode = .off
        }
        refresh()
    }

    @objc private func toggleShuffle() {
        NaviolaPlayQueue.shared.shuffleEnabled.toggle()
        refresh()
    }
}
