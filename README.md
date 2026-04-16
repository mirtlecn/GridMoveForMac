# GridMove

GridMove is a native macOS menu bar app that migrates the current Hammerspoon window layout and drag grid workflow into a standalone AppKit-based application.

## Current scope

- Global keyboard shortcuts for cycling layouts and applying named layouts
- Layout cycling that follows the current order in the Settings UI and skips layouts excluded from cycling
- Drag grid activation by middle mouse hold or configured modifier groups plus left mouse
- Trigger regions that can use either the screen grid or a segmented menu bar strip
- Accessibility-based target window lookup, focus, resize, and fullscreen exit
- Non-activating overlay for trigger slots and target window preview
- Native AppKit settings window with four sections: General, Layouts, Appearance, and Hotkeys
- Property list configuration stored at `~/Library/Application Support/GridMove/config.plist`

## Out of scope in this first version

- Space switching
- Mission Control automation
- Cross-Space window movement
- Fullscreen Space management
- Sparkle integration
- Third-party shortcut libraries

## Build

```bash
make release
```

This creates:

- `dist/GridMove.app`
- `dist/GridMove.dmg`

The packaged app bundle includes a generated app icon derived from the menu bar glyph.

The default signing mode is ad-hoc signing for local testing. To use a real certificate, override `SIGN_IDENTITY`:

```bash
make release SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)"
```

`make release` runs the Swift test suite before packaging. To run tests without packaging, use:

```bash
make test
```

To run the debug build locally, use:

```bash
make dev
```

## Run

```bash
swift run
```

On first launch, grant Accessibility access in System Settings. The app stays in the menu bar and hides the Dock icon by default.

## CLI

The compiled executable can send layout commands to an already running GridMove app:

```bash
.build/release/GridMove -next
.build/release/GridMove -pre
.build/release/GridMove -layout "Center"
.build/release/GridMove -layout layout-4
.build/release/GridMove -layout "Center" -window-id 12345
.build/release/GridMove -help
```

Start GridMove first before using CLI layout actions. If GridMove is not running, the CLI prints an error and exits.

The `-layout` argument accepts either the layout name or the layout identifier. If `-window-id <cg-window-id>` is provided, GridMove targets that exact on-screen window. Otherwise CLI actions operate on the currently focused window only.
If multiple layouts share the same name, use the layout identifier instead. Ambiguous layout names are rejected.

## Configuration

The app writes a default plist configuration on first launch. The initial values mirror the migrated `~/.hammerspoon` layouts, trigger regions, modifier groups, and shortcut defaults.

The Settings window includes:

- `General` for the global enable switch, excluded bundle identifiers, excluded window titles, and drag trigger settings
- `Layouts` for visual editing of window regions and trigger regions, menu bar trigger selection, drag-and-drop layout ordering, and cycle inclusion
- `Appearance` for trigger and highlight overlay rendering
- `Hotkeys` for direct layout actions and cycle shortcuts

When GridMove is disabled, drag triggers, keyboard shortcuts, and CLI layout actions are all blocked until it is enabled again.
