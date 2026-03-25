//
//  NavidromeProvider.swift
//  Radiola
//
//  Naviola — Provider for browsing Navidrome content.
//  Supports albums (with sort modes), artists, genres, playlists, search, and pinned items.
//

import Foundation

// MARK: - NavidromeProvider

class NavidromeProvider: ObservableObject {
    let category: Category
    @Published var searchText: String = ""
    @Published var albumSortMode: AlbumSortMode = .recentlyAdded

    enum Category {
        case albums
        case artists
        case genres
        case playlists
        case search
        case pinned
    }

    enum AlbumSortMode: Int, CaseIterable {
        case recentlyAdded = 0
        case byName
        case byArtist
        case mostPlayed
        case recentlyPlayed
        case random

        var title: String {
            switch self {
            case .recentlyAdded: return NSLocalizedString("Recently Added", comment: "Album sort mode")
            case .byName: return NSLocalizedString("By Name", comment: "Album sort mode")
            case .byArtist: return NSLocalizedString("By Artist", comment: "Album sort mode")
            case .mostPlayed: return NSLocalizedString("Most Played", comment: "Album sort mode")
            case .recentlyPlayed: return NSLocalizedString("Recently Played", comment: "Album sort mode")
            case .random: return NSLocalizedString("Random", comment: "Album sort mode")
            }
        }

        var apiType: String {
            switch self {
            case .recentlyAdded: return "newest"
            case .byName: return "alphabeticalByName"
            case .byArtist: return "alphabeticalByArtist"
            case .mostPlayed: return "frequent"
            case .recentlyPlayed: return "recent"
            case .random: return "random"
            }
        }
    }

    enum SearchScope: Int, CaseIterable {
        case all = 0
        case albums
        case artists
        case songs
        case playlists

        var title: String {
            switch self {
            case .all: return NSLocalizedString("All", comment: "Search scope")
            case .albums: return NSLocalizedString("Albums", comment: "Search scope")
            case .artists: return NSLocalizedString("Artists", comment: "Search scope")
            case .songs: return NSLocalizedString("Songs", comment: "Search scope")
            case .playlists: return NSLocalizedString("Playlists", comment: "Search scope")
            }
        }
    }

    @Published var searchScope: SearchScope = .all

    // Keep old LensType for backward compat during transition
    var lensType: Category { category }

    init(_ category: Category) {
        self.category = category
    }

    func canFetch() -> Bool {
        switch category {
        case .albums, .artists, .genres, .playlists:
            return NaviolaSettings.shared.isConfigured
        case .search:
            return NaviolaSettings.shared.isConfigured && !searchText.isEmpty
        case .pinned:
            return !NaviolaPinnedItemStore.shared.items.isEmpty
        }
    }

    /// Fetch albums (for .albums, .search, .pinned categories).
    func fetchAlbums() async throws -> [SubsonicAlbumID3] {
        guard let client = NaviolaSettings.shared.makeClient() else { return [] }

        switch category {
        case .albums:
            return try await client.getAlbumList2(type: albumSortMode.apiType, size: 100)
        case .search:
            guard !searchText.isEmpty else { return [] }
            return try await client.search3(query: searchText, albumCount: 50)
        case .pinned:
            return fetchPinnedAlbums()
        default:
            return []
        }
    }

    /// Fetch artists (for .artists category).
    func fetchArtists() async throws -> [SubsonicArtistIndex] {
        guard let client = NaviolaSettings.shared.makeClient() else { return [] }
        return try await client.getArtists()
    }

    /// Fetch genres (for .genres category).
    func fetchGenres() async throws -> [SubsonicGenre] {
        guard let client = NaviolaSettings.shared.makeClient() else { return [] }
        let genres = try await client.getGenres()
        return genres.sorted { ($0.albumCount ?? 0) > ($1.albumCount ?? 0) }
    }

    /// Fetch playlists (for .playlists category).
    func fetchPlaylists() async throws -> [SubsonicPlaylist] {
        guard let client = NaviolaSettings.shared.makeClient() else { return [] }
        return try await client.getPlaylists()
    }

    /// Fetch albums for a genre.
    func fetchAlbumsForGenre(_ genre: String) async throws -> [SubsonicAlbumID3] {
        guard let client = NaviolaSettings.shared.makeClient() else { return [] }
        return try await client.getAlbumList2(type: "byGenre", size: 100, genre: genre)
    }

    /// Fetch albums for an artist.
    func fetchAlbumsForArtist(_ artistId: String) async throws -> [SubsonicAlbumID3] {
        guard let client = NaviolaSettings.shared.makeClient() else { return [] }
        let artist = try await client.getArtist(id: artistId)
        return artist.album ?? []
    }

    /// Fetch tracks for a playlist.
    func fetchPlaylistTracks(_ playlistId: String) async throws -> [SubsonicChild] {
        guard let client = NaviolaSettings.shared.makeClient() else { return [] }
        let playlist = try await client.getPlaylist(id: playlistId)
        return playlist.entry ?? []
    }

    // Keep for backward compat
    func fetch() async throws -> [SubsonicAlbumID3] {
        return try await fetchAlbums()
    }

    private func fetchPinnedAlbums() -> [SubsonicAlbumID3] {
        return NaviolaPinnedItemStore.shared.items
            .filter { $0.type == .album }
            .map { item in
                let parts = item.title.components(separatedBy: " - ")
                let artist = parts.count > 1 ? parts.first : nil
                let albumName = parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : item.title

                return SubsonicAlbumID3(
                    id: item.subsonicId,
                    name: albumName,
                    artist: artist,
                    artistId: nil,
                    coverArt: item.coverArtId,
                    songCount: nil,
                    duration: nil,
                    created: nil,
                    year: nil,
                    genre: nil
                )
            }
    }
}
