//
//  NaviolaPlayQueue.swift
//  Radiola
//
//  Naviola — Sequential playback queue with auto-advance.
//  Sits alongside Player, observes state changes to advance
//  to the next track when current track ends.
//

import Foundation

class NaviolaPlayQueue: ObservableObject {
    static let shared = NaviolaPlayQueue()

    @Published var tracks: [NavidromeTrack] = []
    @Published var currentIndex: Int = -1

    enum RepeatMode: Int {
        case off = 0
        case all = 1
        case one = 2
    }

    var repeatMode: RepeatMode {
        get { RepeatMode(rawValue: UserDefaults.standard.integer(forKey: "NaviolaRepeatMode")) ?? .off }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "NaviolaRepeatMode") }
    }

    var shuffleEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "NaviolaShuffleEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "NaviolaShuffleEnabled") }
    }

    var isActive: Bool { !tracks.isEmpty && currentIndex >= 0 }

    var currentTrack: NavidromeTrack? {
        guard isActive, currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }

    /// Set when we're intentionally switching tracks — prevents the observer
    /// from treating the intermediate stop() as a track-end event.
    private var isChangingTrack = false

    /// When the current track started playing — used to determine if a track
    /// ended naturally (elapsed ≈ duration) vs user paused mid-track.
    private var trackStartTime: Date?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerStatusChanged),
            name: Notification.Name.PlayerStatusChanged,
            object: nil
        )
    }

    // MARK: - Playback Control

    /// Load tracks and start playing from the given index.
    func playTracks(_ tracks: [NavidromeTrack], startingAt index: Int = 0) {
        guard !tracks.isEmpty, index < tracks.count else { return }

        self.tracks = tracks
        self.currentIndex = index
        isChangingTrack = true
        trackStartTime = nil

        player.station = tracks[index]
        player.play()
    }

    /// Resolve a pinned item to tracks via Subsonic API and play.
    func play(item: NaviolaPinnedItem) {
        guard let client = NaviolaSettings.shared.makeClient() else { return }

        Task { @MainActor in
            do {
                switch item.type {
                case .album:
                    let albumDetail = try await client.getAlbum(id: item.subsonicId)
                    let tracks = (albumDetail.song ?? []).map { NavidromeTrack(from: $0, client: client) }
                    playTracks(tracks)
                default:
                    // Future: resolve artists, genres, playlists, etc.
                    break
                }
            } catch {
                warning("Failed to resolve pinned item \(item.title): \(error)")
            }
        }
    }

    /// Advance to the next track. Returns false if at end (and not repeating).
    @discardableResult
    func next() -> Bool {
        guard isActive else { return false }

        // Repeat one: replay the same track
        if repeatMode == .one {
            isChangingTrack = true
            trackStartTime = nil
            player.station = tracks[currentIndex]
            player.play()
            return true
        }

        // Shuffle: pick a random different track
        if shuffleEnabled && tracks.count > 1 {
            var nextIndex = currentIndex
            while nextIndex == currentIndex {
                nextIndex = Int.random(in: 0 ..< tracks.count)
            }
            currentIndex = nextIndex
            isChangingTrack = true
            trackStartTime = nil
            player.station = tracks[currentIndex]
            player.play()
            return true
        }

        // Sequential: advance or loop
        if currentIndex + 1 < tracks.count {
            currentIndex += 1
        } else if repeatMode == .all {
            currentIndex = 0
        } else {
            stop()
            return false
        }

        isChangingTrack = true
        trackStartTime = nil
        player.station = tracks[currentIndex]
        player.play()
        return true
    }

    /// Go to the previous track. Returns false if at start.
    @discardableResult
    func previous() -> Bool {
        guard isActive, currentIndex > 0 else { return false }

        currentIndex -= 1
        isChangingTrack = true
        trackStartTime = nil
        player.station = tracks[currentIndex]
        player.play()
        return true
    }

    /// Clear the queue. Does not stop the currently playing track.
    func stop() {
        tracks = []
        currentIndex = -1
        isChangingTrack = false
        trackStartTime = nil
    }

    // MARK: - Auto-Advance

    @objc private func playerStatusChanged() {
        switch player.status {
        case .playing:
            // Track started playing — clear the changing flag, record start time
            isChangingTrack = false
            trackStartTime = Date()

        case .connecting:
            break

        case .paused:
            // Ignore if we're in the middle of a track switch (play() calls stop() internally)
            guard !isChangingTrack else { return }

            // Nothing to advance if queue isn't active
            guard isActive else { return }

            // Verify this is still our track
            guard let current = currentTrack, player.station?.id == current.id else {
                // User switched to a different station — clear queue
                stop()
                return
            }

            // Determine if the track ended naturally by comparing elapsed time to duration.
            // If elapsed >= (duration - tolerance), the track played through → advance.
            // Otherwise, the user paused mid-track → stop the queue.
            let tolerance: TimeInterval = 5.0
            if let startTime = trackStartTime,
               let duration = current.duration,
               duration > 0 {
                let elapsed = Date().timeIntervalSince(startTime)
                let trackDuration = Double(duration)

                if elapsed >= trackDuration - tolerance {
                    // Track ended naturally — advance after a brief cleanup delay
                    trackStartTime = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.next()
                    }
                } else {
                    // User paused mid-track — stop the queue
                    stop()
                }
            } else {
                // No duration info or start time — can't determine, stop queue
                stop()
            }
        }
    }
}
