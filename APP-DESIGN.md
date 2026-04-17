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
- Accessibility onboarding window
- CLI entrypoint for layout actions
- JSON configuration at `~/.config/GridMove/config.json`

There is no full settings window implementation in the current codebase.
`UI-UX.md` records the intended interaction model for future UI work.

## 3. Runtime Architecture

The runtime is coordinated by `AppDelegate`.

Main responsibilities:

- load configuration on launch
- keep the menu bar state in sync with the current configuration
- start and stop the drag controller and shortcut controller based on Accessibility status
- listen for remote CLI commands
- show onboarding when Accessibility is missing
- post a notification when manual config reload falls back to defaults

Main runtime components:

- `AppDelegate`: application lifecycle and coordination
- `ConfigurationStore`: JSON persistence and schema conversion
- `WindowController`: window lookup, focus, movement, layout application
- `LayoutEngine`: trigger-slot resolution and layout cycling
- `DragGridController`: pointer-triggered runtime interaction
- `ShortcutController`: global keyboard shortcut handling
- `LayoutActionExecutor`: shared logic for menu and CLI actions
- `DistributedCommandRelay`: CLI-to-app command relay

## 4. Configuration Model

Persistent configuration is stored in JSON and normalized on read and write.

Important properties:

- layout IDs are internal only and are regenerated from array order
- hotkey binding IDs are internal only and are regenerated from array order
- persisted `applyLayout` actions point to the 1-based layout index
- stroke colors are stored as `#RRGGBBAA`

Current drag-trigger configuration fields:

- `middleMouseButtonNumber`
- `enableMiddleMouseDrag`
- `enableModifierLeftMouseDrag`
- `preferLayoutMode`
- `modifierGroups`
- `activationDelaySeconds`
- `activationMoveThreshold`

### 4.1 Current Default Configuration

The built-in default configuration currently resolves to the following values.

`general`

- `isEnabled = true`
- `excludedBundleIDs = ["com.apple.Spotlight"]`
- `excludedWindowTitles = []`

`appearance`

- `renderTriggerAreas = false`
- `triggerOpacity = 0.2`
- `triggerGap = 2`
- `triggerStrokeColor = system accent color with alpha 0.2`
- `renderWindowHighlight = true`
- `highlightFillOpacity = 0.08`
- `highlightStrokeWidth = 3`
- `highlightStrokeColor = #FFFFFFEB`

`dragTriggers`

- `middleMouseButtonNumber = 2`
- `enableMiddleMouseDrag = true`
- `enableModifierLeftMouseDrag = true`
- `preferLayoutMode = true`
- `modifierGroups = [[ctrl, cmd, shift, alt], [ctrl, shift, alt]]`
- `activationDelaySeconds = 0.3`
- `activationMoveThreshold = 10`

`hotkeys`

- `ctrl + cmd + shift + alt + l` -> cycle next layout
- `ctrl + cmd + shift + alt + j` -> cycle previous layout
- `ctrl + cmd + shift + alt + \` -> apply `layout-4`
- `ctrl + cmd + shift + alt + [` -> apply `layout-2`
- `ctrl + cmd + shift + alt + ]` -> apply `layout-6`
- `ctrl + cmd + shift + alt + ;` -> apply `layout-3`
- `ctrl + cmd + shift + alt + '` -> apply `layout-7`
- `ctrl + cmd + shift + alt + -` -> apply `layout-1`
- `ctrl + cmd + shift + alt + =` -> apply `layout-5`
- `ctrl + cmd + shift + alt + return` -> apply `layout-10`

`layouts`

- the default set contains 11 layouts
- all layouts use a `12 x 6` grid
- `layout-1` to `layout-9` use screen trigger regions
- `layout-10` uses a screen trigger region
- `layout-11` uses the full menu bar strip as its trigger region
- `layout-1` to `layout-10` participate in layout cycling
- `layout-11` does not participate in layout cycling

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
- `layout-10`: `Fill all screen`
- `layout-11`: `Fill all screen (Menu bar)`

Compatibility behavior:

- if config decoding fails, the file is left untouched
- the app falls back to built-in defaults for the current launch
- missing `preferLayoutMode` defaults to `true`

## 5. Accessibility Lifecycle

GridMove depends on Accessibility permission for window targeting and manipulation.

The app uses `AccessibilityAccessMonitor` to cache the current permission state.

Polling behavior:

- fast polling while permission is granted
- slower polling while permission is missing

When permission is available:

- onboarding is closed
- drag interactions are enabled
- shortcut handling is enabled

When permission is missing or revoked:

- drag interactions stop
- shortcut handling stops
- onboarding is shown

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
- built-in excluded titles
- configured excluded titles
- non-operable windows
- desktop-like Finder window

## 7. Drag Interaction Model

The drag runtime is owned by `DragGridController`.

Primary trigger entry points:

- middle mouse hold
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

Cross-screen behavior:

- if the pointer changes screens, trigger slots are recomputed for the new screen

### 7.2 Move-only Mode

Behavior:

- overlay is hidden immediately
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
- always go through `LayoutActionExecutor`

Keyboard shortcuts:

- are captured through a global event tap
- resolve to the first matching enabled binding
- operate on the currently resolved target window

CLI:

- parses arguments in the command process
- sends commands to the running app through `DistributedNotificationCenter`
- waits for a reply notification with a short timeout
- fails fast if the app is not running

This relay exists so CLI actions share the same runtime window-targeting behavior as the app instead of manipulating windows from a short-lived helper process.

## 9. Overlay Behavior

Overlay drawing is handled by `OverlayController`.

Runtime rules:

- overlay is only relevant in `layoutSelection`
- before threshold crossing, it highlights the current target window
- after threshold crossing, it highlights the target frame of the hovered slot
- in `moveOnly`, overlay is dismissed

Appearance is controlled by configuration:

- trigger area visibility
- trigger stroke opacity and color
- trigger gap
- window highlight visibility
- window fill opacity
- window stroke width and color

## 10. Known Implementation Hacks and Compromises

These behaviors are intentional and should be preserved unless replaced with a better design.

### 10.1 Synthetic middle-click replay

Middle mouse activation uses a hold delay.
If the hold never becomes a drag interaction, GridMove replays a synthetic middle-click sequence so the original middle-click behavior is not lost.

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
