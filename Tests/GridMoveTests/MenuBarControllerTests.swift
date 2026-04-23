import AppKit
import Testing
@testable import GridMove

@MainActor
@Test func menuBarControllerUsesSettingsAsOnlySettingsEntry() async throws {
    let controller = MenuBarController(
        dragGridEnabled: true,
        toggleSettings: .init(
            mouseButtonNumber: 3,
            mouseButtonDragEnabled: true,
            modifierLeftMouseDragEnabled: true,
            preferLayoutMode: true,
            launchAtLogin: true
        ),
        layoutGroupState: .init(groupNames: ["default", "work"], activeGroupName: "default"),
        actionItems: [
            .init(title: UICopy.applyPreviousLayout, action: .cyclePrevious, shortcut: nil),
            .init(title: UICopy.applyNextLayout, action: .cycleNext, shortcut: nil),
        ],
        onRequestAccessibilityAccess: {},
        onToggleDragGrid: { _ in true },
        onToggleMouseButtonDrag: { _ in true },
        onToggleModifierLeftMouseDrag: { _ in true },
        onTogglePreferLayoutMode: { _ in true },
        onToggleLaunchAtLogin: { _ in true },
        onSelectLayoutGroup: { _ in true },
        onPerformAction: { _ in },
        onOpenSettings: {},
        onQuit: {}
    )

    #expect(
        controller.menuItemDescriptorsForTesting == [
            UICopy.enableMenuTitle,
            "|",
            UICopy.mouseButtonDragMenuTitle(mouseButtonNumber: 3),
            UICopy.modifierLeftMouseDragMenuTitle,
            UICopy.preferLayoutModeMenuTitle,
            "|",
            UICopy.layoutGroupMenuTitle,
            "|",
            UICopy.applyPreviousLayout,
            UICopy.applyNextLayout,
            "|",
            UICopy.settingsMenuTitle,
            UICopy.launchAtLoginMenuTitle,
            "|",
            UICopy.quitMenuTitle,
        ]
    )
}

@MainActor
@Test func menuBarControllerReflectsToggleStates() async throws {
    let controller = MenuBarController(
        dragGridEnabled: true,
        toggleSettings: .init(
            mouseButtonNumber: 3,
            mouseButtonDragEnabled: false,
            modifierLeftMouseDragEnabled: true,
            preferLayoutMode: false,
            launchAtLogin: true
        ),
        layoutGroupState: .init(groupNames: ["default", "work"], activeGroupName: "work"),
        actionItems: [],
        onRequestAccessibilityAccess: {},
        onToggleDragGrid: { _ in true },
        onToggleMouseButtonDrag: { _ in true },
        onToggleModifierLeftMouseDrag: { _ in true },
        onTogglePreferLayoutMode: { _ in true },
        onToggleLaunchAtLogin: { _ in true },
        onSelectLayoutGroup: { _ in true },
        onPerformAction: { _ in },
        onOpenSettings: {},
        onQuit: {}
    )

    #expect(
        controller.toggleStateDescriptorsForTesting == [
            UICopy.mouseButtonDragMenuTitle(mouseButtonNumber: 3): false,
            UICopy.modifierLeftMouseDragMenuTitle: true,
            UICopy.preferLayoutModeMenuTitle: false,
            UICopy.launchAtLoginMenuTitle: true,
        ]
    )

    #expect(
        controller.layoutGroupDescriptorsForTesting == [
            "default": false,
            "work": true,
        ]
    )
}

@MainActor
@Test func menuBarControllerShowsConfiguredMouseButtonNumberInTitle() async throws {
    let controller = MenuBarController(
        dragGridEnabled: true,
        toggleSettings: .init(
            mouseButtonNumber: 5,
            mouseButtonDragEnabled: true,
            modifierLeftMouseDragEnabled: true,
            preferLayoutMode: true,
            launchAtLogin: false
        ),
        layoutGroupState: .init(groupNames: ["default"], activeGroupName: "default"),
        actionItems: [],
        onRequestAccessibilityAccess: {},
        onToggleDragGrid: { _ in true },
        onToggleMouseButtonDrag: { _ in true },
        onToggleModifierLeftMouseDrag: { _ in true },
        onTogglePreferLayoutMode: { _ in true },
        onToggleLaunchAtLogin: { _ in true },
        onSelectLayoutGroup: { _ in true },
        onPerformAction: { _ in },
        onOpenSettings: {},
        onQuit: {}
    )

    #expect(controller.menuItemDescriptorsForTesting.contains(UICopy.mouseButtonDragMenuTitle(mouseButtonNumber: 5)))
    #expect(
        controller.toggleStateDescriptorsForTesting[UICopy.mouseButtonDragMenuTitle(mouseButtonNumber: 5)] == true
    )
}

@MainActor
@Test func menuBarControllerShowsOnlyAccessibilityRequestWhenAccessIsMissing() async throws {
    let controller = MenuBarController(
        dragGridEnabled: true,
        toggleSettings: .init(
            mouseButtonNumber: 3,
            mouseButtonDragEnabled: true,
            modifierLeftMouseDragEnabled: true,
            preferLayoutMode: true,
            launchAtLogin: true
        ),
        layoutGroupState: .init(groupNames: ["default"], activeGroupName: "default"),
        actionItems: [.init(title: UICopy.applyNextLayout, action: .cycleNext, shortcut: nil)],
        onRequestAccessibilityAccess: {},
        onToggleDragGrid: { _ in true },
        onToggleMouseButtonDrag: { _ in true },
        onToggleModifierLeftMouseDrag: { _ in true },
        onTogglePreferLayoutMode: { _ in true },
        onToggleLaunchAtLogin: { _ in true },
        onSelectLayoutGroup: { _ in true },
        onPerformAction: { _ in },
        onOpenSettings: {},
        onQuit: {}
    )

    controller.updateAccessibilityAccess(false)

    #expect(
        controller.menuItemDescriptorsForTesting == [
            UICopy.requestAccessibilityAccessMenuTitle,
            "|",
            UICopy.quitMenuTitle,
        ]
    )
    #expect(controller.stateColumnSpacingDescriptorsForTesting[UICopy.requestAccessibilityAccessMenuTitle] == false)
    #expect(controller.stateColumnSpacingDescriptorsForTesting[UICopy.quitMenuTitle] == false)
}

@MainActor
@Test func menuBarControllerShowsDefaultShortcutsForSettingsAndQuit() async throws {
    let controller = MenuBarController(
        dragGridEnabled: true,
        toggleSettings: .init(
            mouseButtonNumber: 3,
            mouseButtonDragEnabled: true,
            modifierLeftMouseDragEnabled: true,
            preferLayoutMode: true,
            launchAtLogin: true
        ),
        layoutGroupState: .init(groupNames: ["default"], activeGroupName: "default"),
        actionItems: [],
        onRequestAccessibilityAccess: {},
        onToggleDragGrid: { _ in true },
        onToggleMouseButtonDrag: { _ in true },
        onToggleModifierLeftMouseDrag: { _ in true },
        onTogglePreferLayoutMode: { _ in true },
        onToggleLaunchAtLogin: { _ in true },
        onSelectLayoutGroup: { _ in true },
        onPerformAction: { _ in },
        onOpenSettings: {},
        onQuit: {}
    )

    #expect(controller.shortcutDescriptorsForTesting[UICopy.settingsMenuTitle] == "⌘,")
    #expect(controller.shortcutDescriptorsForTesting[UICopy.quitMenuTitle] == "⌘Q")
}

@MainActor
@Test func menuBarControllerDoesNotReserveStateColumnSpacingWhenItemsAreUnchecked() async throws {
    let controller = MenuBarController(
        dragGridEnabled: false,
        toggleSettings: .init(
            mouseButtonNumber: 3,
            mouseButtonDragEnabled: false,
            modifierLeftMouseDragEnabled: false,
            preferLayoutMode: false,
            launchAtLogin: false
        ),
        layoutGroupState: .init(groupNames: ["default"], activeGroupName: "default"),
        actionItems: [
            .init(title: UICopy.applyPreviousLayout, action: .cyclePrevious, shortcut: nil),
            .init(title: UICopy.applyNextLayout, action: .cycleNext, shortcut: nil),
        ],
        onRequestAccessibilityAccess: {},
        onToggleDragGrid: { _ in true },
        onToggleMouseButtonDrag: { _ in true },
        onToggleModifierLeftMouseDrag: { _ in true },
        onTogglePreferLayoutMode: { _ in true },
        onToggleLaunchAtLogin: { _ in true },
        onSelectLayoutGroup: { _ in true },
        onPerformAction: { _ in },
        onOpenSettings: {},
        onQuit: {}
    )

    #expect(controller.stateColumnSpacingDescriptorsForTesting[UICopy.enableMenuTitle] == false)
    #expect(controller.stateColumnSpacingDescriptorsForTesting[UICopy.mouseButtonDragMenuTitle(mouseButtonNumber: 3)] == false)
    #expect(controller.stateColumnSpacingDescriptorsForTesting[UICopy.applyPreviousLayout] == false)
    #expect(controller.stateColumnSpacingDescriptorsForTesting[UICopy.settingsMenuTitle] == false)
    #expect(controller.stateColumnSpacingDescriptorsForTesting[UICopy.quitMenuTitle] == false)
}
