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

// MARK: - NavidromeBrowseItem (for Artists, Genres, Playlists)

/// A browseable category item that can expand into albums or tracks.
class NavidromeBrowseItem: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String?
    var navidromeId: String
    var coverArtId: String?

    /// Expanded children — albums for artists/genres, tracks for playlists.
    var albums: [NavidromeAlbum] = []
    var tracks: [NavidromeTrack] = []
    var childrenLoaded: Bool = false

    enum ItemType { case artist, genre, playlist }
    let itemType: ItemType

    init(title: String, navidromeId: String, itemType: ItemType, subtitle: String? = nil, coverArtId: String? = nil) {
        self.title = title
        self.navidromeId = navidromeId
        self.itemType = itemType
        self.subtitle = subtitle
        self.coverArtId = coverArtId
    }

    /// Load children from the server.
    @MainActor func loadChildren() async throws {
        guard !childrenLoaded, let client = NaviolaSettings.shared.makeClient() else { return }
        let provider = NavidromeProvider(.albums) // just need the client methods

        switch itemType {
        case .artist:
            let artistAlbums = try await provider.fetchAlbumsForArtist(navidromeId)
            albums = artistAlbums.map { NavidromeAlbum(from: $0) }
        case .genre:
            let genreAlbums = try await provider.fetchAlbumsForGenre(title)
            albums = genreAlbums.map { NavidromeAlbum(from: $0) }
        case .playlist:
            let entries = try await provider.fetchPlaylistTracks(navidromeId)
            tracks = entries.map { NavidromeTrack(from: $0, client: client) }
        }
        childrenLoaded = true
    }
}

// MARK: - NavidromeAlbumList

class NavidromeAlbumList: ObservableObject {
    let id = UUID()
    let title: String
    let icon: String

    var items = [NavidromeAlbum]()
    var browseItems = [NavidromeBrowseItem]()

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
            switch provider.category {
            case .albums:
                let albums = try await provider.fetchAlbums()
                items = albums.map { NavidromeAlbum(from: $0) }
                browseItems = []

            case .search:
                guard let client = NaviolaSettings.shared.makeClient() else { break }
                let scope = provider.searchScope

                let artistCount = (scope == .all || scope == .artists) ? 20 : 0
                let albumCount = (scope == .all || scope == .albums) ? 30 : 0
                let songCount = (scope == .all || scope == .songs) ? 30 : 0

                let result = try await client.search3Full(
                    query: provider.searchText,
                    albumCount: albumCount,
                    artistCount: artistCount,
                    songCount: songCount
                )

                // Artists as browse items
                var searchBrowseItems = [NavidromeBrowseItem]()
                for artist in result.artist ?? [] {
                    searchBrowseItems.append(NavidromeBrowseItem(
                        title: artist.name,
                        navidromeId: artist.id,
                        itemType: .artist,
                        subtitle: artist.albumCount.map { "\($0) albums" },
                        coverArtId: artist.coverArt
                    ))
                }

                // Songs as a "Songs" browse item (or top-level tracks for songs-only scope)
                let songs = (result.song ?? []).map { NavidromeTrack(from: $0, client: client) }
                if !songs.isEmpty {
                    let songsItem = NavidromeBrowseItem(
                        title: NSLocalizedString("Songs", comment: "Search results section"),
                        navidromeId: "_search_songs",
                        itemType: .playlist,
                        subtitle: "\(songs.count) results"
                    )
                    songsItem.tracks = songs
                    songsItem.childrenLoaded = true
                    searchBrowseItems.append(songsItem)
                }

                // Playlists (client-side filter — search3 doesn't include playlists)
                if scope == .all || scope == .playlists {
                    let query = provider.searchText.lowercased()
                    let allPlaylists = try await client.getPlaylists()
                    let matched = allPlaylists.filter { $0.name.lowercased().contains(query) }
                    for playlist in matched {
                        let durationStr = playlist.duration.map { d in
                            let m = d / 60
                            return m > 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
                        }
                        searchBrowseItems.append(NavidromeBrowseItem(
                            title: playlist.name,
                            navidromeId: playlist.id,
                            itemType: .playlist,
                            subtitle: [
                                playlist.songCount.map { "\($0) songs" },
                                durationStr,
                            ].compactMap { $0 }.joined(separator: " · "),
                            coverArtId: playlist.coverArt
                        ))
                    }
                }

                browseItems = searchBrowseItems
                items = (result.album ?? []).map { NavidromeAlbum(from: $0) }

            case .pinned:
                let store = NaviolaPinnedItemStore.shared
                // Albums
                let albumPins = store.items.filter { $0.type == .album }
                items = albumPins.map { pin in
                    let parts = pin.title.components(separatedBy: " - ")
                    let artist = parts.count > 1 ? parts.first : nil
                    let albumName = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : pin.title
                    let album = NavidromeAlbum(title: albumName, navidromeId: pin.subsonicId)
                    album.artist = artist
                    album.coverArtId = pin.coverArtId
                    return album
                }
                // Non-album pins (artists, genres, playlists)
                browseItems = store.items.filter { $0.type != .album }.map { pin in
                    let itemType: NavidromeBrowseItem.ItemType
                    switch pin.type {
                    case .artist: itemType = .artist
                    case .genre: itemType = .genre
                    case .playlist: itemType = .playlist
                    default: itemType = .playlist // fallback
                    }
                    return NavidromeBrowseItem(
                        title: pin.title,
                        navidromeId: pin.subsonicId,
                        itemType: itemType,
                        subtitle: pin.subtitle,
                        coverArtId: pin.coverArtId
                    )
                }

            case .artists:
                let indices = try await provider.fetchArtists()
                browseItems = indices.flatMap { index in
                    index.artist.map { artist in
                        NavidromeBrowseItem(
                            title: artist.name,
                            navidromeId: artist.id,
                            itemType: .artist,
                            subtitle: artist.albumCount.map { "\($0) albums" },
                            coverArtId: artist.coverArt
                        )
                    }
                }
                items = []

            case .genres:
                let genres = try await provider.fetchGenres()
                browseItems = genres.map { genre in
                    NavidromeBrowseItem(
                        title: genre.value,
                        navidromeId: genre.value, // genres are referenced by name
                        itemType: .genre,
                        subtitle: [
                            genre.albumCount.map { "\($0) albums" },
                            genre.songCount.map { "\($0) songs" },
                        ].compactMap { $0 }.joined(separator: " · ")
                    )
                }
                items = []

            case .playlists:
                let playlists = try await provider.fetchPlaylists()
                browseItems = playlists.map { playlist in
                    let durationStr = playlist.duration.map { d in
                        let m = d / 60
                        return m > 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
                    }
                    return NavidromeBrowseItem(
                        title: playlist.name,
                        navidromeId: playlist.id,
                        itemType: .playlist,
                        subtitle: [
                            playlist.songCount.map { "\($0) songs" },
                            durationStr,
                        ].compactMap { $0 }.joined(separator: " · "),
                        coverArtId: playlist.coverArt
                    )
                }
                items = []
            }

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
