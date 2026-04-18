# GridMove Settings UI Integration Notes

This document is the handoff note for wiring the current settings-window prototype to the real configuration model.

It is intentionally narrower than `APP-DESIGN.md` and less abstract than `UI-UX.md`.

- `APP-DESIGN.md`: program behavior, lifecycle, configuration flow
- `UI-UX.md`: interaction structure and grouped control relationships
- `UI-Info.md`: current accepted UI baseline, code entry points, and model-integration guidance

## Status

The current settings window is a reviewed static / prototype UI baseline.

When starting model integration:

- keep the current visual style
- keep the current interaction structure
- do not redesign layout, spacing, or control hierarchy unless explicitly requested
- prefer replacing prototype state and handlers under the existing UI surface

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

### Shared prototype state

- `Sources/GridMove/App/Settings/SettingsPrototypeState.swift`

This is the current shared UI draft object.

Current purpose:

- hold one mutable `AppConfiguration`
- let multiple tabs read and write the same temporary draft

Future purpose:

- remain the UI-side draft boundary
- accept a real configuration snapshot when opening settings
- support save / apply flows without forcing every tab to talk to persistence directly

Do not delete this layer when wiring the model. Replace its internals and ownership, but keep the role.

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

Model wiring expectation:

- this tab should later write through the shared draft and apply immediately

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
- group, display set, and layout each have distinct semantic icons

Right detail behavior:

- selecting `group` shows:
  - `Name`
  - `Include in group cycle`
  - `Active group`
- selecting `display set` shows:
  - `Apply to`
  - values: `All monitor`, `Main monitor`, `Custom monitors`
  - `Custom monitors` reveals monitor multi-select UI
  - a small refresh button exists next to `Apply to`
- selecting `layout` shows:
  - preview
  - inline tabs: `General`, `Window`, `Trigger`
  - `Save` and `Remove` are outside the panel, in the bottom command row

Special save rule:

- this tab is draft-only until `Save`
- no other tab shares this deferred-save rule

Important semantic rule:

- `Active group` is a boolean-looking control in UI
- but the real model is a single active group name
- later wiring must keep this exclusive:
  - when one group becomes active, others become inactive

### Appearance

Current structure:

- top preview
- inline tabs inside a light system panel:
  - `Window highlight`
  - `Trigger overlay`

Current control shape is intentional:

- `Show ...` rows are aligned like other rows
- numeric fields use integer steppers with unit labels
- opacity controls are sliders

Current model expectations:

- `triggerOpacity` and `highlightFillOpacity` remain `Double`
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

Future wiring requirement:

- replace the prototype append logic with a real binding editor flow
- preserve typed action + shortcut structure
- preserve enabled state and ordering
- add conflict diagnostics later

There is already a code marker for this:

- `HotkeysSettingsViewController.applyAddedShortcut(...)`

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
- `Config folder` uses the same behavior as menu-bar `Customize`
- `Reload` reuses the current reload path
- `Restore settings` is UI-only for now

There is already a TODO marker for later reset wiring:

- `AboutSettingsViewController.handleRestoreSettings(_:)`

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

## Prototype State -> Real Model Plan

Recommended integration path:

### Step 1. Keep one UI draft object

Keep `SettingsPrototypeState` as the UI-facing draft boundary.

Replace:

- hardcoded `.defaultValue`
- ad-hoc demo items

with:

- a real configuration snapshot when opening the settings window
- a real monitor snapshot for display names and display-set options

### Step 2. Keep controllers thin

Tab controllers should:

- read from the shared draft
- write to the shared draft
- not call configuration persistence directly

### Step 3. Centralize apply / save

Recommended split:

- `General`, `Appearance`, `Hotkeys`
  - apply immediately through one coordinator-owned path
- `Layouts`
  - mutate only the layout draft
  - apply / persist only on `Save`

### Step 4. Preserve typed values in sheets

Do not let sheets return display strings when the real model wiring starts.

Examples:

- modifier groups should return `[ModifierKey]`
- hotkey recorder should return `KeyboardShortcut`
- hotkey action picker should return `HotkeyAction`
- exclusion sheet should return a typed exclusion entry request

## Known Prototype-Only Code That Must Be Replaced Later

These are intentional placeholder areas, not bugs:

- `SettingsPrototypeState`
  - currently seeds extra demo exclusions
- `HotkeysSettingsViewController.applyAddedShortcut(...)`
  - direct append into prototype bindings
- `AboutSettingsViewController.handleRestoreSettings(_:)`
  - no real restore flow yet
- display-set monitor refresh button
  - currently UI-defined behavior only
  - real monitor reload needs a concrete source of truth and refresh path

If these remain when model integration is complete, the settings UI will still behave like a prototype.

## Monitor Naming and Display-Set Rules

Current accepted naming:

- `All monitor`
- `Main monitor`
- custom monitor names

For custom monitor names:

- use monitor names, not raw IDs
- if multiple names are shown in one compact title, separate with `; `

When real wiring starts:

- source of truth should be persisted monitor metadata first
- not `NSScreen.screens` directly
- refresh behavior may later repopulate from live screens, but only through an explicit refresh action

## Tests to Keep Running During Integration

Minimum targeted tests:

- `swift test --filter appDelegateShowsSettingsPrototypeWithTwoTabs`
- `swift test --filter settingsWindowUsesPerTabWindowMetrics`
- `swift test --filter LayoutsSettingsViewControllerTests`
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
