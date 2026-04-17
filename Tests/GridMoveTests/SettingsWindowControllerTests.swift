import AppKit
import Foundation
import Testing
@testable import GridMove

@MainActor
@Test func settingsWindowControllerInvokesOnCloseCallback() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-window-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var didClose = false

    let controller = SettingsWindowController(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in },
        onClose: {
            didClose = true
        }
    )

    controller.handleWindowClose()

    #expect(didClose == true)
}

@MainActor
@Test func settingsWindowControllerConfiguresToolbarBackedWindow() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-window-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let controller = SettingsWindowController(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    #expect(controller.window?.toolbar != nil)
    #expect(controller.window?.toolbarStyle == .automatic)
    #expect(controller.window?.titleVisibility == .hidden)
    #expect(controller.window?.minSize.width == 860)
    #expect((controller.window?.minSize.height ?? 0) >= 660)
}
