English | [中文](./README.zh-CN.md)

# GridMove for macOS

GridMove is a native macOS app for moving windows across monitors and snapping them into preset layouts.

Get arm64 installer: [🔗](https://github.com/mirtlecn/GridMoveForMac/releases/latest/download/GridMove.arm64.dmg)

> [!NOTE]
> The app is unsigned, you need to trust it in System Preferences > Privacy & Security on first launch.

## Demo

Move windows by dragging from anywhere inside them.

https://github.com/user-attachments/assets/9f1a4fec-e022-4667-96c6-9ee199e15887

Drag windows into preset spots to instantly resize and position them.

https://github.com/user-attachments/assets/0373bb1d-1de4-4542-a67e-b6598859bfd1

## Features

- Super fast and lightweight
- Trigger actions with mouse, keyboard, or CLI
- Move and resize windows across monitors
- Snap windows into any layout you want
- Use different layout sets for each monitor
- Switch layout group on the fly

## Quick Start

- Hold <kbd>Middle Mouse Button</kbd> briefly to apply a layout to the window under the cursor.
- Hold <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>Alt</kbd>, then left-click and hold to apply a layout to the window under the cursor.
- In layout mode, press <kbd>Option</kbd> or <kbd>Right Click</kbd> to enter free-move mode; click again to return to layout mode.
- In layout mode, press <kbd>Shift</kbd> or scroll the mouse wheel to cycle the active layout group.
- Use the menu bar or preset hotkeys to apply layouts to the currently focused window.
- Use the CLI to apply layouts to any window by ID.

## Screenshots

Settings

<img width="1070" height="860" alt="image" src="https://github.com/user-attachments/assets/322b6636-9bac-4d9b-8690-427fda6f2f1d" />

Custom layouts:

<img width="1070" height="811" alt="image" src="https://github.com/user-attachments/assets/18528949-58d3-40ec-a126-3e13a6d6beaf" />


### CLI

GridMove relays CLI actions to a running app instance.

```bash
path/to/GridMove.app/Contents/MacOS/GridMove -next # move focus window
path/to/GridMove.app/Contents/MacOS/GridMove -pre
path/to/GridMove.app/Contents/MacOS/GridMove -layout 4
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center" 
path/to/GridMove.app/Contents/MacOS/GridMove -layout "Center" -window-id 12345 # move specific window in current monitor
```

## Development

```bash
# run tests
make test
# run locally
make dev
# build and package
make build
# build a release package
make release
```

## Additional Notes

- GridMove takes its name from a [Windows AHK app](https://github.com/mirtlecn/GridMove) I previously maintained. This project is essentially its macOS counterpart.
- The entire app—including the icon, documentation, and demo video—was built with OpenAI Codex. The user prompts are available [here](docs/prompts.md). (Note: the file is 700 KB+.)
- [docs/APP-DESIGN.md](docs/APP-DESIGN.md) — runtime behavior, architecture, configuration details, and implementation notes
- [docs/CONFIG-REFERENCE.jsonc](docs/CONFIG-REFERENCE.jsonc) — Advanced JSON configuration reference
