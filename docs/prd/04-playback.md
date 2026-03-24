# Phase 4: Playback — Stream Navidrome Tracks

## Goal
Verify that Navidrome tracks play through the existing Player/FFPlayer pipeline and integrate with history.

## Tasks

### 4.1 — Album Expansion & Playback
When user clicks/expands an album in the browse view:
- Fetch tracks via `NavidromeClient.getAlbum(id:)` if not already loaded
- Display tracks as child rows with stream URLs
- Double-click track → `player.station = track; player.play()`
- Stream URL: `{serverURL}/rest/stream.view?id={songId}&{authParams}`

Player already handles arbitrary URLs via FFPlayer — no Player changes needed.

**Validation**: Double-click a Navidrome track → audio plays through FFPlayer.

### 4.2 — History Integration
The existing `Player` already calls history recording for any `Station`. Since `NavidromeTrack` conforms to `Station`, history should work automatically.

**Validation**: Play a Navidrome track → switch to History sidebar → track appears.

## Dependencies
Phase 3 (browse UI must be functional).

## Status
- [x] 4.1 Album expansion & playback (no code changes — NavidromeTrack conforms to Station, Player handles any URL)
- [x] 4.2 History integration (no code changes — Player.addHistory() works for any Station)
