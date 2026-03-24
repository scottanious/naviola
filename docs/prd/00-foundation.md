# Phase 0: Foundation — Navidrome API Layer

## Goal
Create the Subsonic API client layer that all subsequent phases depend on.

## Tasks

### 0.1 — NavidromeModels.swift
**Create** `Radiola/Navidrome/NavidromeModels.swift`

Codable structs for Subsonic JSON responses:
- `SubsonicResponse` — top-level wrapper with `status`, `version`, `error`
- `SubsonicError` — `code`, `message`
- `SubsonicAlbumID3` — `id`, `name`, `artist`, `artistId`, `coverArt`, `songCount`, `duration`, `year`, `genre`, `created`
- `SubsonicChild` (song/track) — `id`, `title`, `album`, `artist`, `track`, `year`, `genre`, `coverArt`, `size`, `duration`, `bitRate`, `contentType`, `suffix`
- `SubsonicAlbumWithSongsID3` — extends album with `song: [SubsonicChild]`
- `SubsonicAlbumList2` — `album: [SubsonicAlbumID3]`

**Validation**: Unit test `TestNavidromeModels.swift` decodes JSON fixtures from `RadiolaTests/data/testNavidrome/`.

### 0.2 — NavidromeAuth.swift
**Create** `Radiola/Navidrome/NavidromeAuth.swift`

- Keychain CRUD: store/retrieve/delete password for service `"com.naviola.navidrome"`
- `authQueryItems(username:password:) -> [URLQueryItem]` — generates `u`, `t` (md5 token), `s` (random salt), `v`, `c`, `f` params
- MD5 via `CryptoKit.Insecure.MD5`
- `isConfigured: Bool` computed property

**Validation**: Unit test `TestNavidromeAuth.swift` — given known username/password/salt, verify correct `t` token is produced.

### 0.3 — NavidromeClient.swift
**Create** `Radiola/Navidrome/NavidromeClient.swift`

- `struct NavidromeClient` with `baseURL: URL`
- `func fetch<T: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> T`
- `func ping() async throws -> Bool`
- `func getAlbumList2(type: String, size: Int, offset: Int) async throws -> [SubsonicAlbumID3]`
- `func getAlbum(id: String) async throws -> SubsonicAlbumWithSongsID3`
- `func streamURL(songId: String) -> URL` — constructs URL, does not fetch
- `func coverArtURL(id: String, size: Int) -> URL` — constructs URL, does not fetch

**Validation**: Unit test for URL construction. Manual test: `ping()` against real Navidrome.

## Dependencies
None — this is the first phase.

## Status
- [x] 0.1 NavidromeModels
- [x] 0.2 NavidromeAuth
- [x] 0.3 NavidromeClient
