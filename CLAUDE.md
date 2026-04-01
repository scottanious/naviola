# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Naviola** is a fork of [Radiola](https://github.com/SokoloffA/radiola) (lightweight macOS menu bar Internet radio player) that replaces internet radio browsing with **Navidrome** music library integration. Written in Swift/Cocoa.

Upstream repo: `SokoloffA/radiola` (branch: `main`)

## Build & Test Commands

```bash
# Run unit tests (no code signing needed)
xcodebuild test -scheme Naviola CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Build release (requires code signing credentials)
./build.sh

# Build sandboxed variant (App Store)
./build-sandboxed.sh
```

## Development Methodology

This project uses **ralph loops** — iterative, PRD-driven agentic development:
- PRD docs in `docs/prd/` are decomposed into discrete tasks
- Each agent run is small and focused with a validation step
- After each task (pass or fail), status is written for the next iteration
- Every change must pass `xcodebuild test` before being considered complete

## Architecture

### Core Playback Pipeline
`AppDelegate` → `Player` (singleton coordinator) → `FFPlayer` (FFmpeg-based audio engine). Player accepts any `Station` protocol conformer — works for both radio streams and Navidrome `stream.view` URLs.

### Station Model (Protocol-Oriented)
- `StationItem` protocol: `id`, `title` — base for all items
- `Station` protocol: extends with `url`, `isFavorite` — maps to both radio stations and Navidrome tracks
- `StationGroup` protocol: extends with `items` — maps to both station folders and Navidrome albums
- `StationList` protocol: persistence, CRUD, hierarchical search

All in `Radiola/Stations/`. OPML format for local persistence (`OpmlStations.swift`).

### Navidrome Integration (New)
Parallel to the upstream `RadioBrowser/` module:
- `Radiola/Navidrome/` — Subsonic API client (auth, models, client)
- `Radiola/Stations/NavidromeProvider.swift` — Lens-based browsing (recently added, search, etc.)
- `Radiola/Stations/NavidromeStations.swift` — `NavidromeTrack` (Station), `NavidromeAlbum`, `NavidromeAlbumList`
- `Radiola/StationsWindow/NavidromeStations/` — Browse UI (delegate, rows, search panel)
- `Radiola/Preferences/NavidromePage.swift` — Server configuration

### UI Layers
- `StatusBar/` — Menu bar icon, play/pause, volume, favorites dropdown (AppKit)
- `StationsWindow/` — Split view: Sidebar (My lists / Navidrome / History) | Content (NSOutlineView with swappable delegates)
- `Preferences/` — Settings tabs including Navidrome server configuration

### Key Wiring Points
- `AppState.swift` — Singleton holding `localStations`, `internetStations` (upstream), `navidromeStations` (Naviola), `history`
- `NaviolaSettings.swift` — Naviola-specific settings (Navidrome server URL, username); separate from upstream `Settings.swift`
- `StationsWindow.swift` — `sidebarChanged()` swaps delegates: `LocalStationDelegate`, `InternetStationDelegate` (upstream), `NavidromeStationDelegate` (Naviola), `HistoryDelegate`
- `StatuBarController.swift` — Builds menu from `favoritesStations()` (walks localStations recursively)

### Data Persistence
- Core Data: `Radiola.xcdatamodeld`, `HistoryData.xcdatamodeld`
- OPML: local station lists (pinned Navidrome albums become OPML groups)
- UserDefaults: preferences + Navidrome server URL/username
- Keychain: Navidrome password

## Upstream Merge Strategy

This fork is designed to rebase on upstream `SokoloffA/radiola` `main`. Rules:

1. **No upstream files are modified or removed** except for minimal, purely additive edits
2. All Naviola code lives in **new files** named with "Naviola" or "Navidrome" prefix
3. `RadioBrowser/`, `InternetStations/`, `RadioBrowserProvider.swift` — **never touched**
4. `Settings.swift` — **never touched**; Naviola settings live in `NaviolaSettings.swift`
5. `AppState.swift` — additive only: new `navidromeStations` property added alongside existing `internetStations`
6. `StationsWindow.swift` — additive only: new "Naviola" sidebar group appended, new delegate branch added
7. `PreferencesWindow.swift` — additive only: one tab appended
8. `StatuBarController.swift` — **never touched** until hard-fork decision (shows "Radiola" in menu)
9. Branding rename ("Radiola" → "Naviola") is deferred as a hard-fork trigger in Phase 6.4

## Localization

Translations managed via Transifex (`.tx/` directory). String catalog at `Radiola/Localizable.xcstrings`.

## Testing

XCTest in `RadiolaTests/`. Test data fixtures in `RadiolaTests/data/` with subdirectories per test suite. Base class `RadiolaTests` provides utilities: `dataDir`, `walkDataDir`, `findFile`, `glob`.

## Git Identity

All commits must use the following identity:
- **Name:** `Scottanious`
- **Email:** `73787+scottanious@users.noreply.github.com`

## KeyboardShortcuts

Bundled library (not a package dependency) in `KeyboardShortcuts/` for global hotkey registration via Carbon APIs.
