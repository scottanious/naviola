# Phase 5: Pin to Local — Save Albums for Offline Menu Access

## Goal
Allow users to pin Navidrome albums to "My Lists", making them available in the menu bar dropdown.

## Tasks

### 5.1 — Pin Button Action
In `NavidromeStationRows.swift`, the pin button on album rows:
1. Fetch tracks if not loaded (`NavidromeClient.getAlbum(id:)`)
2. Get first local station list: `AppState.shared.localStations.first`
3. Create `OpmlGroup` with title `"artist - albumTitle"`
4. For each track, create `OpmlStation`:
   - `title`: `"trackNumber. trackTitle"`
   - `url`: `NavidromeClient.streamURL(songId:).absoluteString`
   - `isFavorite`: `true`
5. Append group to list, call `list.trySave()`

**Known limitation**: Stream URLs embed auth params. If password changes, pinned albums break. Acceptable for v1.

**Validation**: Pin an album → switch to "My lists" → see album group with tracks.

### 5.2 — Menu Bar Integration
No code changes needed. Existing `favoritesStations()` walks `localStations` recursively. `buildSubmenuFavoritesMenu` creates submenus for groups. Pinned albums with `isFavorite = true` tracks appear automatically.

**Validation**: Pin an album → click menu bar icon → see album as submenu with tracks.

## Dependencies
Phase 4 (playback must work so pinned tracks are useful).

## Status
- [x] 5.1 Pin button action (implemented in Phase 3 — NavidromeStationRows.swift pinAlbumToLocal())
- [x] 5.2 Menu bar integration verification (no code changes — existing favoritesStations() + buildSubmenuFavoritesMenu handles pinned groups automatically)
