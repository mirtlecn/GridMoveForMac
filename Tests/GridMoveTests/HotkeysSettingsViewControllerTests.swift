import Foundation
import Testing
@testable import GridMove

private func makeTestLayout(
    id: String,
    name: String,
    includeInLayoutIndex: Bool = true
) -> LayoutPreset {
    LayoutPreset(
        id: id,
        name: name,
        gridColumns: 12,
        gridRows: 6,
        windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6),
        triggerRegion: nil,
        includeInLayoutIndex: includeInLayoutIndex
    )
}

@Test func hotkeyPrototypeSlotsUseMaximumIndexedLayoutCountAcrossGroupsAndActiveGroupTargets() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.layoutGroups = [
        LayoutGroup(
            name: "built-in",
            includeInGroupCycle: true,
            sets: [
                LayoutSet(
                    monitor: .main,
                    layouts: [
                        makeTestLayout(id: "layout-a", name: "Alpha"),
                        makeTestLayout(id: "layout-b", name: ""),
                    ]
                )
            ]
        ),
        LayoutGroup(
            name: "work",
            includeInGroupCycle: true,
            sets: [
                LayoutSet(
                    monitor: .main,
                    layouts: [
                        makeTestLayout(id: "layout-c", name: "One"),
                        makeTestLayout(id: "layout-d", name: "Two"),
                        makeTestLayout(id: "layout-e", name: "Three"),
                        makeTestLayout(id: "layout-f", name: "Four"),
                    ]
                )
            ]
        ),
    ]
    configuration.general.activeLayoutGroup = "built-in"

    let slots = HotkeyPrototypeSlot.makePrototypeSlots(configuration: configuration)
    let layoutSlots = slots.filter {
        if case .applyLayoutByIndex = $0.action {
            return true
        }
        return false
    }

    #expect(layoutSlots.count == 4)
    #expect(layoutSlots[0].title == UICopy.settingsApplyLayoutSlotTitle(1))
    #expect(layoutSlots[0].currentTarget == "Alpha")
    #expect(layoutSlots[1].title == UICopy.settingsApplyLayoutSlotTitle(2))
    #expect(layoutSlots[1].currentTarget == UICopy.settingsApplyLayoutSlotTitle(2))
    #expect(layoutSlots[2].title == UICopy.settingsApplyLayoutSlotTitle(3))
    #expect(layoutSlots[2].currentTarget == "")
    #expect(layoutSlots[3].title == UICopy.settingsApplyLayoutSlotTitle(4))
    #expect(layoutSlots[3].currentTarget == "")
}

@Test func appearanceConfigurationDecodesIntegerGapAndStrokeButKeepsOpacityAsDouble() async throws {
    let json = """
    {
      "renderTriggerAreas": false,
      "triggerOpacity": 20,
      "triggerGap": 2,
      "triggerStrokeColor": "#007AFF33",
      "layoutGap": 1,
      "renderWindowHighlight": true,
      "highlightFillOpacity": 8,
      "highlightStrokeWidth": 3,
      "highlightStrokeColor": "#FFFFFFEB"
    }
    """

    let data = try #require(json.data(using: .utf8))
    let settings = try JSONDecoder().decode(AppearanceConfiguration.self, from: data)

    #expect(settings.triggerGap == 2)
    #expect(settings.highlightFillOpacity == 0.08)
    #expect(settings.highlightStrokeWidth == 3)
}

@MainActor
@Test func hotkeySheetStagesShortcutChangesUntilSave() async throws {
    let actions = HotkeyPrototypeSlot.makePrototypeSlots(configuration: .defaultValue).map(\.actionDescriptor)
    let contentView = HotkeyAddSheetContentView(
        actions: actions,
        selectedActionID: "cycleNext",
        initialShortcutsByActionID: [
            "cycleNext": [KeyboardShortcut(modifiers: [.cmd], key: "k")]
        ]
    )

    #expect(contentView.isConfirmationEnabled == false)
    #expect(contentView.hasChangesForTesting == false)
    #expect(contentView.visibleShortcutDisplayNamesForTesting == ["⌘K"])
    #expect(contentView.shortcutButtonTitleForTesting == UICopy.settingsRecordShortcutButtonTitle)
    #expect(contentView.shortcutButtonControlSizeForTesting == .regular)

    contentView.beginShortcutRecordingForTesting()
    #expect(contentView.shortcutButtonTitleForTesting == UICopy.settingsPressShortcutValue)

    contentView.applyRecordedShortcutForTesting(KeyboardShortcut(modifiers: [.cmd, .shift], key: "k"))
    #expect(contentView.visibleShortcutDisplayNamesForTesting == ["⌘K", "⇧⌘K"])
    #expect(contentView.shortcutButtonTitleForTesting == UICopy.settingsRecordShortcutButtonTitle)
    #expect(contentView.isConfirmationEnabled == true)
    #expect(contentView.hasChangesForTesting == true)

    contentView.removeVisibleShortcutForTesting(at: 0)
    #expect(contentView.visibleShortcutDisplayNamesForTesting == ["⇧⌘K"])
    #expect(contentView.editedActionIDsForTesting == Set(["cycleNext"]))
}

@MainActor
@Test func hotkeySheetDisplaysFunctionAndKeypadShortcutNames() async throws {
    let actions = HotkeyPrototypeSlot.makePrototypeSlots(configuration: .defaultValue).map(\.actionDescriptor)
    let contentView = HotkeyAddSheetContentView(
        actions: actions,
        selectedActionID: "cycleNext",
        initialShortcutsByActionID: [
            "cycleNext": [
                KeyboardShortcut(modifiers: [.cmd], key: "f1"),
                KeyboardShortcut(modifiers: [.cmd], key: "keypad1"),
            ]
        ]
    )

    #expect(contentView.visibleShortcutDisplayNamesForTesting == ["⌘F1", "⌘Num 1"])
}

@Test func keyboardShortcutPrototypeDisplayUsesCompactNavigationNames() async throws {
    #expect(KeyboardShortcut(modifiers: [.cmd], key: "pageUp").prototypeDisplayName == "⌘PgUp")
    #expect(KeyboardShortcut(modifiers: [.cmd], key: "pageDown").prototypeDisplayName == "⌘PgDn")
    #expect(KeyboardShortcut(modifiers: [.cmd], key: "insert").prototypeDisplayName == "⌘Ins")
    #expect(KeyboardShortcut(modifiers: [.cmd], key: "delete").prototypeDisplayName == "⌘⌫")
    #expect(KeyboardShortcut(modifiers: [.cmd], key: "forwardDelete").prototypeDisplayName == "⌘⌦")
    #expect(KeyboardShortcut(modifiers: [.cmd], key: "escape").prototypeDisplayName == "⌘⎋")
    #expect(KeyboardShortcut(modifiers: [.cmd], key: "home").prototypeDisplayName == "⌘Home")
    #expect(KeyboardShortcut(modifiers: [.cmd], key: "end").prototypeDisplayName == "⌘End")
}

@MainActor
@Test func hotkeysControllerAddsRealShortcutBindingAndClearsSelectedAction() async throws {
    let state = SettingsPrototypeState(configuration: .defaultValue)
    state.reload(from: AppConfiguration.defaultValue)
    let recorder = TestSettingsActionRecorder()
    let controller = HotkeysSettingsViewController(
        prototypeState: state,
        actionHandler: recorder.makeActionHandler()
    )
    controller.loadViewIfNeeded()

    let shortcut = KeyboardShortcut(modifiers: [.ctrl, .cmd], key: "k")
    controller.applyAddedShortcut(actionID: "cycleNext", shortcut: shortcut)

    #expect(state.configuration.hotkeys.bindings.contains {
        $0.action == .cycleNext && $0.shortcut == shortcut && $0.isEnabled
    })

    controller.selectSlotForTesting(1)
    controller.clearSelectedSlotForTesting()

    #expect(state.configuration.hotkeys.bindings.contains { $0.action == .cycleNext } == false)
    #expect(controller.bindingsForSelectedSlotForTesting.isEmpty)
}

@MainActor
@Test func hotkeysControllerRollsBackAddedBindingOnFailure() async throws {
    let state = SettingsPrototypeState(configuration: .defaultValue)
    let recorder = TestSettingsActionRecorder()
    recorder.applySucceeds = false
    let controller = HotkeysSettingsViewController(
        prototypeState: state,
        actionHandler: recorder.makeActionHandler()
    )
    controller.loadViewIfNeeded()

    let originalBindings = state.configuration.hotkeys.bindings
    controller.applyAddedShortcut(
        actionID: "cycleNext",
        shortcut: KeyboardShortcut(modifiers: [.cmd], key: "9")
    )

    #expect(state.configuration.hotkeys.bindings == originalBindings)
}

@MainActor
@Test func hotkeysControllerSavesShortcutEditorChangesForSelectedAction() async throws {
    let state = SettingsPrototypeState(configuration: .defaultValue)
    state.reload(from: AppConfiguration.defaultValue)
    let recorder = TestSettingsActionRecorder()
    let controller = HotkeysSettingsViewController(
        prototypeState: state,
        actionHandler: recorder.makeActionHandler()
    )
    controller.loadViewIfNeeded()

    let actions = HotkeyPrototypeSlot.makePrototypeSlots(configuration: state.configuration).map(\.actionDescriptor)
    let contentView = HotkeyAddSheetContentView(
        actions: actions,
        selectedActionID: "cycleNext",
        initialShortcutsByActionID: [
            "cycleNext": [KeyboardShortcut(modifiers: [.ctrl, .cmd], key: "l")]
        ]
    )
    contentView.applyRecordedShortcutForTesting(KeyboardShortcut(modifiers: [.cmd], key: "9"))
    contentView.removeVisibleShortcutForTesting(at: 0)

    controller.applyShortcutEditorChangesForTesting(contentView)

    let cycleNextBindings = state.configuration.hotkeys.bindings.filter { $0.action == .cycleNext }
    #expect(cycleNextBindings.compactMap(\.shortcut) == [KeyboardShortcut(modifiers: [.cmd], key: "9")])
}

@Test func emptyHotkeyBindingsRenderAsBlankSummary() async throws {
    let slots = HotkeyPrototypeSlot.makePrototypeSlots(configuration: .defaultValue)
    let emptyBindingSlot = try #require(slots.first(where: { $0.bindings.isEmpty }))

    #expect(emptyBindingSlot.bindingSummary.isEmpty)
}

@MainActor
@Test func hotkeysTableSupportsDoubleClickToOpenAddSheet() async throws {
    let controller = HotkeysSettingsViewController(
        prototypeState: SettingsPrototypeState(configuration: .defaultValue),
        actionHandler: TestSettingsActionRecorder().makeActionHandler()
    )
    controller.loadViewIfNeeded()

    #expect(controller.supportsDoubleClickAddShortcutForTesting == true)
}
