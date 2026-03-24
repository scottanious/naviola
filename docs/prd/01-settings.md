# Phase 1: Settings UI — Navidrome Configuration

## Goal
Allow users to configure their Navidrome server connection and test it.

## Upstream Merge Note
All settings live in new files (`NaviolaSettings.swift`, `NavidromePage.swift`). Only `PreferencesWindow.swift` gets a small additive edit (one tab appended).

## Tasks

### 1.1 — NaviolaSettings.swift
**Create** `Radiola/NaviolaSettings.swift`

Separate settings singleton for Naviola-specific configuration (avoids editing upstream `Settings.swift`):
- `NaviolaSettings.shared` singleton
- `navidromeServerURL: String?` (UserDefaults-backed, key: `"NavidromeServerURL"`)
- `navidromeUsername: String?` (UserDefaults-backed, key: `"NavidromeUsername"`)
- Password managed via `NavidromeAuth` Keychain (from Phase 0)
- `isNavidromeConfigured: Bool` computed property

**Validation**: Unit test read/write round-trip.

### 1.2 — NavidromePage.swift
**Create** `Radiola/Preferences/NavidromePage.swift`

Preferences tab with:
- Server URL text field (placeholder: `https://music.example.com`)
- Username text field
- Password secure field (reads/writes Keychain via NavidromeAuth)
- "Test Connection" button → calls `NavidromeClient.ping()`, shows success/failure inline

**Validation**: Manual — open preferences, fill in fields, click test, see result.

### 1.3 — Wire into PreferencesWindow
**Edit** `Radiola/Preferences/PreferencesWindow.swift`

Append one tab block for `NavidromePage` at the end of `init()` (before `viewController.tabStyle`). Purely additive — no existing lines modified.

**Validation**: Manual — Navidrome tab appears in preferences.

## Dependencies
Phase 0 (NavidromeAuth, NavidromeClient for test connection).

## Status
- [x] 1.1 NaviolaSettings
- [x] 1.2 NavidromePage
- [x] 1.3 Wire into PreferencesWindow
