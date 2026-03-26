//
//  NaviolaPlayQueue.swift
//  Naviola
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
    var trackStartTime: Date?

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
    /// Suspends the current queue if one is active (for resume).
    func playTracks(_ tracks: [NavidromeTrack], startingAt index: Int = 0) {
        guard !tracks.isEmpty, index < tracks.count else { return }

        // Suspend current queue so user can resume it later
        if isActive {
            suspendedTracks = self.tracks
            suspendedIndex = currentIndex
        }

        self.tracks = tracks
        startTrack(at: index)
    }

    /// Resolve a pinned item to tracks via Subsonic API and play.
    func play(item: NaviolaPinnedItem) {
        guard let client = NaviolaSettings.shared.makeClient() else { return }

        Task { @MainActor in
            do {
                var allTracks = [NavidromeTrack]()
                debug("[PlayQueue] Resolving pinned item: \(item.type.rawValue) '\(item.title)' id=\(item.subsonicId)")

                switch item.type {
                case .album:
                    let albumDetail = try await client.getAlbum(id: item.subsonicId)
                    allTracks = (albumDetail.song ?? []).map { NavidromeTrack(from: $0, client: client) }

                case .artist:
                    let artist = try await client.getArtist(id: item.subsonicId)
                    for album in artist.album ?? [] {
                        let detail = try await client.getAlbum(id: album.id)
                        allTracks.append(contentsOf: (detail.song ?? []).map { NavidromeTrack(from: $0, client: client) })
                    }

                case .playlist:
                    let playlist = try await client.getPlaylist(id: item.subsonicId)
                    allTracks = (playlist.entry ?? []).map { NavidromeTrack(from: $0, client: client) }

                case .genre:
                    debug("[PlayQueue] Fetching genre albums for '\(item.subsonicId)'")
                    let albums = try await client.getAlbumList2(type: "byGenre", size: 10, genre: item.subsonicId)
                    debug("[PlayQueue] Got \(albums.count) albums for genre")
                    for album in albums {
                        debug("[PlayQueue] Fetching tracks for album '\(album.name)' id=\(album.id)")
                        let detail = try await client.getAlbum(id: album.id)
                        let tracks = (detail.song ?? []).map { NavidromeTrack(from: $0, client: client) }
                        debug("[PlayQueue] Got \(tracks.count) tracks")
                        allTracks.append(contentsOf: tracks)
                    }

                case .track:
                    // Single track — just play it directly
                    let track = NavidromeTrack(title: item.title, url: client.streamURL(songId: item.subsonicId).absoluteString, navidromeId: item.subsonicId)
                    allTracks = [track]
                }

                if !allTracks.isEmpty {
                    playTracks(allTracks)
                }
                debug("[PlayQueue] Resolved \(allTracks.count) tracks")
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

    /// Suspend the queue — saves state for later resume. Used when switching to radio.
    func suspend() {
        guard isActive else { return }
        suspendedTracks = tracks
        suspendedIndex = currentIndex
        tracks = []
        currentIndex = -1
        trackStartTime = nil
        userDidPause = false
        confirmedPlaying = false
    }

    /// Resume a previously suspended queue. Returns true if resumed.
    @discardableResult
    func resume() -> Bool {
        guard !suspendedTracks.isEmpty, suspendedIndex >= 0, suspendedIndex < suspendedTracks.count else { return false }
        playTracks(suspendedTracks, startingAt: suspendedIndex)
        suspendedTracks = []
        suspendedIndex = -1
        return true
    }

    var canResume: Bool {
        return !suspendedTracks.isEmpty && suspendedIndex >= 0
    }

    var resumeDescription: String? {
        guard canResume, suspendedIndex < suspendedTracks.count else { return nil }
        let track = suspendedTracks[suspendedIndex]
        return "\(track.artist ?? "") — \(track.title)"
    }

    /// Clear the queue completely (no suspend).
    func stop() {
        tracks = []
        currentIndex = -1
        suspendedTracks = []
        suspendedIndex = -1
        trackStartTime = nil
        userDidPause = false
        confirmedPlaying = false
    }

    private var suspendedTracks: [NavidromeTrack] = []
    private var suspendedIndex: Int = -1

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

            // Track ended naturally. FFPlayer now drains audio buffers before
            // reporting .paused, so the full track has been heard. Advance
            // immediately.
            trackStartTime = nil
            confirmedPlaying = false
            let expectedGen = playGeneration
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.playGeneration == expectedGen else { return }
                self.next()
            }
        }
    }
}
