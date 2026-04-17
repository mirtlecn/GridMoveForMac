# GridMove

GridMove is a native macOS menu bar app that migrates the current Hammerspoon window layout and drag grid workflow into a standalone AppKit-based application.

## Current scope

- Global keyboard shortcuts for cycling layouts and applying named layouts
- Layout cycling that follows the current order in the JSON configuration and skips layouts excluded from cycling
- Drag grid activation by middle mouse hold or configured modifier groups plus left mouse
- Trigger regions that can use either the screen grid or a segmented menu bar strip
- Accessibility-based target window lookup, focus, move, resize, and fullscreen exit
- Non-activating overlay for trigger slots and target window preview
- JSON configuration stored at `~/.config/GridMove/config.json`

## Out of scope in this first version

- Space switching
- Mission Control automation
- Cross-Space window movement
- Fullscreen Space management
- Sparkle integration
- Third-party shortcut libraries

## Build

```bash
make build
```

This creates:

- `dist/GridMove.app`
- `dist/GridMove.dmg`

Before packaging, `make build` removes the local runtime configuration at `~/.config/GridMove/config.json` so the packaged app starts from a clean default state.
The packaged app bundle includes a generated app icon derived from the menu bar glyph.

The default signing mode is ad-hoc signing for local testing. To use a real certificate, override `SIGN_IDENTITY`:

```bash
make build SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)"
```

`make build` runs the Swift test suite before packaging. To run tests without packaging, use:

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

The app writes a default JSON configuration to `~/.config/GridMove/config.json` on first launch. The initial values mirror the migrated `~/.hammerspoon` layouts, trigger regions, modifier groups, and shortcut defaults.

If the config file contains invalid JSON or an unsupported shape, GridMove keeps the file unchanged, logs the error, and falls back to the built-in default configuration for the current launch.

You can open the config directory from the menu bar with `Customize` and reload the file from disk with `Reload config`.

The generated file uses plain JSON. Layout objects do not store internal identifiers. Their 1-based position in the `layouts` array is the layout number. Hotkey actions that apply a layout use `action.layout` with that layout number. Stroke colors use `#RRGGBBAA`.

If a manual `Reload config` falls back to the built-in default configuration, GridMove also posts a local system notification.

Example:

```json
{
  "general": {
    "isEnabled": true,
    "excludedBundleIDs": ["com.apple.Spotlight"],
    "excludedWindowTitles": []
  },
  "appearance": {
    "renderTriggerAreas": true,
    "triggerOpacity": 0.2,
    "triggerGap": 2,
    "triggerStrokeColor": "#007AFF33",
    "renderWindowHighlight": true,
    "highlightFillOpacity": 0.08,
    "highlightStrokeWidth": 3,
    "highlightStrokeColor": "#FFFFFFEB"
  },
  "dragTriggers": {
    "middleMouseButtonNumber": 2,
    "enableMiddleMouseDrag": true,
    "enableModifierLeftMouseDrag": true,
    "preferLayoutMode": true,
    "modifierGroups": [["ctrl", "cmd", "shift", "alt"]],
    "activationDelaySeconds": 0.3,
    "activationMoveThreshold": 10
  },
  "hotkeys": {
    "bindings": [
      {
        "isEnabled": true,
        "shortcut": {
          "modifiers": ["ctrl", "cmd", "shift", "alt"],
          "key": "l"
        },
        "action": {
          "kind": "cycleNext"
        }
      },
      {
        "isEnabled": true,
        "shortcut": {
          "modifiers": ["ctrl", "cmd", "shift", "alt"],
          "key": "\\"
        },
        "action": {
          "kind": "applyLayout",
          "layout": 4
        }
      }
    ]
  },
  "layouts": [
    {
      "name": "Center",
      "gridColumns": 12,
      "gridRows": 6,
      "windowSelection": {
        "x": 3,
        "y": 1,
        "w": 6,
        "h": 4
      },
      "triggerRegion": {
        "kind": "screen",
        "gridSelection": {
          "x": 5,
          "y": 2,
          "w": 2,
          "h": 2
        }
      },
      "includeInCycle": true
    },
    {
      "name": "Fill all screen (Menu bar)",
      "gridColumns": 12,
      "gridRows": 6,
      "windowSelection": {
        "x": 0,
        "y": 0,
        "w": 12,
        "h": 6
      },
      "triggerRegion": {
        "kind": "menuBar",
        "menuBarSelection": {
          "x": 1,
          "w": 4
        }
      },
      "includeInCycle": false
    }
  ]
}
```

`hotkeys.bindings[*].action.kind` supports `cycleNext`, `cyclePrevious`, and `applyLayout`.
For `applyLayout`, `action.layout` is the 1-based layout number in the `layouts` array.
`layouts[*].includeInCycle = false` excludes that layout from next/previous cycling.

When a drag trigger becomes active, GridMove starts in either layout selection mode or move-only mode according to `dragTriggers.preferLayoutMode`.
While the trigger stays active, a right click or an Option key tap toggles between the two modes. Move-only mode hides the overlay and only updates window position.

When GridMove is disabled, drag triggers, keyboard shortcuts, and CLI layout actions are all blocked until it is enabled again.
