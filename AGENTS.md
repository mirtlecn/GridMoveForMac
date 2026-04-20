# GridMove Agent Rules

Short orientation for agents working in this repository.

## Overview

- This is a Swift macOS menu bar app with an AppKit Settings window. You need a macOS system to run and test it.
- It also has CLI relay, and JSON-based persistence under `~/.config/GridMove/`.

## Docs

Check these files before changing behavior:

1. `README.md`
2. `docs/*.md`
3. `docs/CONFIG-REFERENCE.jsonc`, it's visible settings reference for the config file.

## Runtime Entry Points

- `Sources/GridMove/App/GridMoveApp.swift`
  - Process entry. CLI arguments are handled before `AppDelegate` exists.
- `Sources/GridMove/App/AppDelegate.swift`
  - Main runtime coordinator for config, menu bar state, drag runtime, shortcuts, CLI relay, and Settings.
- `Sources/GridMove/App/LayoutActionExecutor.swift`
  - Shared direct-apply path for menu actions, hotkeys, and CLI.
- `Sources/GridMove/CLI/CommandLineRunner.swift`
  - CLI side of the relay. The CLI talks to the running app instead of applying layouts by itself.

## Settings Entry Points

- `Sources/GridMove/App/Settings/SettingsWindowController.swift`
  - Settings window shell, close behavior, and background-click edit commit behavior.
- `Sources/GridMove/App/Settings/SettingsPrototypeState.swift`
  - Shared draft boundary between UI and persistence. Keep this layer.
- Tab controllers: `GeneralSettingsViewController.swift`, `LayoutsSettingsViewController.swift`, `AppearanceSettingsViewController.swift`, `HotkeysSettingsViewController.swift`, `AboutSettingsViewController.swift`

Save behavior:

- `General`, `Appearance`, `Hotkeys`, and `About` apply immediately.
- `Layouts` is save-only. Unsaved draft changes are discarded when the Settings window closes.

## Configuration and Text

- `Sources/GridMove/Configuration/ConfigurationStore.swift`
  - Loads and saves `~/.config/GridMove/config.json` and `~/.config/GridMove/layout/*.grid.json`.
- `Sources/GridMove/Configuration/DefaultConfiguration.swift`
  - Canonical source for built-in defaults.
- `Sources/GridMove/Support/UICopy.swift`
  - Source of truth for visible strings.
- `Sources/GridMove/Resources/en.lproj/Localizable.strings`
- `Sources/GridMove/Resources/zh-Hans.lproj/Localizable.strings`

When changing visible text or behavior:

- Update `UICopy.swift` and both localization files together.
- Add or update a direct localization test.
- Keep `docs/UI.md` and `docs/APP-DESIGN.md` in sync when behavior changes.

## Hotkeys and Dragging

- `Sources/GridMove/Shortcut/ShortcutKeyMap.swift`
  - Central normalization layer for key names, aliases, keypad handling, and display names.
- `dragTriggers` is the config boundary for drag behavior.
- `applyLayoutImmediatelyWhileDragging` only affects drag preview and drag finalization. It does not affect menu, CLI, or hotkey actions.

## Build and Test

- `make test`: runs `swift test --no-parallel`
- `make dev`: runs the app locally
- `make build`: builds and packages the app into `dist/`
- `make release`: builds a release package using the current `VERSION`
- `make release vX.Y.Z`: updates `VERSION`, creates the release commit and tag, then builds the release package

## Project Rules
- Update test and documentation together with any behavior or text change.
- Use the **Conventional Commits** specification for commit messages.
- Keep SwiftPM runs serial in this repo. Overlapping `swift test` or related SwiftPM commands can conflict on `.build`.
- Do not move GUI reopen behavior into the CLI path. `GridMoveApp.main()` handles CLI before the app delegate exists.
- `LayoutActionExecutor` is shared by menu, hotkeys, and CLI. Routing bugs there affect all three.
- Empty modifier groups must stay inert. They must not behave like plain left click.
- Settings-wide edit commit behavior belongs in `SettingsWindowController`, not in per-control hacks.
- For shared inline-tab spacing, change the shared layout metric before patching each page separately.
- Local packaging signs ad hoc by default because `SIGN_IDENTITY ?= -`. If you are debugging Accessibility or TCC issues, inspect the installed app, not only the source tree.
