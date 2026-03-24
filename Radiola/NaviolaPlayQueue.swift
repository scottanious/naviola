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

    var isActive: Bool { !tracks.isEmpty && currentIndex >= 0 }

    var currentTrack: NavidromeTrack? {
        guard isActive, currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }

    private var wasPlaying = false

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
        self.wasPlaying = true

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

    /// Advance to the next track. Returns false if at end.
    @discardableResult
    func next() -> Bool {
        guard isActive, currentIndex + 1 < tracks.count else {
            stop()
            return false
        }

        currentIndex += 1
        player.station = tracks[currentIndex]
        player.play()
        return true
    }

    /// Clear the queue. Does not stop the currently playing track.
    func stop() {
        tracks = []
        currentIndex = -1
        wasPlaying = false
    }

    // MARK: - Auto-Advance

    @objc private func playerStatusChanged() {
        if player.status == .playing {
            wasPlaying = true
            return
        }

        // When player transitions to paused and we were playing, try to advance
        if player.status == .paused && wasPlaying && isActive {
            wasPlaying = false

            // Check if the paused station matches our current queue track
            // (avoids advancing if user switched to a different station)
            if let currentTrack = currentTrack,
               player.station?.id == currentTrack.id {
                // Small delay to let FFPlayer fully clean up before starting next track
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.next()
                }
            }
        }
    }
}
