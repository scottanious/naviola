//
//  NavidromeModels.swift
//  Radiola
//
//  Naviola — Codable structs for Subsonic/Navidrome JSON API responses.
//

import Foundation

// MARK: - Top-Level Response Wrapper

/// Every Subsonic JSON response is wrapped in `{ "subsonic-response": { ... } }`.
struct SubsonicResponseWrapper<T: Decodable>: Decodable {
    let response: SubsonicResponse<T>

    enum CodingKeys: String, CodingKey {
        case response = "subsonic-response"
    }
}

struct SubsonicResponse<T: Decodable>: Decodable {
    let status: String
    let version: String
    let type: String?
    let serverVersion: String?
    let error: SubsonicError?

    // The payload is decoded from the remaining keys.
    // Concrete wrappers below specify the payload key.

    var isOk: Bool { status == "ok" }
}

struct SubsonicError: Decodable {
    let code: Int
    let message: String
}

// MARK: - Ping

/// Ping has no payload beyond status/version.
struct SubsonicPingPayload: Decodable {}

typealias SubsonicPingResponse = SubsonicResponseWrapper<SubsonicPingPayload>

// MARK: - Album ID3

struct SubsonicAlbumID3: Decodable, Identifiable {
    let id: String
    let name: String
    let artist: String?
    let artistId: String?
    let coverArt: String?
    let songCount: Int?
    let duration: Int?
    let created: String?
    let year: Int?
    let genre: String?
}

// MARK: - Child (Song/Track)

struct SubsonicChild: Decodable, Identifiable {
    let id: String
    let title: String
    let album: String?
    let artist: String?
    let track: Int?
    let year: Int?
    let genre: String?
    let coverArt: String?
    let size: Int?
    let duration: Int?
    let bitRate: Int?
    let contentType: String?
    let suffix: String?
    let discNumber: Int?
    let albumId: String?
    let artistId: String?
}

// MARK: - Album with Songs

struct SubsonicAlbumWithSongsID3: Decodable {
    let id: String
    let name: String
    let artist: String?
    let artistId: String?
    let coverArt: String?
    let songCount: Int?
    let duration: Int?
    let year: Int?
    let genre: String?
    let song: [SubsonicChild]?
}

// MARK: - getAlbumList2 Response

struct SubsonicAlbumList2Response: Decodable {
    let response: SubsonicAlbumList2Inner

    enum CodingKeys: String, CodingKey {
        case response = "subsonic-response"
    }

    struct SubsonicAlbumList2Inner: Decodable {
        let status: String
        let version: String
        let error: SubsonicError?
        let albumList2: SubsonicAlbumList2Container?

        var isOk: Bool { status == "ok" }
    }

    struct SubsonicAlbumList2Container: Decodable {
        let album: [SubsonicAlbumID3]?
    }
}

// MARK: - getAlbum Response

struct SubsonicGetAlbumResponse: Decodable {
    let response: SubsonicGetAlbumInner

    enum CodingKeys: String, CodingKey {
        case response = "subsonic-response"
    }

    struct SubsonicGetAlbumInner: Decodable {
        let status: String
        let version: String
        let error: SubsonicError?
        let album: SubsonicAlbumWithSongsID3?

        var isOk: Bool { status == "ok" }
    }
}
