# GridMove

GridMove is a native macOS app for applying window layouts and moving windows across monitors.

A rewrite of my AHK GridMove for Windows.

GridMove requires accessibility permissions.

## Features

- Fast, lightweight, and customizable window management via mouse, keyboard, and CLI triggers
- Move and resize windows across monitors using different layouts
- Per-monitor layout sets, switchable on the fly

## Hotkeys and Behaviors

- Hold <kbd>Middle Mouse Button</kbd> briefly to apply a layout to the window under the cursor.
- Hold <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Alt</kbd>, then left-click and hold to apply a layout to the window under the cursor.
- In layout mode, press <kbd>Option</kbd> or <kbd>Right Click</kbd> to enter free-move mode; click again to return to layout mode.
- In layout mode, press <kbd>Shift</kbd> or scroll the mouse wheel to cycle the active layout group.
- Use the menu bar or preset hotkeys to apply layouts to the currently focused window.
- Use the CLI to apply layouts to any window by ID.

### CLI

GridMove relays CLI actions to a running app instance:

```bash
path/to/GridMove.app/Contents/MacOS/GridMove -next
path/to/GridMove.app/Contents/MacOS/GridMove -pre
path/to/GridMove.app/Contents/MacOS/GridMove -layout 4
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center"
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center" -window-id 12345
```

If `-window-id <cg-window-id>` is omitted, GridMove targets the currently focused window.

## Configuration

Configuration files are stored at:

- `~/.config/GridMove/config.json` — general settings.
- `~/.config/GridMove/layout/<positive-integer>.grid.json` — layout groups and their layouts.

The examples below use `jsonc` for annotation only. Real files must be plain JSON and do not support comments.

`config.json`

```jsonc
{
  "general": {
    "isEnabled": true, // Enable or disable the whole app. If this field is missing, GridMove treats it as true.
    "excludedBundleIDs": [
      "com.apple.Spotlight" // Exact-match app bundle IDs to ignore. Built-in system exclusions still apply.
    ],
    "excludedWindowTitles": [
      // Exact-match window titles to ignore.
    ],
    "mouseButtonNumber": 3, // Mouse button number for the hold-to-drag trigger. 3 is the standard middle button. 4 and 5 commonly map to side buttons. Missing or invalid values fall back to 3.
    "activeLayoutGroup": "built-in" // The currently selected layout group. Menu-bar changes, layout-mode Shift cycling, and layout-mode mouse-wheel cycling all update this value.
  },
  "appearance": {
    "renderTriggerAreas": false, // Show trigger-region overlay while in layout mode. The default is off.
    "triggerOpacity": 0.2, // Fill opacity for trigger regions. Current defaults assume a 0...1 range.
    "triggerGap": 2, // Gap between trigger-region cells, in points.
    "triggerStrokeColor": "#007AFF33", // Border color for trigger regions. Accepts #RRGGBB or #RRGGBBAA.
    "layoutGap": 1, // Integer gap between window layout frames, in points. Shrinks the applied window frame and the overlay highlight by this amount on each side. Missing or invalid values default to 1. If the gap would collapse a layout on the current screen, GridMove skips that layout on that screen.
    "renderWindowHighlight": true, // Show the current window highlight overlay.
    "highlightFillOpacity": 0.08, // Fill opacity for the window highlight. Current defaults assume a 0...1 range.
    "highlightStrokeWidth": 3, // Border width for the window highlight, in points.
    "highlightStrokeColor": "#FFFFFFEB" // Border color for the window highlight. Accepts #RRGGBB or #RRGGBBAA.
  },
  "dragTriggers": {
    "enableMouseButtonDrag": true, // Enable the mouse-button hold trigger path.
    "enableModifierLeftMouseDrag": true, // Enable the modifier-plus-left-click trigger path.
    "preferLayoutMode": true, // true: start drag interaction in layout mode. false: start in move-only mode.
    "modifierGroups": [
      ["ctrl", "cmd", "shift", "alt"], // Allowed modifier names are ctrl, cmd, shift, alt. Matching is exact by group.
      ["ctrl", "shift", "alt"]
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
          "kind": "applyLayoutByIndex", // Allowed values are applyLayoutByIndex, cycleNext, cyclePrevious.
          "layout": 4 // Required only for applyLayoutByIndex. This is a 1-based index within the active layout group's indexed layouts. CLI -layout <number> uses the same numbering, and GridMove only requires this value to be a positive integer.
        }
      }
      // The default file contains more bindings in the same shape.
    ]
  },
  "monitors": {
    "610-41535-0": "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4" // Filled or refreshed by GridMove on successful reload/startup. Key is vendor-model-serial; value is the preferred runtime ID for that display: UUID when Quartz provides one, otherwise the same vendor-model-serial string.
  }
}
```

`layout/1.grid.json`

```jsonc
{
  "name": "built-in",
  "includeInGroupCycle": true, // Missing includeInGroupCycle means this group still participates in layout-mode group cycling, including Shift taps and mouse-wheel scrolling.
  "sets": [
    {
      "monitor": "all", // Allowed values: "all", "main", "<display-id>", ["<display-id>", ...]. Explicit display IDs may use either a display UUID or a vendor-model-serial fingerprint from monitors. Trigger overlays resolve sets by explicit ID or ID array, then main, then all.
      "layouts": [
        {
          "name": "Center", // CLI -layout "<name>" looks up this value inside the active layout group.
          "gridColumns": 12,
          "gridRows": 6,
          "windowSelection": {
            "x": 3,
            "y": 1,
            "w": 6,
            "h": 4
          },
          "triggerRegion": {
            "kind": "screen", // Allowed values are screen and menuBar.
            "gridSelection": {
              "x": 5,
              "y": 2,
              "w": 2,
              "h": 2
            }
            // If kind is menuBar, use:
            // "menuBarSelection": { "x": 1, "w": 4 }
          },
          "includeInLayoutIndex": true, // false excludes the layout from layout-index shortcuts and from cycle order, but CLI -layout "<name>" can still resolve the layout.
          "includeInMenu": true // false hides the layout from the menu bar only.
        },
        {
          "name": "Centered no trigger",
          "gridColumns": 12,
          "gridRows": 6,
          "windowSelection": {
            "x": 3,
            "y": 1,
            "w": 6,
            "h": 4
          },
          "includeInLayoutIndex": false,
          "includeInMenu": false // Missing triggerRegion means drag trigger is unavailable; menu-hidden layouts remain available to CLI, and to layout-index shortcuts only when includeInLayoutIndex is true.
        }
      ]
    }
  ]
}
```

## Development

```bash
# run tests
make test
# run locally
make dev
# build and package
make build
# build a release package for the current VERSION
make release

# update VERSION, create a release commit and tag, and build a release package
make release v0.1.1
```

The default signing mode is ad-hoc for local testing. To use a real certificate, override `SIGN_IDENTITY`:

```bash
make build SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)"
```

## Additional Docs

- [UI-UX.md](UI-UX.md) — UI structure, editing patterns, and future interface rules
- [APP-DESIGN.md](APP-DESIGN.md) — runtime behavior, architecture, configuration details, and implementation notes
