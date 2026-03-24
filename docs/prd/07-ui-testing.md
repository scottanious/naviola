# Phase 7: UI Testing — XCUITest Framework

## Goal
Add automated UI testing to validate Naviola flows and strengthen validation for every change.

## Tasks

### 7.1 — Add XCUITest Target
Create `NaviolaUITests` target in the Xcode project (easiest via Xcode: File → New → Target → UI Testing Bundle).

**Validation**: `xcodebuild test -scheme Radiola` runs both unit and UI tests.

### 7.2 — Preferences Connection Test
Test the Navidrome preferences flow:
- Launch app
- Open preferences
- Navigate to Navidrome tab
- Verify fields exist (server URL, username, password, test button)
- Fill in fields, click test connection

**Validation**: Test passes in CI.

### 7.3 — Browse Flow Test
Test the Navidrome browsing flow:
- Configure credentials (via UserDefaults in test setup)
- Open main window
- Select "Recently Added" in sidebar
- Verify albums appear
- Expand an album, verify tracks appear

**Validation**: Test passes against test Navidrome instance.

### 7.4 — Pin Flow Test
Test pinning an album:
- Browse to an album
- Click pin button
- Switch to "My stations"
- Verify pinned group appears

**Validation**: Test passes.

## Dependencies
Phases 0-5 complete.

## Status
- [ ] 7.1 Add XCUITest target
- [ ] 7.2 Preferences connection test
- [ ] 7.3 Browse flow test
- [ ] 7.4 Pin flow test
