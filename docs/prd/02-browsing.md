# Phase 2: Browsing Layer — Navidrome Provider & Station Types

## Goal
Create the data layer that fetches and represents Navidrome content, wired into AppState.

## Upstream Merge Note
New files: `NavidromeProvider.swift`, `NavidromeStations.swift`. Only `AppState.swift` gets a purely additive edit (new property + lookup method added, nothing removed or changed).

## Tasks

### 2.1 — NavidromeProvider.swift
**Create** `Radiola/Stations/NavidromeProvider.swift`

Lens-based provider (parallel to `RadioBrowserProvider`):
```swift
class NavidromeProvider: ObservableObject {
    enum LensType { case recentlyAdded, search /* future: .artists, .genres, .random */ }
    let lensType: LensType
    @Published var searchText: String = ""
    func fetch() async throws -> [SubsonicAlbumID3]
}
```

`.recentlyAdded` calls `getAlbumList2(type: "newest")`.

**Validation**: Unit test or manual — fetch returns albums from configured server.

### 2.2 — NavidromeStations.swift
**Create** `Radiola/Stations/NavidromeStations.swift`

- `NavidromeTrack: Station` — id, title, url (stream.view URL), isFavorite, plus artist, albumTitle, duration, trackNumber, navidromeId
- `NavidromeAlbum` — id, title, artist, navidromeId, coverArtId, year, tracks
- `NavidromeAlbumList: ObservableObject` — id, title, icon, items, state (notLoaded/loading/error/loaded), provider

**Validation**: App compiles. NavidromeAlbumList.fetch() populates items.

### 2.3 — Wire into AppState (Additive Only)
**Edit** `Radiola/AppState.swift`

Add (do NOT replace `internetStations`):
```swift
@Published var navidromeStations: [NavidromeAlbumList] = [
    NavidromeAlbumList(title: "Recently Added", icon: "music.note.list",
                       provider: NavidromeProvider(.recentlyAdded)),
]
```

Add `navidromeAlbum(byID:)` lookup method. Existing `internetStations` property stays untouched.

**Validation**: App compiles, builds, existing tests pass (`xcodebuild test`).

## Dependencies
Phase 0.

## Status
- [x] 2.1 NavidromeProvider
- [x] 2.2 NavidromeStations
- [x] 2.3 Wire into AppState
