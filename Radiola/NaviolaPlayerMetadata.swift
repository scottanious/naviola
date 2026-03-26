//
//  NaviolaPlayerMetadata.swift
//  Naviola
//
//  Naviola — Surfaces structured metadata from NavidromeTrack to the Player
//  and MPNowPlayingInfoCenter. FFPlayer's ICY stream metadata works for radio
//  but is blank for Navidrome file playback. This bridges the gap.
//

import Foundation
import MediaPlayer

class NaviolaPlayerMetadata {
    static let shared = NaviolaPlayerMetadata()

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerStatusChanged),
            name: Notification.Name.PlayerStatusChanged,
            object: nil
        )
    }

    @objc private func playerStatusChanged() {
        guard player.status == .playing || player.status == .connecting else { return }
        guard let track = player.station as? NavidromeTrack else { return }

        // Build song title from structured metadata
        let songTitle: String
        if let artist = track.artist, !artist.isEmpty {
            songTitle = "\(artist) - \(track.title)"
        } else {
            songTitle = track.title
        }

        // Only update if the Player doesn't already have metadata
        // (gives ICY metadata a chance to override if present)
        if player.songTitle.isEmpty {
            player.songTitle = songTitle
            NotificationCenter.default.post(
                name: Notification.Name.PlayerMetadataChanged,
                object: nil,
                userInfo: ["title": songTitle]
            )
        }

        // Update MPNowPlayingInfoCenter with structured info
        updateNowPlayingInfo(track: track)
    }

    private func updateNowPlayingInfo(track: NavidromeTrack) {
        var info: [String: Any] = [:]

        info[MPMediaItemPropertyTitle] = track.title

        if let artist = track.artist {
            info[MPMediaItemPropertyArtist] = artist
        }

        if let album = track.albumTitle {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        if let duration = track.duration {
            info[MPMediaItemPropertyPlaybackDuration] = Double(duration)
        }

        if let trackNum = track.trackNumber {
            info[MPMediaItemPropertyAlbumTrackNumber] = trackNum
        }

        let queue = NaviolaPlayQueue.shared
        if queue.isActive {
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = queue.tracks.count
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = queue.currentIndex
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
