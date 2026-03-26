//
//  NowPlayingDelegate.swift
//  Naviola
//
//  Naviola — Read-only view of the current play queue.
//  Shows all tracks with the currently playing track highlighted.
//

import Cocoa

// MARK: - NowPlayingDelegate

class NowPlayingDelegate: NSObject {
    private weak var outlineView: NSOutlineView!
    private let queue = NaviolaPlayQueue.shared

    init(outlineView: NSOutlineView) {
        self.outlineView = outlineView
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: Notification.Name.PlayerStatusChanged,
            object: nil
        )
    }

    @objc func refresh() {
        outlineView?.reloadData()

        // Scroll to and highlight the current track
        if queue.isActive, queue.currentIndex >= 0, queue.currentIndex < queue.tracks.count {
            outlineView?.scrollRowToVisible(queue.currentIndex)
        }
    }
}

// MARK: - NSOutlineViewDelegate

extension NowPlayingDelegate: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let track = item as? NavidromeTrack else { return nil }

        let isCurrent = queue.currentTrack?.id == track.id
        return NowPlayingTrackRow(track: track, index: queue.tracks.firstIndex(where: { $0.id == track.id }), isCurrent: isCurrent)
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return CGFloat(32.0)
    }

    // Disable selection — read-only view
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return false
    }
}

// MARK: - NSOutlineViewDataSource

extension NowPlayingDelegate: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return queue.tracks.count }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return queue.tracks[index] }
        return ""
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
}

// MARK: - NowPlayingTrackRow

fileprivate class NowPlayingTrackRow: NSView {
    init(track: NavidromeTrack, index: Int?, isCurrent: Bool) {
        super.init(frame: NSRect())

        let numberLabel = Label()
        numberLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        numberLabel.alignment = .right
        numberLabel.textColor = isCurrent ? .controlAccentColor : .tertiaryLabelColor
        numberLabel.stringValue = index != nil ? "\(index! + 1)" : ""

        let playingIcon = NSImageView()
        if isCurrent {
            playingIcon.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Playing")
            playingIcon.contentTintColor = .controlAccentColor
        }

        let titleLabel = Label()
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: isCurrent ? .semibold : .regular)
        titleLabel.textColor = isCurrent ? .controlAccentColor : .labelColor
        titleLabel.stringValue = track.title
        titleLabel.lineBreakMode = .byTruncatingTail

        let artistLabel = Label()
        artistLabel.font = NSFont.systemFont(ofSize: 11)
        artistLabel.textColor = isCurrent ? .controlAccentColor.withAlphaComponent(0.7) : .secondaryLabelColor
        artistLabel.stringValue = track.artist ?? ""

        let durationLabel = Label()
        durationLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        durationLabel.textColor = .tertiaryLabelColor
        durationLabel.alignment = .right
        if let d = track.duration, d > 0 {
            durationLabel.stringValue = String(format: "%d:%02d", d / 60, d % 60)
        }

        let separator = Separator()

        addSubview(numberLabel)
        addSubview(playingIcon)
        addSubview(titleLabel)
        addSubview(artistLabel)
        addSubview(durationLabel)
        addSubview(separator)

        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        playingIcon.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false

        artistLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        NSLayoutConstraint.activate([
            numberLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            numberLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            numberLabel.widthAnchor.constraint(equalToConstant: 24),

            playingIcon.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 4),
            playingIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            playingIcon.widthAnchor.constraint(equalToConstant: 14),
            playingIcon.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.leadingAnchor.constraint(equalTo: playingIcon.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            artistLabel.leadingAnchor.constraint(equalToSystemSpacingAfter: titleLabel.trailingAnchor, multiplier: 1),
            artistLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            durationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            durationLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 40),

            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: durationLabel.leadingAnchor, constant: -8),
            artistLabel.trailingAnchor.constraint(lessThanOrEqualTo: durationLabel.leadingAnchor, constant: -8),
        ])

        separator.alignBottom(of: self)
    }

    required init?(coder: NSCoder) { fatalError() }
}
