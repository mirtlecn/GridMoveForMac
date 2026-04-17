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
@Test func settingsWindowControllerConfiguresNativeToolbarSections() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-toolbar-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let controller = SettingsWindowController(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    let toolbar = try #require(controller.window?.toolbar)

    #expect(toolbar.selectedItemIdentifier == NSToolbarItem.Identifier("GridMove.Settings.general"))
    #expect(toolbar.items.map(\.itemIdentifier) == [
        NSToolbarItem.Identifier("GridMove.Settings.general"),
        NSToolbarItem.Identifier("GridMove.Settings.layouts"),
        NSToolbarItem.Identifier("GridMove.Settings.appearance"),
        NSToolbarItem.Identifier("GridMove.Settings.hotkeys"),
        NSToolbarItem.Identifier("GridMove.Settings.about"),
    ])
}
