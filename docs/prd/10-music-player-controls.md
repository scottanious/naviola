# Phase 10: Music Player Controls & Metadata

## Goal
Transform the playback experience from radio-style (single stream, ICY metadata) to music-player-style (structured metadata, skip/back, repeat/shuffle). This acknowledges Naviola is a music client, not a radio app.

## Context
Current state:
- "Now playing" metadata comes from FFPlayer's ICY stream tags — works for radio, blank for Navidrome files
- No skip/back controls (radio streams don't have "next track")
- No repeat/shuffle (radio streams are continuous)
- NavidromeTrack already has structured metadata (artist, album, trackNumber, duration) but it's not surfaced to the UI
- PlayMenuItem shows song title + station name — needs to show artist/track/album for Navidrome

## Tasks

### 10.1 — Surface NavidromeTrack Metadata to Player
When `player.station` is a `NavidromeTrack`, surface its structured metadata instead of waiting for ICY stream tags.

**Create** `Radiola/NaviolaPlayerMetadata.swift`:
- When `PlayerStatusChanged` fires with `.playing` and station is `NavidromeTrack`, post `PlayerMetadataChanged` with structured info
- Set `player.songTitle` to `"Artist - Track Title"` from the NavidromeTrack fields
- This makes the existing menu bar text, tooltip, and history work immediately

**Files**: New `NaviolaPlayerMetadata.swift`. No upstream modifications needed — observes existing notifications and posts them back with correct data.

**Validation**: Play a Navidrome track → song title appears in menu bar, tooltip, and history.

### 10.2 — Rich Metadata in Menu Bar Dropdown
Update `PlayMenuItem` to show structured artist/album/track info for Navidrome content.

**Edit** `Radiola/StatusBar/PlayMenuItem.swift` (additive):
- When playing a `NavidromeTrack`, show:
  - Track title (semibold, primary)
  - Artist — Album (secondary line)
- Falls back to existing behavior for radio stations

**Validation**: Play a Navidrome track → dropdown shows track title + "Artist — Album" on second line.

### 10.3 — Skip/Back Controls
Add next/previous track controls that work with NaviolaPlayQueue.

**Edit** `Radiola/StatusBar/PlayMenuItem.swift` (additive):
- Add skip-forward and skip-back buttons alongside play/pause
- Skip calls `NaviolaPlayQueue.shared.next()`
- Back calls `NaviolaPlayQueue.shared.previous()` (new method)
- Buttons enabled only when play queue is active
- Disabled/hidden for radio stations

**Edit** `Radiola/NaviolaPlayQueue.swift`:
- Add `previous()` method — go back one track (or restart current if > 3 seconds in)

**Edit** `Radiola/StatusBar/StatuBarController.swift` (additive):
- Add skip/back menu items in the dropdown menu when queue is active

**Also wire to media keys** (if media key handling supports it):
- Check `Radiola/MediaKeysController.swift` for prev/next key handling
- `mediaPrevNextKeyAction` setting already exists with `.switchStation` option — reuse for queue navigation

**Validation**: Play queue active → skip/back buttons visible → skip advances, back goes to previous track.

### 10.4 — Player Controls on Main Window
Add playback controls (play/pause, skip/back, now-playing info) to the main StationsWindow toolbar area.

**Edit** `Radiola/StationsWindow/Toolbar/ToolbarPlayView.swift` (additive):
- Add skip-forward and skip-back buttons alongside existing play/pause
- Show track info: "Track Title" + "Artist — Album"
- Buttons enabled only when play queue is active

**Validation**: Main window toolbar shows skip/back buttons and rich track info during Navidrome playback.

### 10.5 — Repeat/Shuffle Toggle
Add repeat and shuffle modes to NaviolaPlayQueue with UI toggles.

**Edit** `Radiola/NaviolaPlayQueue.swift`:
- Add `repeatMode: RepeatMode` (`.off`, `.all`, `.one`)
- Add `shuffleEnabled: Bool`
- `next()` respects shuffle (random next) and repeat (loop back to start)
- `RepeatMode` and `shuffleEnabled` persisted in UserDefaults via NaviolaSettings

**Create** `Radiola/StatusBar/NaviolaPlaybackMenu.swift`:
- Repeat toggle menu item (cycles: off → all → one → off)
- Shuffle toggle menu item
- Added to status bar menu when queue is active

**Edit** `Radiola/StationsWindow/NavidromeStations/NavidromeSearchPanel.swift` (additive):
- Add repeat/shuffle toggle buttons to the search panel (visible during playback)

**Validation**: Toggle repeat → album loops. Toggle shuffle → tracks play in random order.

### 10.6 — Song Title in Menu Bar
The existing "Show song in status bar" setting (`settings.showSongInStatusBar`) should work for Navidrome tracks once 10.1 is done. Verify it works and ensure the text format is good for music (not radio-style).

**Validation**: Enable "Show song in status bar" in preferences → current track title shows next to the menu bar icon.

## Dependencies
Phase 8 (play queue must exist for skip/back/repeat/shuffle).

## Status
- [x] 10.1 Surface NavidromeTrack metadata to Player
- [x] 10.2 Rich metadata in menu bar dropdown
- [x] 10.3 Skip/back controls (menu, toolbar, media keys)
- [x] 10.4 Player controls on main window (skip/back buttons + rich metadata)
- [x] 10.5 Repeat/shuffle toggle (persisted in UserDefaults)
- [x] 10.6 Song title in menu bar (works via NaviolaPlayerMetadata)
