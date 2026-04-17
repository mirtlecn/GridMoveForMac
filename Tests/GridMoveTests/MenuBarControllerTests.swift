import AppKit
import Testing
@testable import GridMove

@MainActor
@Test func menuBarControllerShowsReloadAndCustomizeEntries() async throws {
    let controller = MenuBarController(
        dragGridEnabled: true,
        toggleSettings: .init(
            middleMouseDragEnabled: true,
            modifierLeftMouseDragEnabled: true,
            preferLayoutMode: true
        ),
        actionItems: [
            .init(title: UICopy.applyPreviousLayout, action: .cyclePrevious, shortcut: nil),
            .init(title: UICopy.applyNextLayout, action: .cycleNext, shortcut: nil),
        ],
        onToggleDragGrid: { _ in },
        onToggleMiddleMouseDrag: { _ in },
        onToggleModifierLeftMouseDrag: { _ in },
        onTogglePreferLayoutMode: { _ in },
        onPerformAction: { _ in },
        onReloadConfiguration: {},
        onCustomize: {},
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
            "Apply previous layout",
            "Apply next layout",
            "|",
            "Reload",
            "Customize... ↗",
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
            middleMouseDragEnabled: false,
            modifierLeftMouseDragEnabled: true,
            preferLayoutMode: false
        ),
        actionItems: [],
        onToggleDragGrid: { _ in },
        onToggleMiddleMouseDrag: { _ in },
        onToggleModifierLeftMouseDrag: { _ in },
        onTogglePreferLayoutMode: { _ in },
        onPerformAction: { _ in },
        onReloadConfiguration: {},
        onCustomize: {},
        onQuit: {}
    )

    #expect(
        controller.toggleStateDescriptorsForTesting == [
            UICopy.middleMouseDragMenuTitle: false,
            UICopy.modifierLeftMouseDragMenuTitle: true,
            UICopy.preferLayoutModeMenuTitle: false,
        ]
    )
}
