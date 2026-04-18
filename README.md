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

- [docs/UI.md](docs/UI.md) — UI structure, editing patterns, and interface rules
- [docs/SETTINGS-UI.md](docs/SETTINGS-UI.md) — accepted settings-window baseline, entry points, and model-integration rules
- [docs/APP-DESIGN.md](docs/APP-DESIGN.md) — runtime behavior, architecture, configuration details, and implementation notes
- [docs/CONFIG-REFERENCE.jsonc](docs/CONFIG-REFERENCE.jsonc) — annotated JSON configuration reference
