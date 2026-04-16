# GridMove

GridMove is a native macOS menu bar app that migrates the current Hammerspoon window layout and drag grid workflow into a standalone AppKit-based application.

## Current scope

- Global keyboard shortcuts for cycling layouts and applying named layouts
- Layout cycling that follows the current order in the JSON configuration and skips layouts excluded from cycling
- Drag grid activation by middle mouse hold or configured modifier groups plus left mouse
- Trigger regions that can use either the screen grid or a segmented menu bar strip
- Accessibility-based target window lookup, focus, resize, and fullscreen exit
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

The compiled executable also supports direct command line actions:

```bash
.build/release/GridMove -next
.build/release/GridMove -pre
.build/release/GridMove -layout "Center"
.build/release/GridMove -layout layout-4
.build/release/GridMove -layout "Center" -window-id 12345
.build/release/GridMove -help
```

The `-layout` argument accepts either the layout name or the layout identifier. If `-window-id <cg-window-id>` is provided, GridMove targets that exact on-screen window. Otherwise CLI actions operate on the currently focused window only.
If multiple layouts share the same name, use the layout identifier instead. Ambiguous layout names are rejected.

## Configuration

The app writes a default JSON configuration to `~/.config/GridMove/config.json` on first launch. The initial values mirror the migrated `~/.hammerspoon` layouts, trigger regions, modifier groups, and shortcut defaults.

If the config file contains invalid JSON or an unsupported shape, GridMove keeps the file unchanged, logs the error, and falls back to the built-in default configuration for the current launch.

You can open the config directory from the menu bar with `Customize` and reload the file from disk with `Reload config`.

Example:

```json
{
  "appearance": {
    "highlightFillOpacity": 0.08,
    "highlightStrokeColor": {
      "alpha": 0.92,
      "blue": 1,
      "green": 1,
      "red": 1
    },
    "highlightStrokeWidth": 3,
    "renderTriggerAreas": true,
    "renderWindowHighlight": true,
    "triggerGap": 2,
    "triggerOpacity": 0.2,
    "triggerStrokeColor": {
      "alpha": 0.2,
      "blue": 1,
      "green": 0.48,
      "red": 0
    }
  },
  "dragTriggers": {
    "activationDelaySeconds": 0.3,
    "activationMoveThreshold": 10,
    "enableMiddleMouseDrag": true,
    "enableModifierLeftMouseDrag": true,
    "middleMouseButtonNumber": 2,
    "modifierGroups": [
      ["ctrl", "cmd", "shift", "alt"]
    ]
  },
  "general": {
    "excludedBundleIDs": [
      "com.apple.Spotlight"
    ],
    "excludedWindowTitles": [],
    "isEnabled": true
  },
  "hotkeys": {
    "bindings": [
      {
        "action": {
          "kind": "cycleNext"
        },
        "id": "CYCLE-NEXT-EXAMPLE",
        "isEnabled": true,
        "shortcut": {
          "key": "l",
          "modifiers": ["ctrl", "cmd", "shift", "alt"]
        }
      },
      {
        "action": {
          "kind": "applyLayout",
          "layoutID": "layout-4"
        },
        "id": "CENTER-EXAMPLE",
        "isEnabled": true,
        "shortcut": {
          "key": "\\",
          "modifiers": ["ctrl", "cmd", "shift", "alt"]
        }
      }
    ]
  },
  "layouts": [
    {
      "gridColumns": 12,
      "gridRows": 6,
      "id": "layout-4",
      "includeInCycle": true,
      "name": "Center",
      "triggerRegion": {
        "gridSelection": {
          "h": 2,
          "w": 2,
          "x": 5,
          "y": 2
        },
        "kind": "screen"
      },
      "windowSelection": {
        "h": 4,
        "w": 6,
        "x": 3,
        "y": 1
      }
    },
    {
      "gridColumns": 12,
      "gridRows": 6,
      "id": "layout-11",
      "includeInCycle": false,
      "name": "Fill all screen (Menu bar)",
      "triggerRegion": {
        "kind": "menuBar",
        "menuBarSelection": {
          "w": 4,
          "x": 1
        }
      },
      "windowSelection": {
        "h": 6,
        "w": 12,
        "x": 0,
        "y": 0
      }
    }
  ]
}
```

When GridMove is disabled, drag triggers, keyboard shortcuts, and CLI layout actions are all blocked until it is enabled again.
