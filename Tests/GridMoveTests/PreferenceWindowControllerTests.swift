import Testing
@testable import GridMove

@MainActor
@Test func menuBarControllerKeepsSettingsAndAddsPreferenceEntry() async throws {
    let controller = MenuBarController(
        dragGridEnabled: true,
        actionItems: [],
        onToggleDragGrid: { _ in },
        onPerformAction: { _ in },
        onOpenPreference: {},
        onOpenSettings: {},
        onQuit: {}
    )

    let titles = controller.menuItemTitlesForTesting
    #expect(titles.contains(UICopy.preferenceMenuTitle))
    #expect(titles.contains(UICopy.settingsMenuTitle))
}

@MainActor
@Test func preferenceWindowControllerUsesFiveTabsInExpectedOrder() async throws {
    let controller = PreferenceWindowController()

    #expect(controller.tabTitlesForTesting == [
        UICopy.generalSectionTitle,
        UICopy.layoutsSectionTitle,
        UICopy.appearanceSectionTitle,
        UICopy.hotkeysSectionTitle,
        UICopy.aboutSectionTitle,
    ])
}

@MainActor
@Test func preferenceGeneralTabExposesExpectedSections() async throws {
    let controller = PreferenceWindowController()

    #expect(controller.generalSectionTitlesForTesting == [
        UICopy.enableTitle,
        UICopy.mouseTriggersSectionTitle,
        UICopy.excludedWindowsSectionTitle,
    ])
}

@MainActor
@Test func preferenceWindowControllerInvokesOnCloseCallback() async throws {
    var didClose = false
    let controller = PreferenceWindowController {
        didClose = true
    }

    controller.handleWindowClose()

    #expect(didClose == true)
}
