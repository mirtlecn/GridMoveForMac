---
title: GridMove App Design
description: 记录 GridMove 的当前软件行为和实现细节，基于 `Sources/GridMove/` 代码。此文档用于对软件设计的整体理解和新功能。此文档随着软件迭代更新，反映当前设计和实现状态。
status: active
---

# GridMove App Design

## 1. Purpose

GridMove is a native macOS menu bar application for:

- applying predefined window layouts
- cycling layouts
- moving windows with pointer-triggered interactions
- relaying CLI layout actions to the running app

This document records the current software behavior and implementation details based on the code in `Sources/GridMove/`.

## 2. Current Product Surface

The current codebase implements these user-visible surfaces:

- menu bar app
- settings window with `General`, `Layouts`, `Appearance`, `Hotkeys`, and `About` tabs
- CLI entrypoint for layout actions
- JSON configuration at `~/.config/GridMove/config.json`
- layout-group files at `~/.config/GridMove/layout/*.grid.json`

The settings window now uses the real configuration model:

- `General`, `Appearance`, and `Hotkeys` apply immediately and save through the shared settings action path
- `Layouts` keeps a draft and only saves when the user clicks `Save`
- switching away from `Layouts` keeps that draft in memory without saving it
- closing the settings window discards any unsaved `Layouts` draft
- `About` can manually reload configuration and restore the built-in defaults

`UI.md` records the accepted interaction structure for this window.

## 3. Runtime Architecture

The runtime is coordinated by `AppDelegate`.

Main responsibilities:

- load configuration on launch
- keep the menu bar state in sync with the current configuration
- start and stop the drag controller and shortcut controller based on Accessibility status
- listen for remote CLI commands
- request Accessibility permission from the system when access is missing
- post a success notification when manual config reload applies the full config without skipped files
- post a diagnostic notification when manual config reload rejects the full config
- post a warning when manual config reload skips invalid layout files but still applies the remaining layout groups

Main runtime components:

- `AppDelegate`: application lifecycle and coordination
- `ConfigurationStore`: JSON persistence and schema conversion
- `WindowController`: window lookup, focus, movement, layout application
- `LayoutEngine`: trigger-slot resolution and layout cycling
- `DragGridController`: pointer-triggered runtime interaction
- `ShortcutController`: global keyboard shortcut handling
- `LayoutActionExecutor`: shared logic for menu, shortcut, and CLI actions
- `DistributedCommandRelay`: CLI-to-app command relay

CLI layout lookup rules:

- `-layout <number>` resolves the 1-based layout index inside the active layout group's indexed layouts
- `-layout "<name>"` resolves a layout by name inside the active layout group
- duplicate layout names are allowed inside one group; CLI name lookup fails when more than one layout matches and reports the conflicting layout indexes
- internal layout IDs are not part of the CLI interface

## 4. Configuration Model

Persistent configuration is stored in one main JSON file plus numbered layout-group JSON files.

Important properties:

- layout IDs are internal only and are regenerated from array order
- hotkey binding IDs are internal only and are regenerated from array order
- `config.json` stores `general`, `appearance`, `dragTriggers`, `hotkeys`, and `monitors`
- `layout/*.grid.json` stores one `layoutGroups[]` object per file
- managed layout-group file names must match `<positive-integer>.grid.json`
- persisted `applyLayoutByIndex` actions point to the 1-based layout index within the active layout group's indexed layouts
- stroke colors are stored as `#RRGGBBAA`
- `general.activeLayoutGroup` selects the currently active layout group
- `general.launchAtLogin` stores the desired login-item state and defaults to `false` when missing or invalid
- `general.mouseButtonNumber` selects the hold-to-drag mouse button using user-facing numbering, where `3` is the standard middle button
- the menu bar shows `Middle mouse drag` when `general.mouseButtonNumber == 3`, and `Mouse button <n> drag` for other configured button numbers
- `monitors` stores the last known monitor name by persistent display UUID using the shape `"<monitor-uuid>": "<monitor-name>"`
- monitor metadata refresh only happens on app startup and manual reload; normal setting saves do not rescan displays
- previously learned monitor UUIDs remain in `monitors` even when those displays are currently disconnected
- `layoutGroups[*].includeInGroupCycle` controls whether layout-mode Shift cycling can switch to that group
- `layoutGroups[*].protect` prevents removing a protected group from the settings UI and defaults to `false` when missing or invalid
- protected groups keep their names read-only in the settings UI
- `layoutGroups[*].sets[*].monitor` routes layouts to `all`, `main`, one monitor UUID, or multiple monitor UUIDs
- `layoutGroups[*].sets[*].layouts` order drives menu order, layout-index numbering, and same-display trigger precedence
- `layoutGroups[*].sets[*].layouts[*].includeInMenu` controls whether a layout appears in the menu bar
- empty layout groups and empty monitor sets are allowed and remain inert at runtime
- the settings outline shows `Layout №<index>` when a layout name is empty

Current drag-trigger configuration fields:

- `enableMouseButtonDrag`
- `enableModifierLeftMouseDrag`
- `preferLayoutMode`
- `applyLayoutImmediatelyWhileDragging`
- `modifierGroups`
- `activationDelayMilliseconds`
- `activationMoveThreshold`

### 4.1 Current Default Configuration

The built-in default configuration currently resolves to the following values.

`general`

- `isEnabled = true`
- `launchAtLogin = false`
- `excludedBundleIDs = ["com.apple.Spotlight"]`
- `excludedWindowTitles = []`
- `mouseButtonNumber = 3`

`appearance`

- `triggerHighlightMode = none`
- `triggerFillOpacity = 0.08`
- `triggerGap = 0`
- `triggerStrokeWidth = 2`
- `triggerStrokeColor = #00FDFFFF`
- `layoutGap = 1` (integer, points)
- `renderWindowHighlight = true`
- `highlightFillOpacity = 0.20`
- `highlightStrokeWidth = 3`
- `highlightStrokeColor = #FFFFFFEB`

`dragTriggers`

- `enableMouseButtonDrag = true`
- `enableModifierLeftMouseDrag = true`
- `preferLayoutMode = false`
- `applyLayoutImmediatelyWhileDragging = false`
- `modifierGroups = [[ctrl, cmd, shift, alt], [ctrl, shift, alt]]`
- `activationDelayMilliseconds = 300`
- `activationMoveThreshold = 10`

`hotkeys`

- `ctrl + cmd + shift + alt + l` -> cycle next layout
- `ctrl + cmd + shift + alt + j` -> cycle previous layout
- `ctrl + cmd + shift + alt + \` -> apply active-group layout index `4`
- `ctrl + cmd + shift + alt + [` -> apply active-group layout index `2`
- `ctrl + cmd + shift + alt + ]` -> apply active-group layout index `6`
- `ctrl + cmd + shift + alt + ;` -> apply active-group layout index `3`
- `ctrl + cmd + shift + alt + '` -> apply active-group layout index `7`
- `ctrl + cmd + shift + alt + -` -> apply active-group layout index `1`
- `ctrl + cmd + shift + alt + =` -> apply active-group layout index `5`
- `ctrl + cmd + shift + alt + return` -> apply active-group layout index `10`

`layoutGroups`

- the default `default` group contains one `all` set with 11 layouts
- the default `fullscreen` group contains one `main` set and one fallback `all` set
- both default groups participate in layout-mode group cycling
- all layouts use a `12 x 6` grid
- `layout-1` to `layout-9` use screen trigger regions
- `layout-10` uses a screen trigger region
- `layout-11` uses the full menu bar strip as its trigger region
- `layout-1` to `layout-10` participate in layout-index shortcuts and layout cycling
- `layout-11` does not participate in layout-index shortcuts or layout cycling
- the `fullscreen` group uses these layouts:
  - `Fullscreen main`: full screen with a full-screen trigger
  - `Main left 1/2`: left half with a left-quarter screen trigger
  - `Main right 1/2`: right half with a right-quarter screen trigger
  - `Fullscreen main (menu bar)`: full screen with a menu-bar trigger, hidden from the menu bar list, and excluded from layout-index shortcuts and layout cycling
  - `Fullscreen other`: full screen with a full-screen trigger
  - `Fullscreen other (menu bar)`: full screen with a menu-bar trigger, hidden from the menu bar list, and excluded from layout-index shortcuts and layout cycling

Default layout names in order:

- `layout-1`: `Left 1/3`
- `layout-2`: `Left 1/2`
- `layout-3`: `Left 2/3`
- `layout-4`: `Center`
- `layout-5`: `Right 2/3`
- `layout-6`: `Right 1/2`
- `layout-7`: `Right 1/3`
- `layout-8`: `Right 1/3 top`
- `layout-9`: `Right 1/3 bottom`
- `layout-10`: `Full`
- `layout-11`: `Full (menu bar)`

Compatibility behavior:

- `config.json` must not contain embedded `layoutGroups`
- if `config.json` decoding fails, including invalid JSON, comments, embedded `layoutGroups`, or an invalid persisted layout index, the file is left untouched
- matching layout files that fail to decode are skipped individually
- unmatched files in `layout/` are ignored
- after skipping invalid layout files, the merged configuration must still pass validation or the whole load fails
- when skipped layout files contribute to a manual reload failure, the notification includes both the fatal config error and the skipped-file details
- successful saves also refresh `~/.config/GridMove/config.last-known-good.json` and `~/.config/GridMove/layout.last-known-good/*.grid.json`
- on launch, the app loads `config.last-known-good.json` plus `layout.last-known-good/` when the primary config is invalid, and only falls back to built-in defaults when no valid recovery snapshot exists
- on manual reload, full-load failures are rejected and the current in-memory configuration keeps running
- on manual reload, full success applies the config and posts a success notification
- on manual reload, partial success applies valid layout files and warns about skipped files
- missing or invalid `general.launchAtLogin` defaults to `false`
- missing or invalid `preferLayoutMode` defaults to `false`
- missing or invalid `applyLayoutImmediatelyWhileDragging` defaults to `false`
- missing `includeInGroupCycle` defaults to `true`
- missing `triggerRegion` means the layout is menu, shortcut, and CLI only
- missing `triggerHighlightMode` defaults to `none`
- invalid `triggerHighlightMode` falls back to `all`
- missing `triggerFillOpacity` defaults to `0.08`
- missing `triggerStrokeWidth` defaults to `2`
- missing `includeInMenu` defaults to `true`
- missing `includeInLayoutIndex` defaults to `true`
- missing or invalid `general.mouseButtonNumber` defaults to `3`
- missing or invalid `layoutGap` defaults to `1`

## 5. Accessibility Lifecycle

GridMove depends on Accessibility permission for window targeting and manipulation.

The app uses `AccessibilityAccessMonitor` to cache the current permission state.

Polling behavior:

- no background polling while permission is granted
- `1s` polling while permission is missing
- every real action entry re-checks Accessibility access on demand before using AX-dependent behavior

When permission is available and `general.isEnabled` is `true`:

- drag interactions are enabled
- shortcut handling is enabled

When permission is missing, revoked, or the app is disabled:

- drag interactions stop
- shortcut handling stops
- if the access state changed to missing, the app directly triggers one system Accessibility permission request for that state transition
- if access stays missing, the app does not keep re-requesting until the next transition or the next launch
- while permission is missing, the menu bar menu collapses to a single `Get accessibility access` item
- clicking `Get accessibility access` invalidates the cached permission state and triggers the same system Accessibility prompt path again
- the normal menu items return only after Accessibility permission is actually available

Launch-at-login coordination:

- GridMove uses `SMAppService.mainApp` as the login-item backend
- the menu item `Launch at login` is bound to `general.launchAtLogin`
- startup and manual reload schedule a login-item reconciliation pass after config is applied
- reconciliation only runs once Accessibility access is available; if access is still missing, the app waits for the existing polling path to observe a granted state
- normal config saves do not touch the login-item backend
- direct clicks on `Launch at login` trigger immediate register or unregister attempts
- enabling from the menu first re-checks Accessibility access and prompts if needed; if access is still missing, the config stays unchanged
- if enabling fails, still requires system approval, or does not end in `enabled`, GridMove writes `general.launchAtLogin = false` and posts a notification that points the user to System Settings > General > Login Items
- if disabling fails or does not end in `disabled`, GridMove keeps the existing config value and posts a failure notification

Layout cycling state is stored in memory only:

- GridMove keeps the most recent 10 window-to-layout records
- older window records are dropped automatically
- reloading a changed layout list clears the recorded cycle baseline

Layout-mode group cycling:

- while a drag interaction is active in layout-selection mode, pressing and releasing `Shift` alone cycles to the next group whose `includeInGroupCycle` is `true`
- while a drag interaction is active in layout-selection mode, vertical mouse-wheel scrolling cycles groups directly: upward scrolling moves to the previous group and downward scrolling moves to the next group
- one scroll gesture only triggers one group change after a small accumulated-distance threshold; the gesture must stop briefly before the next group change can trigger
- the `Shift` tap is evaluated relative to the modifier baseline captured when the interaction starts, so GridMove only cycles groups when `Shift` is tapped as the only extra modifier beyond that baseline
- the switch updates in-memory runtime state immediately, then saves `general.activeLayoutGroup` asynchronously
- the trigger overlay is recomputed immediately for the new group
- after the switch, layout selection returns to the same pre-threshold state used at initial activation, so no layout is applied until the pointer crosses the movement threshold again
- the overlay shows the new group name centered inside the current highlight region for the same duration used by the move-only highlight flash, while keeping the current highlight and trigger overlay visible

## 6. Target Window Resolution

`WindowController` has two main targeting paths:

- focused-window lookup
- window-under-cursor lookup

Focused-window lookup:

- first ask the system-wide AX focused application
- if that fails, fall back to the frontmost app from `NSWorkspace`

Pointer-based lookup:

- inspect `CGWindowListCopyWindowInfo`
- prefer windows whose bounds contain the pointer
- resolve AX windows for the owning app
- score matches by title, bounds, and standard-window status
- fall back to AX hit-testing and parent traversal if direct matching fails

Window exclusion rules apply in both paths:

- built-in excluded bundle IDs
- configured excluded bundle IDs
- configured excluded titles
- non-operable windows
- desktop-like Finder window

## 7. Drag Interaction Model

The drag runtime is owned by `DragGridController`.

Primary trigger entry points:

- configured mouse-button hold
- configured modifier group + left mouse

Once active, the trigger runs one of two sub-modes:

- `layoutSelection`
- `moveOnly`

Default sub-mode:

- controlled by `dragTriggers.preferLayoutMode`
- `true` starts in layout selection
- `false` starts in move-only

Mode switching while active:

- right click toggles sub-mode
- Option key tap toggles sub-mode

Exit conditions:

- `Esc`
- releasing the primary trigger button
- Accessibility loss
- event-tap shutdown paths

### 7.1 Layout Selection

Behavior:

- resolve trigger slots for the active screen
- show overlay
- keep a move threshold before layout application starts
- before the threshold is crossed, highlight the current window frame
- after the threshold is crossed, use hovered trigger slot to apply layouts
- remember the last applied layout to avoid redundant reapplication
- if trigger regions overlap on one display, the later declared layout wins
- overlapping trigger regions are resolved when trigger slots are built, so earlier layouts do not keep temporary hit regions inside a later layout's winning area

Cross-screen behavior:

- if the pointer changes screens, trigger slots are recomputed for the new screen

### 7.2 Move-only Mode

Behavior:

- when entering move-only mode, the current window frame is briefly highlighted with a fade-out flash
- the flash uses the same style as the window highlight overlay (stroke color, stroke width, fill opacity)
- the flash is only shown when `appearance.renderWindowHighlight` is enabled
- after the flash fades out, the overlay is dismissed
- only window position is updated
- window size is preserved
- movement keeps the pointer-to-window grab offset captured at mode entry

Switching from move-only back to layout selection:

- resets to the same state as an initial layout-selection entry
- does not immediately apply the layout under the current pointer
- waits for the same thresholded layout-selection conditions as a normal entry

## 8. Shortcuts, Menu Actions, and CLI

There are three non-pointer action entry points:

- menu bar action items
- global keyboard shortcuts
- CLI relay

Menu actions:

- are built from current configuration
- collapse to a single `Get accessibility access` item while Accessibility permission is missing
- include a `Layout group` submenu that switches `general.activeLayoutGroup`
- keep a separator between the drag-preference items and the `Layout group` submenu
- include `Settings...`, `Launch at login`, and `Quit` in the final settings section, in that order
- only include layouts whose `includeInMenu` value is `true`
- always go through `LayoutActionExecutor`
- layouts hidden from the menu remain available to trigger and CLI paths, and remain available to layout-index shortcuts only when `includeInLayoutIndex` is `true`

Keyboard shortcuts:

- are captured through a global event tap
- resolve to the first matching enabled binding
- interpret `applyLayoutByIndex` as a global index within the active layout group's indexed layouts
- only require the configured index to be a positive integer; missing indexes fail when invoked instead of at load time
- operate on the currently resolved target window
- use physical-key names shared by recording, JSON config, and runtime matching
- support the standard number row (`1` ... `0`)
- support function keys (`f1` ... `f20`)
- support navigation keys (`left`, `right`, `up`, `down`, `home`, `end`, `pageUp`, `pageDown`, `insert`)
- support common special keys (`return`, `tab`, `space`, `delete`, `forwardDelete`, `escape`)
- support keypad keys (`keypad0` ... `keypad9`, `keypadDecimal`, `keypadPlus`, `keypadMinus`, `keypadMultiply`, `keypadDivide`, `keypadEnter`, `keypadEquals`, `keypadClear`)
- support common aliases (`enter`, `backspace`, `esc`, `del`, `ins`, `help`, `pgup`, `pgdn`, and `kp*`)

CLI:

- parses arguments in the command process
- sends commands to the running app through `DistributedNotificationCenter`
- waits for a reply notification with a short timeout
- fails fast if the app is not running

This relay exists so CLI actions share the same runtime window-targeting behavior as the app instead of manipulating windows from a short-lived helper process.

Display set resolution:

- each physical display resolves exactly one set from the active layout group
- priority is explicit monitor UUID or UUID array, then `main`, then `all`
- drag overlays and trigger hit testing only use the resolved set for the current display
- `cycleNext` and `cyclePrevious` only use the resolved set for the target window's current display, skip layouts whose `includeInLayoutIndex` is `false`, and never move the window across displays
- menu, shortcut, and CLI direct layout application first resolve which displays map to the selected layout set inside the active group, then keep the current display only when it belongs to that set
- `monitor: all` keeps the current display only when that display still resolves to the selected set; if another set owns the current display, it picks the first currently connected display that resolves to the selected set
- `monitor: main` always targets the current system main display
- `monitor: "<monitor-uuid>"` always targets that display
- `monitor: ["<monitor-uuid>", ...]` keeps the current display when it is included; otherwise it picks the first currently connected display in declaration order
- menu actions target layouts by internal layout ID so same-name layouts in different sets still go to the intended display

## 9. Overlay Behavior

Overlay drawing is handled by `OverlayController`.

Runtime rules:

- overlay is only relevant in `layoutSelection`
- before threshold crossing, it highlights the current target window
- after threshold crossing, it highlights the target frame of the hovered slot
- in `moveOnly`, a brief highlight flash of the current window frame is shown at mode entry, then the overlay fades out and is dismissed
- the flash respects `appearance.renderWindowHighlight` and uses the same highlight style

Appearance is controlled by configuration:

- trigger area visibility
- trigger stroke color
- trigger gap
- layout gap (integer, applied to window layout frames and overlay highlight; layouts whose target frame collapses on the current screen are skipped)
- window highlight visibility
- window fill opacity
- window stroke width and color

## 10. Known Implementation Hacks and Compromises

These behaviors are intentional and should be preserved unless replaced with a better design.

### 10.1 Synthetic other-mouse click replay

Configured mouse-button activation uses a hold delay.
If the hold never becomes a drag interaction, GridMove replays a synthetic click sequence for that same other-mouse button so the original click behavior is not lost.

Relevant code:

- `DragGridController+Utilities.swift`
- `SyntheticEventMarker.swift`

### 10.2 CLI command relay through distributed notifications

CLI layout actions do not manipulate windows directly.
They send a command to the running app and wait for a reply.

This is a compromise to preserve the same window-resolution and focus behavior across:

- CLI
- menu actions
- running-app state

### 10.3 Focus fallback and pointer fallback

Focused AX window lookup can fail in real applications.
The code therefore falls back through multiple layers:

- AX focused app
- frontmost app
- CGWindow list
- AX element-at-point traversal

This stack is deliberately redundant.

### 10.4 Cross-screen settle after layout apply

Cross-screen frame changes are not always stable in one pass.
The code first primes the window onto the target screen, then reapplies position and size after a short delay.

Relevant code:

- `primeWindowOnTargetScreen`
- `scheduleCrossScreenSettle`

### 10.5 Notification fallback in non-bundled runs

When the app is not running as a normal app bundle, user notifications fall back to AppleScript notifications.
This keeps local development behavior usable without bundling.

## 11. Non-goals and Out-of-scope Areas

Current design boundaries:

- no Space switching
- no Mission Control automation
- no cross-Space window movement
- no fullscreen-Space management
- no third-party shortcut dependency

These boundaries matter because several code paths already use platform heuristics and AX workarounds; expanding into cross-Space behavior would need a different design.
