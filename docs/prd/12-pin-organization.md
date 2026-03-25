# Phase 12: Pin Organization — Groups, Ordering, and Menu Editing

## Goal
Allow users to organize pinned items into groups and control their order, mirroring the radio station group/subgroup pattern from Radiola's "My stations" but for Navidrome content. This makes the menu bar dropdown and Pinned sidebar section manageable as the pin count grows.

## Context
Currently, pinned items are a flat list — albums, artists, genres, and playlists all in one level. As users pin more content, this becomes unwieldy. Radiola solves this for radio stations with OPML groups (folders). We need the same for pins.

The menu bar dropdown should reflect the pin organization: groups become submenus, ungrouped pins stay at the top level.

## Design

### Pin Groups
A `NaviolaPinnedGroup` is a named folder that contains pinned items:

```swift
struct NaviolaPinnedGroup: Codable, Identifiable {
    let id: UUID
    var title: String
    var items: [NaviolaPinnedItem]
}
```

The `NaviolaPinnedItemStore` changes from a flat `[NaviolaPinnedItem]` to a structure with both ungrouped items and groups:

```swift
class NaviolaPinnedItemStore {
    var ungrouped: [NaviolaPinnedItem]    // top-level pins
    var groups: [NaviolaPinnedGroup]       // folders of pins
}
```

### Drag-and-Drop Reordering
In the Pinned sidebar view:
- Drag items to reorder within the list
- Drag items into/out of groups
- Drag to create new groups (drop on another item to group them)
- Context menu: "New Group", "Move to Group >", "Remove from Group"

### Menu Bar Reflection
The status bar "Pinned" section mirrors the organization:
- Ungrouped pins → top-level menu items
- Groups → submenus (like Radiola's `buildSubmenuFavoritesMenu`)
- Click any item → plays via NaviolaPlayQueue

### Edit Mode
A future "Edit Pinned..." menu item or toolbar button that opens an editor view:
- Reorder by drag
- Create/rename/delete groups
- Remove pins
- Similar to how Radiola lets you manage station groups in "My stations"

## Tasks

### 12.1 — Pin Groups Model
**Edit** `NaviolaPinnedItems.swift`:
- Add `NaviolaPinnedGroup` struct
- Update `NaviolaPinnedItemStore` to hold `ungrouped` + `groups`
- Migrate existing flat `items` to `ungrouped` on first load
- JSON persistence updated for new structure

**Validation**: Unit test — create groups, add/move items, persist/reload.

### 12.2 — Pinned Sidebar with Groups
Update the Pinned view in the delegate to show groups as collapsible sections:
- Groups show as expandable rows (with folder icon)
- Ungrouped items show at root level
- Items inside groups show when expanded

**Validation**: Create a group → items appear nested. Expand/collapse works.

### 12.3 — Context Menu for Organization
Add context menu items to the Pinned view:
- "New Group" — creates an empty group
- "Move to Group >" — submenu listing available groups
- "Remove from Group" — moves item to ungrouped
- "Rename Group" — inline edit
- "Delete Group" — removes group, moves items to ungrouped

**Validation**: Right-click → create group → move pin into it → verify in sidebar and menu.

### 12.4 — Drag-and-Drop Reordering
Implement NSOutlineView drag-and-drop in the Pinned view:
- Reorder items within ungrouped
- Reorder items within a group
- Move items between groups and ungrouped
- Reorder groups themselves

**Validation**: Drag items around, verify order persists after restart.

### 12.5 — Menu Bar Group Support
**Edit** `NaviolaMenuBuilder.swift`:
- Ungrouped pins → flat menu items
- Groups → NSMenuItem with submenu
- Click → plays via NaviolaPlayQueue (same as now)

**Validation**: Pin organization reflected in menu bar dropdown.

### 12.6 — Auto-Group Suggestions
When pinning, optionally suggest grouping:
- Pin an album by Artist X when other albums by Artist X are already pinned → suggest "Group under Artist X?"
- Pin a genre album when that genre is already a group → suggest adding to group

This is a nice-to-have polish item.

## Dependencies
Phase 11 (browse navigation should be stable).

## Status
- [ ] 12.1 Pin groups model
- [ ] 12.2 Pinned sidebar with groups
- [ ] 12.3 Context menu for organization
- [ ] 12.4 Drag-and-drop reordering
- [ ] 12.5 Menu bar group support
- [ ] 12.6 Auto-group suggestions
