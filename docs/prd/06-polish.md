# Phase 6: Polish — Cover Art, Search, Error States, Branding

## Goal
Refine visuals, expand browsing capabilities, and establish Naviola identity where safe.

## Tasks

### 6.1 — Cover Art
In `NavidromeStationRows.swift`, album rows:
- Async load cover art from `NavidromeClient.coverArtURL(id:size:)`
- Cache in memory (NSCache) to avoid re-fetching on scroll
- Show placeholder while loading

**Validation**: Album rows display cover art thumbnails.

### 6.2 — Search Lens
Add `.search` LensType to NavidromeProvider:
- Calls `search3.view?query=X`
- Add second `NavidromeAlbumList` in AppState for search
- Search panel shows text field for search lens

**Validation**: Type a query in the search lens → see matching albums.

### 6.3 — Error States
When Navidrome is not configured:
- "Naviola" sidebar section shows "Not configured" state indicator
- State indicator text links/points to preferences
- When configured but server unreachable: show connection error

**Validation**: Remove credentials → sidebar shows helpful message. Restore → works.

### 6.4 — Branding (Hard-Fork Trigger)
**NOTE**: This task converts the fork from rebaseable to hard-fork. Only do this when the decision is made to stop tracking upstream.

Changes that would conflict on rebase:
- `StatuBarController.swift`: "Open Radiola…" → "Open Naviola…"
- `Info.plist`: `CFBundleName`, `CFBundleDisplayName`
- Bundle identifier change
- App icon replacement

Until this task is done, the app shows "Radiola" in some upstream UI surfaces. That's intentional — it preserves the rebase path.

**Validation**: App shows "Naviola" in all UI surfaces.

## Dependencies
Phases 0-5 complete.

## Status
- [ ] 6.1 Cover art
- [ ] 6.2 Search lens
- [ ] 6.3 Error states
- [ ] 6.4 Branding (hard-fork trigger — deferred)
