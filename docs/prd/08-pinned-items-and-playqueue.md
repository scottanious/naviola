# Phase 8: Pinned Items & Play Queue — Generalized Music Library Pinning

## Goal
Replace the current OPML-based pin (which creates individual favorite stations) with a proper pinned items system and sequential play queue. This is the foundation for Naviola behaving like a music client rather than a radio app.

## Design

### NaviolaPinnedItem
A generalized pinned item that can represent any browseable content:

```swift
struct NaviolaPinnedItem: Codable, Identifiable {
    let id: UUID
    let type: PinnedItemType      // .album, .artist, .genre, .track, .playlist
    let title: String             // Display title ("Artist - Album")
    let subtitle: String?         // Secondary info ("12 tracks · 2024")
    let subsonicId: String        // Subsonic ID for re-fetching
    let coverArtId: String?       // For cover art display
    let dateAdded: Date

    enum PinnedItemType: String, Codable {
        case album
        case artist
        case genre
        case track
        case playlist
    }
}
```

Each pinned item knows how to **resolve** into an ordered track list via the Subsonic API at play time. No embedded URLs — tracks are fetched fresh.

### NaviolaPlayQueue
Sequential playback manager that sits alongside Player:
- Holds an ordered `[Station]` (resolved tracks)
- Listens for Player state changes — when track ends, advances to next
- Exposes current track index, total count
- Future: repeat-one, repeat-all, shuffle modes

### Persistence
JSON file at `~/Library/Application Support/com.naviola/pinned.json` — not OPML. Independent of upstream persistence.

### Menu Bar
Each pinned item = one menu item. Clicking starts the play queue for that item. Unpin removes it.

## Tasks

### 8.1 — NaviolaPinnedItem Model + Persistence
**Create** `Radiola/NaviolaPinnedItems.swift`
- `NaviolaPinnedItem` struct (Codable)
- `NaviolaPinnedItemStore` — load/save JSON, add/remove/list
- Pin and unpin operations

**Validation**: Unit test — add item, persist, reload, verify. Remove item, verify gone.

### 8.2 — NaviolaPlayQueue
**Create** `Radiola/NaviolaPlayQueue.swift`
- Holds current track list and index
- Resolves a `NaviolaPinnedItem` into tracks via Subsonic API
- Subscribes to Player state — auto-advances on track end
- `play(item:)`, `next()`, `previous()`, `stop()`

**Validation**: Unit test — queue with 3 tracks, simulate advancement. Manual — play pinned album, verify auto-advance.

### 8.3 — Rework Pin Button
**Edit** `NavidromeStationRows.swift`
- Pin button creates a `NaviolaPinnedItem` (not OpmlGroup)
- Unpin button removes it
- Visual state reflects pinned status via `NaviolaPinnedItemStore`

**Validation**: Pin album → appears in store. Unpin → removed.

### 8.4 — Menu Bar Integration
**Create** `Radiola/StatusBar/NaviolaMenuBuilder.swift`
- Builds menu section for pinned items
- Each item = one NSMenuItem with album/artist title
- Click → `NaviolaPlayQueue.play(item:)`
- Replaces the favorites section in menu (or adds alongside, depending on upstream merge strategy)

**Validation**: Pin album → appears in menu. Click → plays. Unpin → disappears.

### 8.5 — Sidebar "Pinned" Section
Update sidebar to show pinned items under "My Lists" or a new "Pinned" section. Selecting a pinned item shows its tracks in the content area.

**Validation**: Pin album → appears in sidebar. Select → shows tracks.

## Dependencies
Phases 0-5.

## Status
- [x] 8.1 NaviolaPinnedItem model + persistence
- [x] 8.2 NaviolaPlayQueue
- [x] 8.3 Rework pin button
- [x] 8.4 Menu bar integration
- [x] 8.5 Play queue from browse (double-click track → album queue; double-click album → full queue)
