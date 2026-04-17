# GridMove

GridMove is a native macOS menu bar app for applying window layouts and moving windows with mouse, keyboard, and CLI triggers.

## Features

- Global keyboard shortcuts for cycling layouts and applying named layouts
- Drag-triggered layout selection and move-only mode
- Trigger regions on the screen grid or menu bar strip
- Accessibility-based window lookup, focus, move, resize, and fullscreen exit
- CLI actions relayed to the running app
- JSON configuration stored at `~/.config/GridMove/config.json`

## Dev

```bash
# test
make test
# run locally
make dev
# build and package
make build
```

The default signing mode is ad-hoc signing for local testing. To use a real certificate, override `SIGN_IDENTITY`:

```bash
make build SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)"
```

## CLI

GridMove can relay CLI actions to a running app instance:

```bash
path/to/GridMove.app/Contents/MacOS/GridMove -next
path/to/GridMove.app/Contents/MacOS/GridMove -pre
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center"
path/to/GridMove.app/Contents/MacOS/GridMove -layout layout-4
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center" -window-id 12345
```

If `-window-id <cg-window-id>` is not provided, GridMove targets the currently focused window. 

## Configuration

Config file location is `~/.config/GridMove/config.json`.

On first launch, GridMove writes a default file to that path if it does not exist.

The real file must be plain JSON and does not support comments. The example below uses `jsonc` only for explanation.

```jsonc
{
  "general": {
    "isEnabled": true, // Enable or disable the whole app. If this field is missing, GridMove treats it as true.
    "excludedBundleIDs": [
      "com.apple.Spotlight" // Exact-match app bundle IDs to ignore. Built-in system exclusions still apply.
    ],
    "excludedWindowTitles": [
      // Exact-match window titles to ignore.
    ]
  },
  "appearance": {
    "renderTriggerAreas": true, // Show trigger-region overlay while in layout mode.
    "triggerOpacity": 0.2, // Fill opacity for trigger regions. Current defaults assume a 0...1 range.
    "triggerGap": 2, // Gap between trigger-region cells, in points.
    "triggerStrokeColor": "#007AFF33", // Border color for trigger regions. Accepts #RRGGBB or #RRGGBBAA.
    "renderWindowHighlight": true, // Show the current window highlight overlay.
    "highlightFillOpacity": 0.08, // Fill opacity for the window highlight. Current defaults assume a 0...1 range.
    "highlightStrokeWidth": 3, // Border width for the window highlight, in points.
    "highlightStrokeColor": "#FFFFFFEB" // Border color for the window highlight. Accepts #RRGGBB or #RRGGBBAA.
  },
  "dragTriggers": {
    "middleMouseButtonNumber": 2, // Mouse button number used for the middle-button trigger. 2 is the standard middle button.
    "enableMiddleMouseDrag": true, // Enable the middle-mouse trigger path.
    "enableModifierLeftMouseDrag": true, // Enable the modifier-plus-left-click trigger path.
    "preferLayoutMode": true, // true: start drag interaction in layout mode. false: start in move-only mode.
    "modifierGroups": [
      ["ctrl", "cmd", "shift", "alt"] // Allowed modifier names are ctrl, cmd, shift, alt. Matching is exact by group.
    ],
    "activationDelaySeconds": 0.3, // Hold time before drag interaction becomes active.
    "activationMoveThreshold": 10 // Pointer movement threshold, in points, before the interaction counts as a drag.
  },
  "hotkeys": {
    "bindings": [
      {
        "isEnabled": true, // Enable or disable this shortcut binding.
        "shortcut": {
          "modifiers": ["ctrl", "cmd", "shift", "alt"], // Allowed values are ctrl, cmd, shift, alt.
          "key": "\\" // Supported keys: a-z, -, =, [, ], \, ;, ', ,, ., /, return, enter, escape, esc.
        },
        "action": {
          "kind": "applyLayout", // Allowed values are applyLayout, cycleNext, cyclePrevious.
          "layout": 4 // Required only for applyLayout. This is a 1-based index into the layouts array.
        }
      }
      // The default file contains more bindings in the same shape.
    ]
  },
  "layouts": [
    {
      "name": "Center", // Name shown in the menu bar. CLI can also look up layouts by this name.
      "gridColumns": 12, // Column count of the layout grid.
      "gridRows": 6, // Row count of the layout grid.
      "windowSelection": {
        "x": 3, // Target window origin column inside the grid.
        "y": 1, // Target window origin row inside the grid.
        "w": 6, // Target window width in grid cells.
        "h": 4 // Target window height in grid cells.
      },
      "triggerRegion": {
        "kind": "screen", // Allowed values are screen and menuBar.
        "gridSelection": {
          "x": 5, // Trigger origin column for screen mode.
          "y": 2, // Trigger origin row for screen mode.
          "w": 2, // Trigger width in cells for screen mode.
          "h": 2 // Trigger height in cells for screen mode.
        }
        // If kind is menuBar, use:
        // "menuBarSelection": { "x": 1, "w": 4 }
        // x is the start cell in the menu bar strip, w is the width in cells.
      },
      "includeInCycle": true // Whether this layout participates in next/previous layout cycling.
    }
    // The default file contains more layouts in the same shape.
  ]
}
```

Notes:

- `layouts` order matters. `layout-1`, `layout-2`, and other generated layout identifiers come from this order.
- `hotkeys.bindings[*].action.layout` is also based on this order and starts from `1`, not `0`.
- Internal layout IDs and binding IDs are not stored in `config.json`. GridMove regenerates them when loading.
- If the file is invalid JSON, contains comments, or references a missing layout index, GridMove falls back to built-in defaults for the current launch and keeps the broken file unchanged.


## Additional docs

- `UI-UX.md`: UI structure, editing patterns, and future interface rules
- `APP-DESIGN.md`: runtime behavior, architecture, configuration details, and implementation notes
