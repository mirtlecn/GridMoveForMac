# GridMove Settings UI Integration Notes

This document records the accepted settings-window baseline and the current real model integration rules.

It is intentionally narrower than `APP-DESIGN.md` and less abstract than `UI.md`.

- `APP-DESIGN.md`: program behavior, lifecycle, configuration flow
- `UI.md`: interaction structure and grouped control relationships
- `SETTINGS-UI.md`: current accepted UI baseline, code entry points, and model-integration guidance

## Status

The current settings window is the accepted AppKit baseline and is already connected to the real configuration model.

Current save rules:

- `General`, `Appearance`, and `Hotkeys` apply immediately and save through the shared action handler
- `Layouts` keeps a shared draft and only applies when the user clicks `Save`
- `About` can reload configuration and restore the built-in defaults

UI review constraints remain unchanged:

- keep the current visual style
- keep the current interaction structure
- do not redesign layout, spacing, or control hierarchy unless explicitly requested
- prefer replacing internals under the existing UI surface

## Hard Constraints

The following were explicitly confirmed during the prototype phase:

- Use AppKit, not a SwiftUI app rewrite.
- Keep the current title-bar tab style.
- Keep the current content-area styling and spacing language.
- Do not turn the settings window into a different shell while wiring the model.
- Do not bind controls directly to persistent configuration from many places.
- Preserve one shared draft layer between UI and persistence.
- `Layouts` is special:
  - changes in `Layouts` are not immediate
  - `Layouts` changes should only apply when the user clicks `Save`
- Other tabs are expected to be immediate once real wiring starts, unless a later decision changes that.

## Source of Truth for Visible Text

Visible strings should stay aligned with:

- `Sources/GridMove/Support/UICopy.swift`

Do not introduce new inline strings in controllers unless they are temporary placeholders that will immediately be moved into `UICopy`.

## Current Settings UI File Map

### Window shell

- `Sources/GridMove/App/Settings/SettingsWindowController.swift`

Contains:

- settings window creation
- tab setup
- per-tab window sizing
- animated window resizing when switching tabs

### Shared settings draft state

- `Sources/GridMove/App/Settings/SettingsPrototypeState.swift`

This is the shared UI draft object.

Current purpose:

- hold the current settings draft
- hold the committed configuration snapshot
- let multiple tabs read and write one shared mutable draft
- separate immediate-save tabs from `Layouts`

Do not delete this layer. It is the UI-side draft boundary for the current settings window.

### Tab controllers

- `GeneralSettingsViewController.swift`
- `LayoutsSettingsViewController.swift`
- `AppearanceSettingsViewController.swift`
- `HotkeysSettingsViewController.swift`
- `AboutSettingsViewController.swift`

### Shared view / support code

- `SettingsViewComponents.swift`
- `SettingsInlineTabsView.swift`
- `SettingsSelectableListControlView.swift`
- `SettingsPreviewSupport.swift`
- `AppearancePreviewView.swift`
- `LayoutPreviewView.swift`
- `LayoutsSettingsSupport.swift`
- `SettingsPrototypeSheetController.swift`
- `SettingsPrototypeInputSheets.swift`

## Per-Tab Behavior Baseline

### General

Current sections:

- runtime rows without a visible section title
- drag behavior
- exclusions

Confirmed interactions:

- `Modifier groups`
  - list items are selectable
  - `Add...` opens a sheet
  - user chooses one or more modifiers from Control / Shift / Option / Command
  - empty selection is not allowed
  - duplicate groups are not added twice
- `Excluded bundle IDs` and `Excluded window titles`
  - list items are selectable
  - one shared `Add...` / `Remove` row
  - `Add...` opens one sheet that can add either exclusion kind

Current model behavior:

- this tab writes through the shared draft
- changes apply immediately through the shared action handler

### Layouts

Current structure:

- left outline tree
- right detail panel
- bottom command row aligned with the large two-column area

Left tree hierarchy:

- group
- display set
- layout

Confirmed behavior:

- layout rows can be drag-reordered inside the same display set
- drag starts only from index + icon area, not from the name text
- active group is visually distinguished in the tree
- double-clicking a group row activates that group
- group, display set, and layout each have distinct semantic icons

Right detail behavior:

- selecting `group` shows:
  - `Name`
  - `Include in group cycle`
- selecting `display set` shows:
  - `Apply to`
  - values: `All monitor`, `Main monitor`, `Custom monitors`
  - `Custom monitors` reveals monitor multi-select UI
  - a small refresh button exists next to `Apply to`
- selecting `layout` shows:
  - preview
  - inline tabs: `Layout`, `Window area`, `Trigger area`
  - `Save` and `Remove` are outside the panel, in the bottom command row

Current save rule:

- this tab is draft-only until `Save`
- no other tab shares this deferred-save rule
- switching to another tab keeps the current `Layouts` draft
- closing the settings window discards any unsaved `Layouts` draft

Important semantic rule:

- the real model is a single active group name
- the UI activates a group by double-clicking a group row in the left tree
- when one group becomes active, others become inactive
- protected groups (`protect = true`) cannot be removed in UI
- protected groups keep their names read-only in UI
- empty groups and empty monitor sets are allowed and remain inert at runtime

### Appearance

Current structure:

- top preview
- inline tabs inside a light system panel:
  - `Window area`
  - `Trigger area`

Current control shape is intentional:

- `Highlight ...` rows are aligned like other rows
- numeric fields use integer steppers with unit labels
- the window fill opacity control is a slider
- the slider updates preview immediately and only saves when the drag ends

Current model expectations:

- `highlightFillOpacity` remains `Double`
- `triggerGap`, `layoutGap`, and `highlightStrokeWidth` are integer-based

Preview rules:

- `AppearancePreviewView` respects the render toggles
- `LayoutPreviewView` must always show window / trigger overlays for editing convenience
- both previews should use the same appearance-derived rendering helpers

Current shared draw helpers:

- `SettingsPreviewSupport.drawWindowHighlight(...)`
- `SettingsPreviewSupport.drawTriggerRegion(...)`

Known limitation:

- trigger stroke width is still fixed in preview and runtime because there is no separate appearance field for it
- trigger rendering is stroke-only; there is no trigger fill opacity field in the current model

### Hotkeys

Current organization:

- one scrollable table
- columns:
  - `Slot`
  - `Current target`
  - `Bindings`
- bottom-right buttons:
  - `Add...`
  - `Clear`

Confirmed semantics:

- `Clear` means clear all bindings for the selected action
- it is not per-binding delete

Action naming baseline:

- cycle actions:
  - `Apply previous layout`
  - `Apply next layout`
- indexed layout actions:
  - `Apply layout 1`
  - `Apply layout 2`
  - ...

Target naming baseline:

- use the active group’s current indexed layout names
- use the same name fallback rule as the menu:
  - if name is empty, fall back to the slot identifier

Important display rule:

- hotkey slots are shown up to the maximum indexed-layout count across all groups
- do not hide higher indices just because the current active group has fewer indexed layouts

Current prototype recorder:

- `Add...` sheet has:
  - `Behavior`
  - shortcut recording
- no default shortcut value should be prefilled
- recording has an intermediate state:
  - field shows `Press shortcut`
  - old shortcut is not shown while recording

Current model behavior:

- the editor writes real `ShortcutBinding` values
- changes apply immediately through the shared action handler
- bindings still preserve typed `HotkeyAction` and `KeyboardShortcut`
- conflict diagnostics are still a later improvement

### About

Current content:

- `Version`
- `Author`
- `Config folder`
- `Advanced`
  - `Reload`
  - `Restore settings`

Current behavior:

- `Author` opens the GitHub profile
- `Config folder` opens the configuration directory from inside Settings
- `Reload` reuses the current reload path
- `Restore settings` restores the built-in default configuration and reloads all tabs

## Preview Integration Rules

When wiring the real model, preserve these rules:

- preview geometry should continue to use:
  - current layout grid values
  - current appearance values
- do not reintroduce hardcoded preview-only boosts such as:
  - extra opacity offsets
  - minimum stroke clamps
- `Appearance` preview:
  - hide overlays when the corresponding render toggle is off
- `Layouts` preview:
  - still show them even when render toggles are off
  - because the user needs to edit layout and trigger positions

## Current Integration Rules

### Keep one UI draft object

`SettingsPrototypeState` remains the UI-facing draft boundary.

### Keep controllers thin

Tab controllers should:

- read from the shared draft
- write to the shared draft
- not call persistence directly

### Centralize apply and save

- `General`, `Appearance`, and `Hotkeys`
  - apply immediately through one coordinator-owned path
- `Layouts`
  - mutate only the layout draft
  - apply and persist only on `Save`

### Preserve typed values in sheets

Sheets should return typed values instead of display strings.

Examples:

- modifier groups return `[ModifierKey]`
- hotkey recorder returns `KeyboardShortcut`
- hotkey action picker returns `HotkeyAction`
- exclusion sheet returns a typed exclusion request

## Monitor Naming and Display-Set Rules

Current accepted naming:

- `All monitor`
- `Main monitor`
- custom monitor names

For custom monitor names:

- use monitor names, not raw IDs
- if multiple names are shown in one compact title, separate with `; `

Current source of truth:

- persisted monitor metadata is used first
- refresh behavior repopulates through an explicit refresh action
- the UI must not write an empty explicit monitor list

## Tests to Keep Running During Integration

Minimum targeted tests:

- `swift test --filter appDelegateShowsSettingsPrototypeWithTwoTabs`
- `swift test --filter settingsWindowUsesPerTabWindowMetrics`
- `swift test --filter LayoutsSettingsViewControllerTests`
- `swift test --filter SettingsPrototypeStateTests`
- `swift test --filter AppDelegateTests`
- `swift test --filter HotkeysSettingsViewControllerTests`

Before reporting:

- `make test`

## Style Guardrails for the Next Session

Do not change these without a new UI review:

- tab structure
- section grouping
- content-area spacing language
- list / preview / detail layout in `Layouts`
- inline tab container styling
- current button placement logic
- icon choices in the `Layouts` tree
- current wording system in `UICopy`

In short:

- replace data flow first
- replace prototype handlers second
- change visuals only if a new review explicitly asks for it
