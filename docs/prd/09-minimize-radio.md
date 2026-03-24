# Phase 9: Minimize Radio Infrastructure

## Goal
Remove or hide radio-specific features to establish Naviola as a focused Subsonic music client. Users who want internet radio should use Radiola.

## Design Considerations
- This phase is a **hard-fork trigger** for certain changes (hiding Radio browser sidebar)
- Some changes are safe for rebase (additive), others conflict
- Prioritize hiding over deleting — dead code is fine, confusing UI is not

## Tasks

### 9.1 — Hide Radio Browser Sidebar Section
Remove or conditionally hide the "Radio browser" group from the sidebar in `StationsWindow.swift`.

**Impact**: Modifies upstream code. Hard-fork trigger.

### 9.2 — Simplify Default Stations
Replace default radio stations in `AppState.swift` with empty list or Naviola-specific defaults.

**Impact**: Modifies upstream code. Hard-fork trigger.

### 9.3 — Evaluate OPML Usage
Determine if OPML persistence is still needed for Naviola or if `NaviolaPinnedItemStore` (Phase 8) replaces it entirely. If OPML is only used for radio stations, it can be removed from the UI.

### 9.4 — Update "My Lists" Semantics
Rename "My stations" / "My lists" to reflect music library semantics (e.g., "Library", "Pinned"). Update sidebar, menu bar text.

**Impact**: Modifies upstream strings. Hard-fork trigger.

### 9.5 — Branding
Rename "Radiola" → "Naviola" in all user-facing strings, bundle ID, app icon. (Moved from Phase 6.4.)

**Impact**: Hard-fork trigger.

## Dependencies
Phase 8 (to understand what replaces radio-era features).

## Status
- [ ] 9.1 Hide Radio Browser sidebar
- [ ] 9.2 Simplify default stations
- [ ] 9.3 Evaluate OPML usage
- [ ] 9.4 Update "My Lists" semantics
- [ ] 9.5 Branding
