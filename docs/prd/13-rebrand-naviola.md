# Phase 13: Rebrand as Naviola — Hard Fork Identity

## Goal
Establish Naviola as an independent app that can coexist with Radiola on the same machine. Respectful hard fork: keep Radio features working, credit the upstream project, but give Naviola its own identity, data paths, and update mechanism.

## Guiding Principles
- A user should be able to run BOTH Radiola and Naviola simultaneously
- No shared data directories, preferences, or Keychain entries
- Radio features stay but are branded as part of Naviola ("Radio" section)
- Credit SokoloffA/Radiola as the upstream foundation
- Remove Radiola's update mechanism (Sparkle feed points to upstream)

## Audit Summary

| Category | Count | Impact |
|----------|-------|--------|
| Bundle identifiers | 4 locations | **Critical** — app identity, data isolation |
| Data directories | 3 hardcoded paths | **Critical** — prevents data conflicts |
| User-visible "Radiola" strings | 50+ across localized files | **High** — user sees wrong name |
| XIB module references | 11 XIB files | **High** — build breaks if module renamed |
| Build scripts / schemes | 5 files, 2 schemes | **Medium** — developer workflow |
| Update feed (Sparkle) | 1 URL in Info.plist | **High** — would update to Radiola |
| Code comments | 60+ files | **Low** — cosmetic |
| Documentation | README, CLAUDE.md, PRDs | **Medium** — developer confusion |

## Tasks

### 13.1 — Bundle Identity
Change the app's identity so macOS treats it as a separate app from Radiola.

**Files:**
- `Radiola.xcodeproj/project.pbxproj`: `PRODUCT_BUNDLE_IDENTIFIER` → `com.naviola.app` (all build configurations)
- `Radiola.xcodeproj/project.pbxproj`: Test target → `com.naviola.tests`
- `Radiola/Radiola.entitlements`: iCloud container → `iCloud.com.naviola.app` (or remove iCloud entirely — Naviola doesn't use it)
- `Radiola/RadiolaDebug.entitlements`: Align with production
- `Radiola/Info.plist`: Verify no hardcoded bundle ID

**Validation:** Both apps appear separately in Finder, Dock, Activity Monitor.

### 13.2 — Data Directory Isolation
Ensure Naviola uses its own Application Support, preferences, and Keychain.

**Files to change:**
- `Radiola/AppState.swift` line 29: `"com.github.SokoloffA.Radiola/"` → `"com.naviola.app/"`
- `Radiola/AppDelegate.swift` line 20: `"com.github.SokoloffA.Radiola/"` → `"com.naviola.app/"`
- `Radiola/Stations/OpmlStations.swift` line 157: `"com.github.SokoloffA.Radiola"` → `"com.naviola.app"`
- `Radiola/NaviolaSettings.swift`: Already uses `UserDefaults.standard` (auto-scoped to bundle ID)
- `Radiola/NaviolaPinnedItems.swift`: Already uses `com.naviola/` path — good

**Data migration note:** First launch of rebranded Naviola could optionally offer to import radio stations from Radiola's OPML file. Not required for MVP.

**Validation:** Naviola creates its own `~/Library/Application Support/com.naviola.app/` directory. Radiola's data untouched.

### 13.3 — Remove Sparkle Update Feed
Radiola's Sparkle feed would try to update Naviola back to Radiola.

**Files:**
- `Radiola/Info.plist`: Remove or comment out `SUFeedURL` key
- `Radiola/Preferences/UpdatePanel.swift`: Disable or replace with Naviola-specific update mechanism (or remove the Updates preference tab)
- Consider: Replace with GitHub Releases check for Naviola's own repo

**Validation:** No update prompts from Radiola's feed. Preferences → Updates tab either hidden or shows Naviola update info.

### 13.4 — User-Visible Strings
Replace all user-facing "Radiola" text with "Naviola". Radio features use "Radio" not "Radiola".

**Localized string files:**
- `Radiola/Localizable.xcstrings`:
  - `"Open Radiola…"` → `"Open Naviola…"`
  - `"Radiola logs"` → `"Naviola logs"`
- `Radiola/mul.lproj/MainMenu.xcstrings` (27 occurrences across 5 languages):
  - `"Radiola"` → `"Naviola"` (menu title)
  - `"Quit Radiola"` → `"Quit Naviola"`
  - `"About Radiola"` → `"About Naviola"`
  - `"Hide Radiola"` → `"Hide Naviola"`
  - `"Radiola Help"` → `"Naviola Help"`
  - All translations (de, it, ru, zh-Hans)

**Swift code:**
- `StatuBarController.swift` line 220: `"Open Radiola…"` → `"Open Naviola…"`

**Validation:** No "Radiola" visible anywhere in the app UI.

### 13.5 — XIB Module References
All 11 XIB files reference `customModule="Radiola"`. If we rename the Xcode target module, these must match.

**Note:** If we keep the target name as "Radiola" internally (just changing display name and bundle ID), XIBs don't need to change. If we rename the target to "Naviola", all 11 XIBs need updating.

**Recommendation:** Rename the target to "Naviola" for consistency. Update all XIBs.

**Files:** AudioPage.xib, UpdatePanel.xib, MainMenu.xib, SidebarSecondLevelView.xib, SidebarTopLevelView.xib, SideBar.xib, ToolbarPlayView.xib, AddGroupDialog.xib, AddStationDialog.xib, StationsWindow.xib, LogsWindow.xib

### 13.6 — Project Structure Rename
Rename the Xcode project and source directory.

**Changes:**
- `Radiola.xcodeproj/` → `Naviola.xcodeproj/`
- `Radiola/` source directory → `Naviola/` (optional — high churn, could keep as-is internally)
- Scheme: `Radiola` → `Naviola`, `Radiola Release` → `Naviola Release`
- Test target: `RadiolaTests` → `NaviolaTests`
- All `@testable import Radiola` → `@testable import Naviola`

**Recommendation:** Rename xcodeproj and schemes. Keep source directory as `Radiola/` to minimize diff churn — it's internal and doesn't affect users.

### 13.7 — Build Scripts and CI
Update build scripts for the new app name.

**Files:**
- `build.sh`: `APP_NAME="Radiola"` → `APP_NAME="Naviola"`, new provisioning profile
- `build-sandboxed.sh`: Same changes
- `.github/workflows/build-mac.yml`: Artifact names, remove upstream GitHub URLs
- `.github/workflows/dmg_settings.json`: `"title": "Radiola"` → `"title": "Naviola"`

### 13.8 — App Icon
Create or adapt a Naviola icon distinct from Radiola's.

**Current:** 10 PNG files in `Assets.xcassets/AppIcon.appiconset/` named `radiola-*.png`

**Options:**
- Design a new icon (Navidrome-inspired)
- Modify Radiola's icon with different colors
- Use a placeholder SF Symbol icon temporarily

### 13.9 — Documentation and Credits
Update docs and add proper attribution.

**Files:**
- `README.md`: Rewrite for Naviola — describe as a Navidrome menu bar client, credit Radiola as the foundation
- `CLAUDE.md`: Already mostly correct, minor updates
- `docs/prd/*.md`: Internal docs, update references
- Add `CREDITS.md` or section in README: "Naviola is built on [Radiola](https://github.com/SokoloffA/radiola) by Alexander Sokolov"

### 13.10 — Code Comments (Optional)
Update `//  Radiola` headers in 60+ Swift files to `//  Naviola`.

**Low priority** — cosmetic only, high churn. Could do with a script:
```bash
find Radiola -name "*.swift" -exec sed -i '' 's|//  Radiola|//  Naviola|g' {} \;
```

## Coexistence Verification Checklist
After rebranding, verify both apps can run simultaneously:

- [ ] Different app icons in Dock
- [ ] Different names in menu bar
- [ ] Separate Application Support directories
- [ ] Separate UserDefaults (preferences)
- [ ] Separate Keychain entries (if applicable)
- [ ] No Sparkle update conflicts
- [ ] Independent window positions (autosave names)
- [ ] Both can play audio simultaneously (different audio engines)

## Dependencies
All functional phases (0-12) complete.

## Status
- [ ] 13.1 Bundle identity
- [ ] 13.2 Data directory isolation
- [ ] 13.3 Remove Sparkle update feed
- [ ] 13.4 User-visible strings
- [ ] 13.5 XIB module references
- [ ] 13.6 Project structure rename
- [ ] 13.7 Build scripts and CI
- [ ] 13.8 App icon
- [ ] 13.9 Documentation and credits
- [ ] 13.10 Code comments (optional)
