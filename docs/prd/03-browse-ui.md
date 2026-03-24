# Phase 3: Browse UI — Navidrome Station Views

## Goal
Create the UI for browsing Navidrome albums in the main window, wired into the sidebar.

## Upstream Merge Note
New files in `StationsWindow/NavidromeStations/`. Only `StationsWindow.swift` gets additive edits: a new sidebar group appended, a new delegate property, and a new branch in `sidebarChanged()`. No existing lines modified or removed.

## Tasks

### 3.1 — NavidromeStationDelegate.swift
**Create** `Radiola/StationsWindow/NavidromeStations/NavidromeStationDelegate.swift`

NSOutlineView data source/delegate (parallel to `InternetStationDelegate`):
- Shows `NavidromeAlbum` items from the associated `NavidromeAlbumList`
- Expandable albums → child `NavidromeTrack` rows (fetched on expand via `getAlbum()`)
- Double-click a track → `player.station = track; player.play()`

**Validation**: Selecting "Recently Added" in sidebar shows album list.

### 3.2 — NavidromeStationRows.swift
**Create** `Radiola/StationsWindow/NavidromeStations/NavidromeStationRows.swift`

Custom `NSTableCellView` subclasses:
- Album row: title, artist, year, pin button
- Track row: track number, title, duration

**Validation**: Albums render correctly in the outline view.

### 3.3 — NavidromeSearchPanel.swift
**Create** `Radiola/StationsWindow/NavidromeStations/NavidromeSearchPanel.swift`

Minimal panel:
- "Refresh" button (for Recently Added lens — fetches latest)
- Search field (wired for future search lens, hidden for non-search lenses)

**Validation**: Panel appears above content area, refresh triggers fetch.

### 3.4 — Wire into StationsWindow (Additive Only)
**Edit** `Radiola/StationsWindow/StationsWindow.swift`

Additive changes only — no existing lines removed or modified:
- `initSideBar()`: **Append** "Naviola" group after "Radio browser" group, iterate `navidromeStations`
- Add `navidromeStationsDelegate` property alongside existing delegates
- `windowDidLoad()`: init `navidromeStationsDelegate`
- `sidebarChanged()`: Add `else if` branch for `navidromeStations.find(byId:)` → calls new `setNavidromeStationList()`
- Add `setNavidromeStationList()` method (parallel to `setInternetStationList()`)

The "Radio browser" section remains in the sidebar (upstream code untouched). It will show empty results since no RadioBrowser searches are triggered, but the code is not removed.

**Validation**: Full browse flow — sidebar shows "Naviola" section → "Recently Added" → album list appears → albums expandable.

## Dependencies
Phase 2.

## Status
- [x] 3.1 NavidromeStationDelegate
- [x] 3.2 NavidromeStationRows
- [x] 3.3 NavidromeSearchPanel
- [x] 3.4 Wire into StationsWindow
