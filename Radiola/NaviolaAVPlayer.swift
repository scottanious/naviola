//
//  NaviolaAVPlayer.swift
//  Radiola
//
//  Naviola — AVFoundation-based audio player for Navidrome streams.
//  Handles MP3/AAC/FLAC/Opus files correctly, including those with
//  large ID3 tags that the bundled FFmpeg mishandles.
//
//  Used for Navidrome URLs; FFPlayer remains for radio streams.
//

import AVFoundation
import Foundation

class NaviolaAVPlayer: ObservableObject {
    static let shared = NaviolaAVPlayer()

    private var avPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObserver: NSKeyValueObservation?
    private var endObserver: Any?

    enum State {
        case stopped
        case connecting
        case playing
        case error
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    var volume: Float = 1.0 {
        didSet { avPlayer?.volume = volume }
    }

    var isMuted: Bool = false {
        didSet { avPlayer?.isMuted = isMuted }
    }

    // MARK: - Playback

    func play(url: URL) {
        stop()

        state = .connecting
        debug("[NaviolaAVPlayer] Playing \(url.absoluteString)")

        playerItem = AVPlayerItem(url: url)
        avPlayer = AVPlayer(playerItem: playerItem!)
        avPlayer?.volume = volume
        avPlayer?.isMuted = isMuted

        // Observe status to know when playback is ready
        statusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.state = .playing
                    self?.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    debug("[NaviolaAVPlayer] Ready to play, duration: \(self?.duration ?? 0)s")
                case .failed:
                    self?.state = .error
                    warning("[NaviolaAVPlayer] Failed: \(item.error?.localizedDescription ?? "unknown")")
                default:
                    break
                }
            }
        }

        // Observe when track finishes
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            debug("[NaviolaAVPlayer] Track finished playing")
            self?.state = .stopped
        }

        avPlayer?.play()
    }

    func stop() {
        avPlayer?.pause()
        avPlayer = nil

        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        playerItem = nil

        if state != .stopped {
            state = .stopped
        }
        currentTime = 0
        duration = 0
    }

    func pause() {
        avPlayer?.pause()
        // Don't change state — we're paused but not stopped
    }

    func resume() {
        avPlayer?.play()
    }

    var isPlaying: Bool {
        return avPlayer?.rate ?? 0 > 0
    }

    /// Get current playback position in seconds.
    func getCurrentTime() -> Double {
        guard let time = avPlayer?.currentTime(), time.isValid, !time.isIndefinite else { return 0 }
        return time.seconds
    }
}
