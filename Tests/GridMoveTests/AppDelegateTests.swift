import AppKit
import Testing
@testable import GridMove

@MainActor
@Test func appDelegateReopenShowsSettingsWithoutCreatingDuplicates() async throws {
    let appDelegate = AppDelegate()

    let firstResult = appDelegate.handleApplicationReopen()
    let firstController = try #require(appDelegate.settingsWindowControllerForTesting)

    let secondResult = appDelegate.handleApplicationReopen()
    let secondController = try #require(appDelegate.settingsWindowControllerForTesting)

    #expect(firstResult == false)
    #expect(secondResult == false)
    #expect(ObjectIdentifier(firstController) == ObjectIdentifier(secondController))

    firstController.close()
}
