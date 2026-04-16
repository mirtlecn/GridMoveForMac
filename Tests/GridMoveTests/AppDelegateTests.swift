import Foundation
import Testing
@testable import GridMove

@MainActor
@Test func appDelegateReloadsConfigurationFromDisk() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-appdelegate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.isEnabled = false
    savedConfiguration.layouts.reverse()
    try store.save(savedConfiguration)

    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk()

    #expect(delegate.configuration.general.isEnabled == false)
    #expect(delegate.configuration.layouts.map(\.name) == savedConfiguration.layouts.map(\.name))
    #expect(delegate.configuration.layouts.map(\.id) == (1...savedConfiguration.layouts.count).map { "layout-\($0)" })
    #expect(delegate.configuration.hotkeys.bindings.map(\.id) == (1...savedConfiguration.hotkeys.bindings.count).map { "binding-\($0)" })
    #expect(delegate.configuration.hotkeys.bindings[2].action == .applyLayout(layoutID: "layout-8"))
}

@MainActor
@Test func appDelegateCustomizeOpensConfigurationDirectory() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-customize-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var openedURL: URL?
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { url in
            openedURL = url
            return true
        }
    )

    #expect(delegate.openConfigurationDirectory() == true)
    #expect(openedURL == store.directoryURL)
}

@MainActor
@Test func appDelegateNotifiesUserWhenManualReloadFallsBackToDefault() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-notify-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    try """
    {
      "general": {
        "isEnabled":
    """.write(to: store.fileURL, atomically: true, encoding: .utf8)

    var receivedTitle: String?
    var receivedBody: String?
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        notifyUser: { title, body in
            receivedTitle = title
            receivedBody = body
        }
    )

    delegate.reloadConfigurationFromDisk(notifyOnFallback: true)

    #expect(delegate.configuration == .defaultValue)
    #expect(receivedTitle == UICopy.configReloadFailedTitle)
    #expect(receivedBody == UICopy.configReloadFailedBody)
}
