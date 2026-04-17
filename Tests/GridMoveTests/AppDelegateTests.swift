import AppKit
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

@MainActor
@Test func appDelegateRequestsAccessibilityPromptOnlyOnceWhileAccessRemainsMissing() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-accessibility-prompt-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var promptCount = 0
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { false },
        accessibilityPromptRequester: {
            promptCount += 1
            return false
        }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.evaluateAccessibilityState()

    #expect(promptCount == 1)
    #expect(delegate.isAccessibilityPollingActiveForTesting == true)
    #expect(delegate.accessibilityPollingIntervalForTesting == 1.0)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateRequestsAccessibilityPromptAgainAfterAccessIsRevoked() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-accessibility-revoke-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var trustState = true
    var promptCount = 0
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { trustState },
        accessibilityPromptRequester: {
            promptCount += 1
            return false
        }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    #expect(promptCount == 0)
    #expect(delegate.isAccessibilityPollingActiveForTesting == false)

    trustState = false
    delegate.evaluateAccessibilityState()
    #expect(promptCount == 1)
    #expect(delegate.isAccessibilityPollingActiveForTesting == true)
    #expect(delegate.accessibilityPollingIntervalForTesting == 1.0)

    trustState = true
    delegate.evaluateAccessibilityState()
    #expect(delegate.isAccessibilityPollingActiveForTesting == false)
    trustState = false
    delegate.evaluateAccessibilityState()
    #expect(promptCount == 2)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateStopsGlobalInputMonitoringWhenDisabled() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-disable-monitoring-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    #expect(delegate.shouldMonitorGlobalInputForTesting == true)

    var disabledConfiguration = try store.load()
    disabledConfiguration.general.isEnabled = false
    try store.save(disabledConfiguration)

    delegate.reloadConfigurationFromDisk()

    #expect(delegate.configuration.general.isEnabled == false)
    #expect(delegate.shouldMonitorGlobalInputForTesting == false)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateStopsAccessibilityPollingWhenAccessIsAvailable() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-accessibility-polling-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

    #expect(delegate.isAccessibilityPollingActiveForTesting == false)
    #expect(delegate.accessibilityPollingIntervalForTesting == nil)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateKeepsRuntimeStateUnchangedWhenConfigurationSaveFails() async throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-save-failure-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }

    try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    let blockedStoreURL = temporaryRoot.appendingPathComponent("blocked-store")
    try "not a directory".write(to: blockedStoreURL, atomically: true, encoding: .utf8)

    let store = ConfigurationStore(baseDirectoryURL: blockedStoreURL)
    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })

    #expect(delegate.configuration.dragTriggers.enableMiddleMouseDrag == true)
    #expect(delegate.updateMiddleMouseDragEnabled(false) == false)
    #expect(delegate.configuration.dragTriggers.enableMiddleMouseDrag == true)
}

@MainActor
@Test func appDelegateClearsRecordedLayoutCycleStateAfterReloadingChangedLayouts() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-layout-reset-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk()

    delegate.recordLayoutIDForTesting("layout-2", windowIdentity: "window-a")
    #expect(delegate.nextLayoutIDForTesting(windowIdentity: "window-a") == "layout-3")

    var reorderedConfiguration = delegate.configuration
    reorderedConfiguration.moveLayout(id: "layout-2", to: reorderedConfiguration.layouts.count)
    try store.save(reorderedConfiguration)

    delegate.reloadConfigurationFromDisk()

    #expect(delegate.nextLayoutIDForTesting(windowIdentity: "window-a") == "layout-1")
}

@MainActor
@Test func appDelegatePersistsDragTriggerMenuToggles() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-drag-toggle-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    _ = try store.load()

    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk()

    delegate.updateMiddleMouseDragEnabled(false)
    delegate.updateModifierLeftMouseDragEnabled(false)
    delegate.updatePreferLayoutMode(false)

    let reloadedConfiguration = try store.load()

    #expect(delegate.configuration.dragTriggers.enableMiddleMouseDrag == false)
    #expect(delegate.configuration.dragTriggers.enableModifierLeftMouseDrag == false)
    #expect(delegate.configuration.dragTriggers.preferLayoutMode == false)
    #expect(reloadedConfiguration.dragTriggers.enableMiddleMouseDrag == false)
    #expect(reloadedConfiguration.dragTriggers.enableModifierLeftMouseDrag == false)
    #expect(reloadedConfiguration.dragTriggers.preferLayoutMode == false)
}
