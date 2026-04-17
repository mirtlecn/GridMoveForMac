# GridMove

GridMove is a native macOS menu bar app for applying window layouts and moving windows with mouse, keyboard, and CLI triggers.

## Features

- Global keyboard shortcuts for cycling layouts and applying layout indexes within the active group
- Drag-triggered layout selection and move-only mode
- Layout groups that can be switched from the menu bar
- Per-display layout sets with `all`, `main`, single-display, and multi-display targeting
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

Config file location is `~/.config/GridMove/config.json`.

On first launch, GridMove writes a default file to that path if it does not exist.
The built-in default file contains two groups: `built-in` and `fullscreen`.

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
    ],
    "activeLayoutGroup": "built-in" // The menu-bar-selected layout group.
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
          "layout": 4 // Required only for applyLayoutByIndex. This is a 1-based index within the active layout group's indexed layouts.
        }
      }
      // The default file contains more bindings in the same shape.
    ]
  },
  "layoutGroups": [
    {
      "name": "built-in",
      "includeInGroupCycle": true, // Missing includeInGroupCycle means this group still participates in Shift-based group cycling.
      "sets": [
        {
          "monitor": "all", // Allowed values: "all", "main", "<display-id>", ["<display-id>", ...]
          "layouts": [
            {
              "name": "Center", // CLI name lookup uses this value inside the active layout group.
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
              "includeInLayoutIndex": true,
              "includeInMenu": true // Missing includeInMenu means the layout still appears in the menu bar.
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
              "includeInLayoutIndex": false, // Excluded from layout-index shortcuts and from cycle order.
              "includeInMenu": false // Missing triggerRegion means trigger is unavailable; menu visibility is controlled separately.
            }
          ]
        }
      ]
    }
  ],
  "monitors": {
    "Built-in Retina Display": "69732928" // Filled or refreshed by GridMove on successful reload/startup.
  }
}
```

Notes:

- `layoutGroups[*].sets[*].layouts` order matters.
- `layoutGroups[*].includeInGroupCycle` controls whether layout-mode Shift cycling can switch to that group.
- the built-in default file includes `built-in` and `fullscreen`; startup keeps `built-in` active until the user switches the group
- `hotkeys.bindings[*].action.layout` is a 1-based index within the active layout group's indexed layouts.
- CLI `-layout <number>` uses the same 1-based index within the active layout group's indexed layouts.
- CLI `-layout "<name>"` matches a layout name inside the active layout group.
- if more than one layout in the active group shares the same name, CLI name lookup fails and reports the conflicting layout indexes.
- layouts with `includeInLayoutIndex = false` are excluded from layout-index shortcuts and from layout cycling.
- GridMove resolves one active set per display in this order: explicit display ID or ID array, then `main`, then `all`.
- if trigger regions overlap on one display, the later declared layout wins.
- `cycleNext` and `cyclePrevious` only cycle inside the target window's current display set. They never move the window to another display.
- Menu and CLI direct layout application may move the target window to another display if the matched layout belongs to another set.
- `includeInMenu` controls only menu-bar visibility.
- layouts hidden from the menu can still be used by trigger and CLI paths, and can still be reached by layout-index shortcuts only when `includeInLayoutIndex = true`.
- while a drag interaction is in layout mode, pressing and releasing `Shift` alone switches to the next group whose `includeInGroupCycle` is `true`, saves that group as `general.activeLayoutGroup`, refreshes the active trigger set immediately, and returns to the pre-threshold highlight state until the pointer moves far enough again.
- Internal layout IDs and binding IDs are not stored in `config.json`. GridMove regenerates them when loading.
- If the file is invalid JSON, contains comments, or references a missing layout index, GridMove falls back to built-in defaults for the current launch and keeps the broken file unchanged.


## Additional docs

- `UI-UX.md`: UI structure, editing patterns, and future interface rules
- `APP-DESIGN.md`: runtime behavior, architecture, configuration details, and implementation notes
