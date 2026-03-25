# Phase 11: Full Navidrome Browser Navigation

## Goal
Expand the Naviola sidebar section from a flat list (Recently Added, Search) into a full Navidrome browser with navigation matching Navidrome's own structure: Albums, Artists, Genres, Playlists, and Search.

## Design

### Navigation Structure

The "Naviola" sidebar section becomes a set of top-level navigation categories:

```
Naviola
  Albums
  Artists
  Genres
  Playlists
  Search
```

Selecting a category shows its content in the main content area. Each category has sub-navigation via a segmented control or tab bar in the search panel area.

### Albums View
Default landing. A segmented control at the top switches between sort/filter modes:
- **Recently Added** (default) — `getAlbumList2?type=newest`
- **By Name** — `getAlbumList2?type=alphabeticalByName`
- **By Artist** — `getAlbumList2?type=alphabeticalByArtist`
- **Most Played** — `getAlbumList2?type=frequent`
- **Recently Played** — `getAlbumList2?type=recent`
- **Random** — `getAlbumList2?type=random`

All modes return `[SubsonicAlbumID3]` — the same album row UI works for all. Pagination via offset/size for large libraries.

### Artists View
Alphabetical artist list from `getArtists`. Selecting an artist fetches `getArtist?id=X` to show their albums. Each album is expandable to tracks (same as album view).

API responses:
- `getArtists` → `{ artists: { index: [{ name: "A", artist: [{id, name, albumCount}] }] } }`
- `getArtist?id=X` → `{ artist: { name, album: [SubsonicAlbumID3] } }`

### Genres View
Genre list from `getGenres`, sorted by album count. Selecting a genre fetches albums: `getAlbumList2?type=byGenre&genre=X`.

API response:
- `getGenres` → `{ genres: { genre: [{value, songCount, albumCount}] } }`

### Playlists View
Playlist list from `getPlaylists`. Selecting a playlist fetches tracks: `getPlaylist?id=X`.

API responses:
- `getPlaylists` → `{ playlists: { playlist: [{id, name, songCount, duration}] } }`
- `getPlaylist?id=X` → `{ playlist: { entry: [SubsonicChild] } }`

### Search View
Already implemented (Phase 6). Uses `search3?query=X`.

## API Endpoints Needed (New)

| Endpoint | Returns | Status |
|----------|---------|--------|
| `getAlbumList2?type=X` | Albums by sort mode | Already implemented (newest only) |
| `getArtists` | All artists grouped by letter | New |
| `getArtist?id=X` | Artist with albums | New |
| `getGenres` | All genres with counts | New |
| `getPlaylists` | All playlists | New |
| `getPlaylist?id=X` | Playlist with tracks | New |

Note: Navidrome requires endpoints WITHOUT `.view` suffix (e.g., `/rest/getArtists` not `/rest/getArtists.view`).

## Tasks

### 11.1 — API Layer: New Endpoints
**Edit** `NavidromeModels.swift` — add Codable structs:
- `SubsonicArtistsResponse` (artists → index → artist)
- `SubsonicArtistDetailResponse` (artist with albums)
- `SubsonicGenresResponse` (genres → genre with value/counts)
- `SubsonicPlaylistsResponse` (playlists → playlist)
- `SubsonicPlaylistDetailResponse` (playlist with entries)

**Edit** `NavidromeClient.swift` — add methods:
- `getArtists()`, `getArtist(id:)`
- `getGenres()`
- `getPlaylists()`, `getPlaylist(id:)`
- Extend `getAlbumList2` to accept all sort types

**Validation**: Unit tests decoding JSON fixtures for each new response type.

### 11.2 — Sidebar Navigation
Replace the flat "Naviola" sidebar items with category items:
- Albums, Artists, Genres, Playlists, Search
- Each with an appropriate SF Symbol icon

**Edit** `AppState.swift` — restructure `navidromeStations` or add new list types.
**Edit** `StationsWindow.swift` — sidebar construction and delegate switching.

**Validation**: Sidebar shows all 5 categories. Selecting each shows the correct content area.

### 11.3 — Albums Sub-Navigation
Add a segmented control (NSSegmentedControl) to the search panel area when Albums is selected. Segments: Recently Added, By Name, By Artist, Most Played, Recently Played, Random.

Switching segments re-fetches with the corresponding `type` parameter. Reuses existing album row UI.

**Validation**: Switch between album sort modes, verify correct results.

### 11.4 — Artists Browser
New outline view content: top-level shows artists (name, album count). Expanding an artist fetches albums via `getArtist`. Expanding an album fetches tracks. Double-click/right-click to play.

May need a new delegate or extend `NavidromeStationDelegate` to handle the artist→album→track hierarchy.

**Validation**: Browse artists → expand → see albums → expand → see tracks → play.

### 11.5 — Genres Browser
Genre list as top-level items (name, album count, song count). Selecting/expanding a genre fetches albums via `getAlbumList2?type=byGenre&genre=X`.

**Validation**: Browse genres → select → see albums for that genre.

### 11.6 — Playlists Browser
Playlist list as top-level items (name, song count, duration). Expanding a playlist fetches tracks via `getPlaylist?id=X`. Double-click plays the playlist.

**Validation**: Browse playlists → expand → see tracks → double-click to play.

### 11.7 — Pagination
Large libraries may have thousands of albums/artists. Add pagination support:
- "Load More" row at the bottom of album lists
- Or infinite scroll (fetch next page when scrolling near bottom)
- `offset` and `size` parameters already supported by `getAlbumList2`

**Validation**: Library with 750+ albums loads in pages, scrolling fetches more.

## Navidrome Server Data (for reference)
From the test server:
- 26 artist index groups, multiple artists per group
- 90 genres (top: Christian 750 albums, Jazz 376, Video Games 146)
- 11 playlists
- Album sort modes: newest, alphabeticalByName, alphabeticalByArtist, frequent, recent, random, byGenre, byYear

## Dependencies
Phases 0-10 complete. Builds on existing NavidromeClient, NavidromeStationDelegate, album row UI.

## Status
- [ ] 11.1 API layer: new endpoints + models
- [ ] 11.2 Sidebar navigation
- [ ] 11.3 Albums sub-navigation
- [ ] 11.4 Artists browser
- [ ] 11.5 Genres browser
- [ ] 11.6 Playlists browser
- [ ] 11.7 Pagination
