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

    /// When the current track started playing.
    private(set) var trackStartTime: Date?

    /// Set by userPause() to prevent auto-advance when user explicitly pauses.
    private var userDidPause = false

    /// Incremented each time we start a new track. Used to ignore stale
    /// .paused notifications from previous tracks arriving out of order.
    private var playGeneration: Int = 0

    /// Whether the current generation has confirmed .playing state.
    private var confirmedPlaying = false

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerStatusChanged),
            name: Notification.Name.PlayerStatusChanged,
            object: nil
        )
    }

    // MARK: - Playback Control

    /// Start a new track — increments generation to ignore stale notifications.
    private func startTrack(at index: Int) {
        currentIndex = index
        playGeneration += 1
        confirmedPlaying = false
        trackStartTime = nil
        userDidPause = false

        player.station = tracks[index]
        player.play()
    }

    /// Load tracks and start playing from the given index.
    func playTracks(_ tracks: [NavidromeTrack], startingAt index: Int = 0) {
        guard !tracks.isEmpty, index < tracks.count else { return }

        self.tracks = tracks
        startTrack(at: index)
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
                    break
                }
            } catch {
                warning("Failed to resolve pinned item \(item.title): \(error)")
            }
        }
    }

    /// Call this when the user explicitly pauses/stops playback.
    func userPause() {
        userDidPause = true
    }

    /// Advance to the next track. Returns false if at end (and not repeating).
    @discardableResult
    func next() -> Bool {
        guard isActive else { return false }

        // Repeat one: replay the same track
        if repeatMode == .one {
            startTrack(at: currentIndex)
            return true
        }

        // Shuffle: pick a random different track
        if shuffleEnabled && tracks.count > 1 {
            var nextIndex = currentIndex
            while nextIndex == currentIndex {
                nextIndex = Int.random(in: 0 ..< tracks.count)
            }
            startTrack(at: nextIndex)
            return true
        }

        // Sequential: advance or loop
        if currentIndex + 1 < tracks.count {
            startTrack(at: currentIndex + 1)
            return true
        } else if repeatMode == .all {
            startTrack(at: 0)
            return true
        } else {
            stop()
            return false
        }
    }

    /// Go to the previous track. Returns false if at start.
    @discardableResult
    func previous() -> Bool {
        guard isActive, currentIndex > 0 else { return false }
        startTrack(at: currentIndex - 1)
        return true
    }

    /// Clear the queue. Does not stop the currently playing track.
    func stop() {
        tracks = []
        currentIndex = -1
        trackStartTime = nil
        userDidPause = false
        confirmedPlaying = false
    }

    // MARK: - Auto-Advance

    @objc private func playerStatusChanged() {
        let gen = playGeneration

        switch player.status {
        case .playing:
            // Only accept .playing for the current generation
            if gen == playGeneration {
                confirmedPlaying = true
                trackStartTime = Date()
                userDidPause = false
            }

        case .connecting:
            break

        case .paused:
            // Ignore if queue isn't active
            guard isActive else { return }

            // User explicitly paused — don't advance
            if userDidPause {
                userDidPause = false
                return
            }

            // Only advance if we confirmed this generation actually played.
            // This prevents stale .paused from a previous track's stop()
            // arriving after the new track's .playing.
            guard confirmedPlaying else { return }

            // Verify this is still our track
            guard let current = currentTrack, player.station?.id == current.id else {
                stop()
                return
            }

            // Must have played for at least 2 seconds (guards against rapid
            // state transitions during track startup)
            if let startTime = trackStartTime, Date().timeIntervalSince(startTime) < 2.0 {
                return
            }

            // Track ended naturally — wait for audio buffers to drain before advancing.
            // FFPlayer's decoder hits EOF before the audio queue finishes playing
            // the last few seconds of buffered audio. A longer delay ensures the
            // listener hears the full track.
            trackStartTime = nil
            confirmedPlaying = false
            let expectedGen = playGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, self.playGeneration == expectedGen else { return }
                self.next()
            }
        }
    }
}
