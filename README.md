# GridMove

GridMove is a native macOS menu bar app for applying window layouts and moving windows with mouse, keyboard, and CLI triggers.

## Features

- Global keyboard shortcuts for cycling layouts and applying layout indexes within the active group
- Drag-triggered layout selection and move-only mode
- Layout groups that can be switched from the menu bar or from layout mode with a Shift tap
- Per-display layout sets with `all`, `main`, single-display, and multi-display targeting
- Trigger regions on the screen grid or menu bar strip
- Accessibility-based window lookup, focus, move, resize, and fullscreen exit
- CLI actions relayed to the running app
- Split JSON configuration stored at `~/.config/GridMove/config.json` and `~/.config/GridMove/layout/*.grid.json`

## Dev

```bash
# test
make test
# run locally
make dev
# build and package
make build
# update VERSION and build a release package
make release v0.1.1
```

The default signing mode is ad-hoc signing for local testing. To use a real certificate, override `SIGN_IDENTITY`:

```bash
make build SIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)"
```

`VERSION` is the single source of truth for the main app version. `make build` keeps `CFBundleShortVersionString` and `CFBundleVersion` at the main version and records `<main-version>+<short-commit>` in the package info string. `make release v0.1.1` updates `VERSION`, then builds a release package whose package info string is just `0.1.1`.

## CLI

GridMove can relay CLI actions to a running app instance:

```bash
path/to/GridMove.app/Contents/MacOS/GridMove -next
path/to/GridMove.app/Contents/MacOS/GridMove -pre
path/to/GridMove.app/Contents/MacOS/GridMove -layout 4
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center"
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center" -window-id 12345
```

If `-window-id <cg-window-id>` is not provided, GridMove targets the currently focused window. 

## Configuration

Config files are stored at:

- `~/.config/GridMove/config.json`
- `~/.config/GridMove/layout/*.grid.json`

On first launch, GridMove writes default files if they do not exist:

- `layout/1.grid.json` for `built-in`
- `layout/2.grid.json` for `fullscreen`

`config.json` stores non-layout settings only. Each `layout/*.grid.json` file stores one layout-group object.
Managed layout filenames must match `<positive-integer>.grid.json`, and GridMove loads them in numeric order.

The example below uses `jsonc` only for explanation. Real files must be plain JSON and do not support comments.

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
    "activeLayoutGroup": "built-in" // The currently selected layout group. Menu-bar changes and layout-mode Shift cycling both update this value.
  },
  "appearance": {
    "renderTriggerAreas": false, // Show trigger-region overlay while in layout mode. The default is off.
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
    "Built-in Retina Display": "69732928" // Filled or refreshed by GridMove on successful reload/startup.
  }
}
```

`layout/1.grid.json`

```jsonc
{
  "name": "built-in",
  "includeInGroupCycle": true, // Missing includeInGroupCycle means this group still participates in Shift-based group cycling while layout mode is active.
  "sets": [
    {
      "monitor": "all", // Allowed values: "all", "main", "<display-id>", ["<display-id>", ...]. Trigger overlays resolve sets by explicit ID or ID array, then main, then all.
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


## Additional docs

- `UI-UX.md`: UI structure, editing patterns, and future interface rules
- `APP-DESIGN.md`: runtime behavior, architecture, configuration details, and implementation notes
