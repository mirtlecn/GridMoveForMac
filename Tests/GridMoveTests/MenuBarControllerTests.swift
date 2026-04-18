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
        layoutGroupState: .init(groupNames: ["built-in", "work"], activeGroupName: "built-in"),
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
            "Enable",
            "|",
            "Middle mouse drag",
            "Modifier + left mouse drag",
            "Prefer layout mode",
            "|",
            "Layout group",
            "|",
            "Apply previous layout",
            "Apply next layout",
            "|",
            "Settings...",
            "Launch at login",
            "|",
            "Quit",
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
        layoutGroupState: .init(groupNames: ["built-in", "work"], activeGroupName: "work"),
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
            "built-in": false,
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
        layoutGroupState: .init(groupNames: ["built-in"], activeGroupName: "built-in"),
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

    #expect(controller.menuItemDescriptorsForTesting.contains("Mouse button 5 drag"))
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
        layoutGroupState: .init(groupNames: ["built-in"], activeGroupName: "built-in"),
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

    #expect(controller.menuItemDescriptorsForTesting == [UICopy.requestAccessibilityAccessMenuTitle])
}
