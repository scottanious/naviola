//
//  NavidromeClient.swift
//  Radiola
//
//  Naviola — Subsonic/Navidrome API client.
//

import Foundation

// MARK: - NavidromeClient

struct NavidromeClient {
    let baseURL: URL
    let username: String
    let password: String

    private let auth = NavidromeAuth.shared

    // MARK: - Generic Fetch

    func fetch<T: Decodable>(_ type: T.Type, path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents()
        components.scheme = baseURL.scheme ?? "http"
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = path
        components.queryItems = auth.authQueryItems(username: username, password: password) + queryItems

        guard let url = components.url else {
            throw NavidromeClientError.invalidURL(path)
        }

        debug("NavidromeClient fetch \(url.absoluteString)")

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: data)
        } catch {
            warning("NavidromeClient decode error: \(error)")
            throw error
        }
    }

    // MARK: - API Methods

    /// Verify connection and authentication.
    func ping() async throws -> Bool {
        let response = try await fetch(SubsonicPingResponse.self, path: "/rest/ping.view")
        if let error = response.response.error {
            throw NavidromeClientError.serverError(code: error.code, message: error.message)
        }
        return response.response.isOk
    }

    /// Get a list of albums matching the given type (newest, recent, random, etc.).
    func getAlbumList2(type: String, size: Int = 20, offset: Int = 0, genre: String? = nil) async throws -> [SubsonicAlbumID3] {
        var queryItems = [
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let genre = genre {
            queryItems.append(URLQueryItem(name: "genre", value: genre))
        }

        let response = try await fetch(SubsonicAlbumList2Response.self, path: "/rest/getAlbumList2.view", queryItems: queryItems)

        if let error = response.response.error {
            throw NavidromeClientError.serverError(code: error.code, message: error.message)
        }

        return response.response.albumList2?.album ?? []
    }

    /// Get all artists grouped by letter.
    func getArtists() async throws -> [SubsonicArtistIndex] {
        let response = try await fetch(SubsonicArtistsResponse.self, path: "/rest/getArtists")

        if let error = response.response.error {
            throw NavidromeClientError.serverError(code: error.code, message: error.message)
        }

        return response.response.artists?.index ?? []
    }

    /// Get an artist's albums.
    func getArtist(id: String) async throws -> SubsonicArtistWithAlbums {
        let queryItems = [URLQueryItem(name: "id", value: id)]
        let response = try await fetch(SubsonicArtistDetailResponse.self, path: "/rest/getArtist", queryItems: queryItems)

        if let error = response.response.error {
            throw NavidromeClientError.serverError(code: error.code, message: error.message)
        }

        guard let artist = response.response.artist else {
            throw NavidromeClientError.missingPayload("artist")
        }
        return artist
    }

    /// Get all genres.
    func getGenres() async throws -> [SubsonicGenre] {
        let response = try await fetch(SubsonicGenresResponse.self, path: "/rest/getGenres")

        if let error = response.response.error {
            throw NavidromeClientError.serverError(code: error.code, message: error.message)
        }

        return response.response.genres?.genre ?? []
    }

    /// Get all playlists.
    func getPlaylists() async throws -> [SubsonicPlaylist] {
        let response = try await fetch(SubsonicPlaylistsResponse.self, path: "/rest/getPlaylists")

        if let error = response.response.error {
            throw NavidromeClientError.serverError(code: error.code, message: error.message)
        }

        return response.response.playlists?.playlist ?? []
    }

    /// Get a playlist's tracks.
    func getPlaylist(id: String) async throws -> SubsonicPlaylistWithEntries {
        let queryItems = [URLQueryItem(name: "id", value: id)]
        let response = try await fetch(SubsonicPlaylistDetailResponse.self, path: "/rest/getPlaylist", queryItems: queryItems)

        if let error = response.response.error {
            throw NavidromeClientError.serverError(code: error.code, message: error.message)
        }

        guard let playlist = response.response.playlist else {
            throw NavidromeClientError.missingPayload("playlist")
        }
        return playlist
    }

    /// Get a single album with its tracks.
    func getAlbum(id: String) async throws -> SubsonicAlbumWithSongsID3 {
        let queryItems = [
            URLQueryItem(name: "id", value: id),
        ]

        let response = try await fetch(SubsonicGetAlbumResponse.self, path: "/rest/getAlbum.view", queryItems: queryItems)

        if let error = response.response.error {
            throw NavidromeClientError.serverError(code: error.code, message: error.message)
        }

        guard let album = response.response.album else {
            throw NavidromeClientError.missingPayload("album")
        }

        return album
    }

    /// Search for albums by query string (albums only).
    func search3(query: String, albumCount: Int = 20) async throws -> [SubsonicAlbumID3] {
        let result = try await search3Full(query: query, albumCount: albumCount, artistCount: 0, songCount: 0)
        return result.album ?? []
    }

    /// Full search returning artists, albums, and songs.
    func search3Full(query: String, albumCount: Int = 20, artistCount: Int = 10, songCount: Int = 20) async throws -> SubsonicSearchResult {
        let queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "albumCount", value: String(albumCount)),
            URLQueryItem(name: "artistCount", value: String(artistCount)),
            URLQueryItem(name: "songCount", value: String(songCount)),
        ]

        let response = try await fetch(SubsonicSearch3Response.self, path: "/rest/search3.view", queryItems: queryItems)

        if let error = response.response.error {
            throw NavidromeClientError.serverError(code: error.code, message: error.message)
        }

        if let result = response.response.searchResult3 {
            return result
        }
        // Return empty result — can't construct SubsonicSearchResult (no init) so return via decode
        let emptyData = "{\"artist\":[],\"album\":[],\"song\":[]}".data(using: .utf8)!
        return try JSONDecoder().decode(SubsonicSearchResult.self, from: emptyData)
    }

    // MARK: - URL Builders (no network call)

    /// Build a streaming URL for a song. This URL can be passed directly to Player.
    func streamURL(songId: String) -> URL {
        var components = URLComponents()
        components.scheme = baseURL.scheme ?? "http"
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = "/rest/stream.view"
        components.queryItems = auth.authQueryItems(username: username, password: password) + [
            URLQueryItem(name: "id", value: songId),
        ]
        return components.url!
    }

    /// Build a cover art URL.
    func coverArtURL(id: String, size: Int = 300) -> URL {
        var components = URLComponents()
        components.scheme = baseURL.scheme ?? "http"
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = "/rest/getCoverArt.view"
        components.queryItems = auth.authQueryItems(username: username, password: password) + [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "size", value: String(size)),
        ]
        return components.url!
    }
}

// MARK: - Error Type

enum NavidromeClientError: LocalizedError {
    case invalidURL(String)
    case serverError(code: Int, message: String)
    case missingPayload(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "Invalid URL for path: \(path)"
        case .serverError(_, let message):
            return message
        case .missingPayload(let key):
            return "Missing expected payload key: \(key)"
        }
    }
}
