import AppKit
import Testing
@testable import GridMove

@MainActor
@Test func menuBarControllerShowsReloadAndCustomizeEntries() async throws {
    let controller = MenuBarController(
        dragGridEnabled: true,
        actionItems: [
            .init(title: UICopy.applyPreviousLayout, action: .cyclePrevious, shortcut: nil),
            .init(title: UICopy.applyNextLayout, action: .cycleNext, shortcut: nil),
        ],
        onToggleDragGrid: { _ in },
        onPerformAction: { _ in },
        onReloadConfiguration: {},
        onCustomize: {},
        onQuit: {}
    )

    #expect(
        controller.menuItemDescriptorsForTesting == [
            "Enable",
            "|",
            "Apply previous layout",
            "Apply next layout",
            "|",
            "Reload config",
            "Customize",
            "|",
            "Quit",
        ]
    )
}
