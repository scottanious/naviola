//
//  NavidromeStations.swift
//  Radiola
//
//  Naviola — Station types for Navidrome content.
//  NavidromeTrack conforms to Station so it plugs directly into Player.
//  Parallel to InternetStations.swift.
//

import Foundation

// MARK: - NavidromeTrack

class NavidromeTrack: Station, Identifiable {
    var id = UUID()
    var title: String
    var url: String
    var isFavorite: Bool = false

    var artist: String?
    var albumTitle: String?
    var duration: Int?
    var trackNumber: Int?
    var navidromeId: String

    init(title: String, url: String, navidromeId: String) {
        self.title = title
        self.url = url
        self.navidromeId = navidromeId
    }

    /// Create from a Subsonic Child (song) using the given client for stream URL.
    convenience init(from song: SubsonicChild, client: NavidromeClient) {
        let streamURL = client.streamURL(songId: song.id).absoluteString
        self.init(title: song.title, url: streamURL, navidromeId: song.id)
        self.artist = song.artist
        self.albumTitle = song.album
        self.duration = song.duration
        self.trackNumber = song.track
    }
}

// MARK: - NavidromeAlbum

class NavidromeAlbum: Identifiable {
    let id = UUID()
    var title: String
    var artist: String?
    var navidromeId: String
    var coverArtId: String?
    var year: Int?
    var songCount: Int?
    var tracks: [NavidromeTrack] = []
    var tracksLoaded: Bool = false

    init(title: String, navidromeId: String) {
        self.title = title
        self.navidromeId = navidromeId
    }

    /// Create from a Subsonic AlbumID3.
    convenience init(from album: SubsonicAlbumID3) {
        self.init(title: album.name, navidromeId: album.id)
        self.artist = album.artist
        self.coverArtId = album.coverArt
        self.year = album.year
        self.songCount = album.songCount
    }

    /// Load tracks from the server if not already loaded.
    @MainActor func loadTracks() async throws {
        guard !tracksLoaded, let client = NaviolaSettings.shared.makeClient() else { return }

        let albumDetail = try await client.getAlbum(id: navidromeId)
        tracks = (albumDetail.song ?? []).map { NavidromeTrack(from: $0, client: client) }
        tracksLoaded = true
    }
}

// MARK: - NavidromeAlbumList

class NavidromeAlbumList: ObservableObject {
    let id = UUID()
    let title: String
    let icon: String

    var items = [NavidromeAlbum]()

    enum State {
        case notLoaded
        case loading
        case error
        case loaded
    }

    @Published var state = State.notLoaded

    let provider: NavidromeProvider

    init(title: String, icon: String, provider: NavidromeProvider) {
        self.title = title
        self.icon = icon
        self.provider = provider
    }

    @MainActor func fetch() async {
        state = .loading

        if !provider.canFetch() {
            state = .notLoaded
            return
        }

        do {
            let albums = try await provider.fetch()
            items = albums.map { NavidromeAlbum(from: $0) }
            state = .loaded
        } catch {
            state = .error
            warning(error)
        }
    }

    func firstAlbum(byID: UUID) -> NavidromeAlbum? {
        return items.first { $0.id == byID }
    }

    /// Find a track across all albums.
    func firstTrack(byID: UUID) -> NavidromeTrack? {
        for album in items {
            if let track = album.tracks.first(where: { $0.id == byID }) {
                return track
            }
        }
        return nil
    }
}

extension [NavidromeAlbumList] {
    func find(byId: UUID) -> NavidromeAlbumList? {
        return first { $0.id == byId }
    }
}
