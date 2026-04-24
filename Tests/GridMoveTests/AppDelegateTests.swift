import AppKit
import Foundation
import Testing
@testable import GridMove

private func writeMainConfigurationJSON(_ json: String, to store: ConfigurationStore) throws {
    try FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
    try json.write(to: store.fileURL, atomically: true, encoding: .utf8)
}

private func writeLayoutFile(_ fileName: String, json: String, to store: ConfigurationStore) throws {
    try FileManager.default.createDirectory(at: store.layoutDirectoryURL, withIntermediateDirectories: true)
    try json.write(
        to: store.layoutDirectoryURL.appendingPathComponent(fileName),
        atomically: true,
        encoding: .utf8
    )
}

private struct TestLaunchAtLoginError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private final class TestLaunchAtLoginService: LaunchAtLoginServiceProtocol {
    var currentStatus: LaunchAtLoginStatus
    var registerResult: LaunchAtLoginStatus
    var unregisterResult: LaunchAtLoginStatus
    var registerError: Error?
    var unregisterError: Error?

    private(set) var statusCallCount = 0
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(
        currentStatus: LaunchAtLoginStatus = .disabled,
        registerResult: LaunchAtLoginStatus = .enabled,
        unregisterResult: LaunchAtLoginStatus = .disabled
    ) {
        self.currentStatus = currentStatus
        self.registerResult = registerResult
        self.unregisterResult = unregisterResult
    }

    func status() -> LaunchAtLoginStatus {
        statusCallCount += 1
        return currentStatus
    }

    func register() throws -> LaunchAtLoginStatus {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        currentStatus = registerResult
        return registerResult
    }

    func unregister() throws -> LaunchAtLoginStatus {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        currentStatus = unregisterResult
        return unregisterResult
    }
}

@MainActor
@Test func appDelegateReloadsConfigurationFromDisk() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-appdelegate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.isEnabled = false
    savedConfiguration.layoutGroups[0].sets[0].layouts.reverse()
    try store.save(savedConfiguration)

    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk(mode: .launch)

    #expect(delegate.configuration.general.isEnabled == false)
    #expect(delegate.configuration.layouts.map(\.name) == savedConfiguration.layouts.map(\.name))
    #expect(delegate.configuration.layouts.map(\.id) == (1...savedConfiguration.layouts.count).map { "layout-\($0)" })
    #expect(delegate.configuration.hotkeys.bindings.map(\.id) == (1...savedConfiguration.hotkeys.bindings.count).map { "binding-\($0)" })
    #expect(delegate.configuration.hotkeys.bindings[2].action == .applyLayoutByIndex(layout: 4))
}

@MainActor
@Test func appDelegateDecodesLaunchAtLoginMissingFieldAsFalse() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-default-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    _ = try store.load()

    try writeMainConfigurationJSON(
        """
        {
          "general": {
            "isEnabled": true,
            "excludedBundleIDs": ["com.apple.Spotlight"],
            "excludedWindowTitles": [],
            "mouseButtonNumber": 3,
            "activeLayoutGroup": "default"
          },
          "appearance": {
            "renderTriggerAreas": false,
            "triggerOpacity": 0.2,
            "triggerGap": 2,
            "triggerStrokeColor": "#00FDFFFF",
            "renderWindowHighlight": true,
            "highlightFillOpacity": 0.20,
            "highlightStrokeWidth": 3,
            "highlightStrokeColor": "#FFFFFFEB"
          },
          "dragTriggers": {
            "enableMouseButtonDrag": true,
            "enableModifierLeftMouseDrag": true,
            "preferLayoutMode": true,
            "modifierGroups": [["ctrl", "cmd", "shift", "alt"]],
            "activationDelayMilliseconds": 300,
            "activationMoveThreshold": 10
          },
          "hotkeys": {
            "bindings": []
          },
          "monitors": {}
        }
        """,
        to: store
    )

    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk(mode: .launch)

    #expect(delegate.configuration.general.launchAtLogin == false)
}

@MainActor
@Test func appDelegateReloadPersistsMonitorMetadata() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-monitor-metadata-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let monitorMap = [
        "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display",
        "9b249d3c-1111-2222-3333-444455556666": "DELL U2720Q",
    ]
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        currentMonitorMapProvider: { monitorMap }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)

    let persistedConfiguration = try store.load()
    #expect(delegate.configuration.monitors == monitorMap)
    #expect(persistedConfiguration.monitors == monitorMap)
}

@MainActor
@Test func appDelegateReloadMergesCurrentMonitorMetadataAndPreservesDisconnectedDisplays() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-monitor-metadata-merge-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.monitors = [
        "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Old Built-in Name",
        "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee": "Retired Display",
    ]
    try store.save(savedConfiguration)

    let currentMonitorMap = [
        "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display",
        "9b249d3c-1111-2222-3333-444455556666": "DELL U2720Q",
    ]
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        currentMonitorMapProvider: { currentMonitorMap }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)

    let expectedMonitorMap = [
        "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display",
        "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee": "Retired Display",
        "9b249d3c-1111-2222-3333-444455556666": "DELL U2720Q",
    ]
    let persistedConfiguration = try store.load()
    #expect(delegate.configuration.monitors == expectedMonitorMap)
    #expect(persistedConfiguration.monitors == expectedMonitorMap)
}

@MainActor
@Test func appDelegateReloadDoesNotRewriteExplicitMonitorIDs() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-monitor-id-preserve-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.monitors = [
        "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Old Built-in Name",
    ]
    savedConfiguration.layoutGroups = [
        LayoutGroup(
            name: "default",
            includeInGroupCycle: true,
            sets: [
                LayoutSet(
                    monitor: .displays(["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4"]),
                    layouts: AppConfiguration.defaultValue.layoutGroups[0].sets[0].layouts
                ),
            ]
        ),
    ]
    try store.save(savedConfiguration)

    let currentMonitorMap = [
        "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display",
    ]
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        currentMonitorMapProvider: { currentMonitorMap }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)

    #expect(delegate.configuration.layoutGroups[0].sets[0].monitor == .displays(["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4"]))
    #expect(delegate.configuration.monitors == currentMonitorMap)

    let persistedConfiguration = try store.load()
    #expect(persistedConfiguration.layoutGroups[0].sets[0].monitor == .displays(["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4"]))
    #expect(persistedConfiguration.monitors == currentMonitorMap)
}

@MainActor
@Test func appDelegateRegistersLaunchAtLoginOnLaunchWhenAccessibilityIsAvailable() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-launch-register-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.launchAtLogin = true
    try store.save(savedConfiguration)

    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .disabled)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

    #expect(launchAtLoginService.registerCallCount == 1)
    #expect(launchAtLoginService.unregisterCallCount == 0)
    #expect(delegate.configuration.general.launchAtLogin == true)

    #expect(delegate.updateLaunchAtLoginEnabled(false) == true)
    #expect(launchAtLoginService.unregisterCallCount == 1)
    #expect(launchAtLoginService.currentStatus == .disabled)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateDefersLaunchAtLoginRegistrationUntilAccessibilityBecomesAvailable() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-deferred-register-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.launchAtLogin = true
    try store.save(savedConfiguration)

    var trustState = false
    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .disabled)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { trustState },
        accessibilityPromptRequester: { false }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    #expect(launchAtLoginService.registerCallCount == 0)

    trustState = true
    delegate.evaluateAccessibilityState()

    #expect(launchAtLoginService.registerCallCount == 1)

    #expect(delegate.updateLaunchAtLoginEnabled(false) == true)
    #expect(launchAtLoginService.unregisterCallCount == 1)
    #expect(launchAtLoginService.currentStatus == .disabled)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateUnregistersLaunchAtLoginOnLaunchWhenConfigurationDisablesIt() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-launch-unregister-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.launchAtLogin = false
    try store.save(savedConfiguration)

    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .enabled)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

    #expect(launchAtLoginService.unregisterCallCount == 1)
    #expect(launchAtLoginService.registerCallCount == 0)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateSavingRegularSettingsDoesNotRefreshMonitorMetadata() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-monitor-metadata-no-refresh-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var currentMonitorMap = [
        "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display",
    ]
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        currentMonitorMapProvider: { currentMonitorMap }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)
    currentMonitorMap = [
        "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Renamed Built-in Display",
        "9b249d3c-1111-2222-3333-444455556666": "DELL U2720Q",
    ]

    #expect(delegate.updateMouseButtonDragEnabled(false) == true)

    let persistedConfiguration = try store.load()
    #expect(delegate.configuration.monitors == ["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"])
    #expect(persistedConfiguration.monitors == ["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"])
}

@MainActor
@Test func appDelegateSavingRegularSettingsDoesNotTouchLaunchAtLoginService() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-no-regular-sync-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.launchAtLogin = false
    try store.save(savedConfiguration)

    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .disabled)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    #expect(launchAtLoginService.registerCallCount == 0)
    #expect(launchAtLoginService.unregisterCallCount == 0)

    #expect(delegate.updateMouseButtonDragEnabled(false) == true)

    #expect(launchAtLoginService.registerCallCount == 0)
    #expect(launchAtLoginService.unregisterCallCount == 0)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateCyclesLayoutGroupInMemoryBeforeDeferredSave() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-group-cycle-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk(mode: .launch)

    let updatedConfiguration = try #require(delegate.cycleToNextLayoutGroupForTesting())
    #expect(updatedConfiguration.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
    #expect(delegate.configuration.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)

    await delegate.waitForDeferredConfigurationSaveForTesting()

    let persistedConfiguration = try store.load()
    #expect(persistedConfiguration.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
}

@MainActor
@Test func appDelegateDragGroupCyclePostsSystemNotification() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-group-cycle-notify-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var receivedKind: UserNotifier.Kind?
    var receivedTitle: String?
    var receivedBody: String?
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        notifyUser: { kind, title, body in
            receivedKind = kind
            receivedTitle = title
            receivedBody = body
        }
    )
    delegate.reloadConfigurationFromDisk(mode: .launch)

    let updatedConfiguration = try #require(delegate.cycleToNextLayoutGroupForDragForTesting())

    #expect(updatedConfiguration.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
    #expect(receivedKind == .layoutGroupChanged)
    #expect(receivedTitle == UICopy.layoutGroupChangedTitle)
    #expect(receivedBody == UICopy.layoutGroupChangedBody(groupName: AppConfiguration.fullscreenGroupName))
}

@MainActor
@Test func appDelegateMenuActionsHideLayoutsExcludedFromMenu() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-menu-actions-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var configuration = AppConfiguration.defaultValue
    configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
    try store.save(configuration)

    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk(mode: .launch)

    let actionItems = delegate.menuActionItemsForTesting()
    let layoutActionTitles = actionItems.dropFirst(2).map(\.title)
    let layoutActions = actionItems.dropFirst(2).map(\.action)

    #expect(layoutActionTitles == [
        UICopy.applyLayout("Fullscreen main"),
        UICopy.applyLayout("Main left 1/2"),
        UICopy.applyLayout("Main right 1/2"),
        UICopy.applyLayout("Fullscreen other"),
    ])
    #expect(layoutActions == [
        .applyLayoutByID(layoutID: "layout-11"),
        .applyLayoutByID(layoutID: "layout-12"),
        .applyLayoutByID(layoutID: "layout-13"),
        .applyLayoutByID(layoutID: "layout-14"),
    ])
    #expect(actionItems.dropFirst(2).map(\.shortcut) == [
        KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "-"),
        KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "["),
        KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: ";"),
        KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "\\"),
    ])
}

@MainActor
@Test func appDelegateMenuActionsShowDirectLayoutShortcutsForSingleSetGroup() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-menu-shortcuts-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk(mode: .launch)

    let actionItems = delegate.menuActionItemsForTesting()
    let layoutActionItems = Array(actionItems.dropFirst(2))

    #expect(layoutActionItems[0].shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "-"))
    #expect(layoutActionItems[1].shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "["))
    #expect(layoutActionItems[2].shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: ";"))
    #expect(layoutActionItems[3].shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "\\"))
    #expect(layoutActionItems[4].shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "="))
    #expect(layoutActionItems[5].shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "]"))
    #expect(layoutActionItems[6].shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "'"))
    #expect(layoutActionItems[7].shortcut == nil)
    #expect(layoutActionItems.map(\.title).contains(UICopy.applyLayout("Full (menu bar)")) == false)
}

@MainActor
@Test func appDelegateMenuActionsUseUserFacingFallbackForUntitledLayouts() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-menu-untitled-layout-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var configuration = AppConfiguration.defaultValue
    configuration.layoutGroups[0].sets[0].layouts[3].name = ""
    try store.save(configuration)

    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk(mode: .launch)

    let actionItems = delegate.menuActionItemsForTesting()
    let layoutActionTitles = actionItems.dropFirst(2).map(\.title)

    #expect(layoutActionTitles.contains(UICopy.applyLayout(UICopy.settingsUntitledLayoutTitle(4))))
    #expect(layoutActionTitles.contains(where: { $0.contains("layout-4") }) == false)
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
@Test func appDelegateMainMenuShowsSettingsWithCommandComma() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-main-menu-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

    #expect(delegate.mainMenuItemDescriptorsForTesting == [
        UICopy.settingsMenuTitle,
        "|",
        UICopy.quitAppMenuTitle,
    ])
    #expect(delegate.mainMenuShortcutDescriptorsForTesting[UICopy.settingsMenuTitle] == "⌘,")
    #expect(delegate.mainMenuShortcutDescriptorsForTesting[UICopy.quitAppMenuTitle] == "⌘Q")
    #expect(delegate.visibleMenuItemDescriptorsForTesting.contains(UICopy.settingsMenuTitle))

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateCommandWClosesSettingsOnlyWhenSettingsWindowIsKey() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-main-menu-close-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    #expect(delegate.performSettingsCloseShortcutForTesting() == false)

    delegate.showSettings()
    #expect(delegate.performSettingsCloseShortcutForTesting(isKeyWindow: false) == false)
    #expect(delegate.isSettingsWindowOpenForTesting == true)

    #expect(delegate.performSettingsCloseShortcutForTesting(isKeyWindow: true) == true)
    #expect(delegate.isSettingsWindowOpenForTesting == false)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateSettingsWindowReadsPersistedConfigurationValues() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-real-config-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.mouseButtonNumber = 5
    savedConfiguration.general.excludedBundleIDs = ["com.apple.Spotlight"]
    savedConfiguration.general.excludedWindowTitles = ["Floating Panel"]
    try store.save(savedConfiguration)

    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()

    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsMouseDragTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains("com.apple.Spotlight"))
    #expect(delegate.settingsVisibleStringsForTesting.contains("Floating Panel"))
    #expect(
        delegate.settingsVisibleStringsForTesting.contains(
            ModifierKey.allCases.map(\.displayName).joined(separator: " + ")
        )
    )
    #expect(delegate.generalExcludedWindowTitlesForTesting == ["Floating Panel"])

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateShowsSettingsPrototypeWithTwoTabs() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-prototype-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()

    #expect(delegate.isSettingsWindowOpenForTesting == true)
    #expect(delegate.settingsWindowTitleForTesting == UICopy.settingsWindowTitle)
    #expect(delegate.settingsTabTitlesForTesting == [
        UICopy.settingsGeneralTabTitle,
        UICopy.settingsLayoutsTabTitle,
        UICopy.settingsAppearanceTabTitle,
        UICopy.settingsHotkeysTabTitle,
        UICopy.settingsAboutTabTitle,
    ])
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.enableMenuTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.launchAtLoginMenuTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsModifierGroupsLabel))
    #expect(delegate.settingsVisibleStringsForTesting.contains("Runtime") == false)
    delegate.selectSettingsTabForTesting(index: 1)
    #expect(delegate.settingsVisibleStringsForTesting.contains(AppConfiguration.defaultGroupName))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsAllMonitorsValue))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.defaultLayoutNames[0]))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsNameLabel))
    delegate.selectLayoutsLayoutForTesting(id: "layout-1")
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsLayoutInlineTabTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsWindowAreaInlineTabTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsTriggerAreaInlineTabTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsAddLayoutButtonTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains("-"))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsSaveButtonTitle))
    delegate.selectSettingsTabForTesting(index: 2)
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsWindowAreaSectionTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsTriggerAreaSectionTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsHighlightWindowAreaTitle))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsHighlightTriggerAreaTitle))
    delegate.selectSettingsTabForTesting(index: 3)
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.applyNextLayout))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsApplyLayoutSlotTitle(1)))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.defaultLayoutNames[0]))
    #expect(delegate.settingsVisibleStringsForTesting.contains("⌃⌥⇧⌘L"))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsHotkeysAddButtonTitle))
    delegate.selectSettingsTabForTesting(index: 4)
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsVersionLabel))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsAuthorLabel))
    #expect(delegate.settingsVisibleStringsForTesting.contains("Mirtle"))

    delegate.closeSettingsWindowForTesting()
    #expect(delegate.isSettingsWindowOpenForTesting == false)

    delegate.showSettings()
    #expect(delegate.isSettingsWindowOpenForTesting == true)
    #expect(delegate.settingsTabTitlesForTesting == [
        UICopy.settingsGeneralTabTitle,
        UICopy.settingsLayoutsTabTitle,
        UICopy.settingsAppearanceTabTitle,
        UICopy.settingsHotkeysTabTitle,
        UICopy.settingsAboutTabTitle,
    ])

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func settingsWindowUsesPerTabWindowMetrics() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-window-metrics-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()

    let generalMinimumSize = try #require(delegate.settingsMinimumSizeForTesting)
    #expect(generalMinimumSize.width == 680)

    delegate.selectSettingsTabForTesting(index: 1)
    let layoutsMinimumSize = try #require(delegate.settingsMinimumSizeForTesting)
    #expect(layoutsMinimumSize.width == 680)
    #expect(layoutsMinimumSize.height == generalMinimumSize.height)

    delegate.selectSettingsTabForTesting(index: 4)
    let aboutMinimumSize = try #require(delegate.settingsMinimumSizeForTesting)
    #expect(aboutMinimumSize.width == 680)
    #expect(aboutMinimumSize.height < generalMinimumSize.height)

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func settingsWindowUsesCurrentTabMetricsOnFirstOpen() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-window-initial-metrics-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()

    let metrics = try #require(delegate.settingsResolvedMetricsForTesting)

    #expect(metrics.preferredContentSize.width == 700)
    #expect(metrics.preferredContentSize.height == 640)
    #expect(metrics.minimumContentSize.width == 680)
    #expect(metrics.minimumContentSize.height == 640)

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func settingsWindowDoesNotAutoFocusEditableControls() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-focus-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()

    #expect(delegate.settingsUsesTextEditingFocusForTesting == false)

    delegate.selectSettingsTabForTesting(index: 2)
    #expect(delegate.settingsUsesTextEditingFocusForTesting == false)

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func aboutReloadRefreshesOpenSettingsDraft() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-about-reload-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.mouseButtonNumber = 3
    try store.save(savedConfiguration)

    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsMouseDragTitle))

    savedConfiguration.general.mouseButtonNumber = 5
    savedConfiguration.general.excludedWindowTitles = ["Reloaded Panel"]
    try store.save(savedConfiguration)

    delegate.reloadSettingsFromAboutTabForTesting()
    delegate.selectSettingsTabForTesting(index: 0)

    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsMouseDragTitle))

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func aboutRestoreSettingsResetsConfigurationAndReloadsTabs() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-about-restore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.mouseButtonNumber = 5
    savedConfiguration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
    savedConfiguration.general.excludedWindowTitles = ["Restore Me"]
    try store.save(savedConfiguration)

    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        currentMonitorMapProvider: { ["display-1": "Studio Display"] },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()

    delegate.restoreSettingsFromAboutTabForTesting()
    delegate.selectSettingsTabForTesting(index: 0)

    let persistedConfiguration = try store.load()

    #expect(delegate.configuration.general == AppConfiguration.defaultValue.general)
    #expect(delegate.configuration.layoutGroups == AppConfiguration.defaultValue.layoutGroups)
    #expect(delegate.configuration.monitors == ["display-1": "Studio Display"])
    #expect(persistedConfiguration.general == AppConfiguration.defaultValue.general)
    #expect(persistedConfiguration.appearance.triggerHighlightMode == AppConfiguration.defaultValue.appearance.triggerHighlightMode)
    #expect(persistedConfiguration.appearance.triggerFillOpacity == AppConfiguration.defaultValue.appearance.triggerFillOpacity)
    #expect(persistedConfiguration.appearance.triggerGap == AppConfiguration.defaultValue.appearance.triggerGap)
    #expect(persistedConfiguration.appearance.triggerStrokeWidth == AppConfiguration.defaultValue.appearance.triggerStrokeWidth)
    #expect(persistedConfiguration.appearance.layoutGap == AppConfiguration.defaultValue.appearance.layoutGap)
    #expect(persistedConfiguration.appearance.renderWindowHighlight == AppConfiguration.defaultValue.appearance.renderWindowHighlight)
    #expect(persistedConfiguration.appearance.highlightFillOpacity == AppConfiguration.defaultValue.appearance.highlightFillOpacity)
    #expect(persistedConfiguration.appearance.highlightStrokeWidth == AppConfiguration.defaultValue.appearance.highlightStrokeWidth)
    #expect(persistedConfiguration.dragTriggers == AppConfiguration.defaultValue.dragTriggers)
    #expect(persistedConfiguration.hotkeys.bindings.map(\.shortcut) == AppConfiguration.defaultValue.hotkeys.bindings.map(\.shortcut))
    #expect(persistedConfiguration.hotkeys.bindings.map(\.action) == AppConfiguration.defaultValue.hotkeys.bindings.map(\.action))
    #expect(persistedConfiguration.layoutGroups == AppConfiguration.defaultValue.layoutGroups)
    #expect(persistedConfiguration.monitors == ["display-1": "Studio Display"])

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func layoutsSaveFromSettingsPersistsNewGroupAndManagedFile() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-layouts-save-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    delegate.selectSettingsTabForTesting(index: 1)
    delegate.selectLayoutsGroupForTesting(named: AppConfiguration.defaultGroupName)
    delegate.triggerLayoutsAddActionForTesting()

    let draftConfiguration = try #require(delegate.layoutsDraftConfigurationForTesting)
    #expect(draftConfiguration.layoutGroups.count == 3)
    #expect(delegate.configuration.layoutGroups.count == 2)

    delegate.saveLayoutsFromSettingsForTesting()

    let persistedConfiguration = try store.load()
    let layoutFiles = try FileManager.default.contentsOfDirectory(
        at: store.layoutDirectoryURL,
        includingPropertiesForKeys: nil
    ).map(\.lastPathComponent).sorted()

    #expect(delegate.configuration.layoutGroups.count == 3)
    #expect(persistedConfiguration.layoutGroups.count == 3)
    #expect(persistedConfiguration.layoutGroups.last?.sets == [LayoutSet(monitor: .all, layouts: [])])
    #expect(layoutFiles == ["1.grid.json", "2.grid.json", "3.grid.json"])

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func protectedGroupInfoAppearsOnlyForProtectedLayoutGroups() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-protected-group-info-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    delegate.selectSettingsTabForTesting(index: 1)

    delegate.selectLayoutsGroupForTesting(named: AppConfiguration.defaultGroupName)
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsNoteLabel))
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsProtectedGroupInfo))
    let includeDescriptionMinX = try #require(
        delegate.settingsMinXForStringForTesting(UICopy.settingsIncludeInGroupCycleDescription)
    )
    let protectedInfoMinX = try #require(
        delegate.settingsMinXForStringForTesting(UICopy.settingsProtectedGroupInfo)
    )
    #expect(includeDescriptionMinX == protectedInfoMinX)

    delegate.triggerLayoutsAddActionForTesting()
    delegate.selectLayoutsGroupForTesting(named: "Group 1")
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsNoteLabel) == false)
    #expect(delegate.settingsVisibleStringsForTesting.contains(UICopy.settingsProtectedGroupInfo) == false)

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func backgroundClickCommitsGeneralTextEditing() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-background-commit-general-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    delegate.selectSettingsTabForTesting(index: 0)

    delegate.setGeneralActivationDelayRawWithoutCommitForTesting("640")
    #expect(delegate.configuration.dragTriggers.activationDelayMilliseconds == DragTriggerSettings.defaultActivationDelayMilliseconds)

    #expect(delegate.commitSettingsEditingFromBackgroundClickForTesting(clickedInsideEditableControl: false) == true)
    #expect(delegate.configuration.dragTriggers.activationDelayMilliseconds == 640)

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func backgroundClickDoesNotCommitWhenClickStaysInsideEditableControl() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-background-no-commit-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    delegate.selectSettingsTabForTesting(index: 0)

    delegate.setGeneralActivationDelayRawWithoutCommitForTesting("640")
    #expect(delegate.commitSettingsEditingFromBackgroundClickForTesting(clickedInsideEditableControl: true) == false)
    #expect(delegate.configuration.dragTriggers.activationDelayMilliseconds == DragTriggerSettings.defaultActivationDelayMilliseconds)

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func backgroundClickCommitsLayoutsNameEditing() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-background-commit-layouts-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    delegate.selectSettingsTabForTesting(index: 1)
    delegate.selectLayoutsGroupForTesting(named: AppConfiguration.defaultGroupName)
    delegate.triggerLayoutsAddActionForTesting()
    delegate.selectLayoutsGroupForTesting(named: "Group 1")

    delegate.setLayoutsGroupNameRawWithoutCommitForTesting("work")
    #expect(delegate.layoutsDraftConfigurationForTesting?.layoutGroups.last?.name == "Group 1")

    #expect(delegate.commitSettingsEditingFromBackgroundClickForTesting(clickedInsideEditableControl: false) == true)
    #expect(delegate.layoutsDraftConfigurationForTesting?.layoutGroups.last?.name == "work")

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func layoutsSaveFromSettingsNotifiesWhenSaveFails() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-layouts-save-failure-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var receivedKind: UserNotifier.Kind?
    var receivedTitle: String?
    var receivedBody: String?
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        notifyUser: { kind, title, body in
            receivedKind = kind
            receivedTitle = title
            receivedBody = body
        }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    delegate.selectSettingsTabForTesting(index: 1)
    delegate.mutateLayoutsDraftForTesting { configuration in
        configuration.general.activeLayoutGroup = "missing-group"
    }

    delegate.saveLayoutsFromSettingsForTesting()

    #expect(receivedKind == .layoutsSaveFailed)
    #expect(receivedTitle == UICopy.layoutsSaveFailedTitle)
    #expect(receivedBody?.contains("missing-group") == true)
    #expect(delegate.configuration.general.activeLayoutGroup == AppConfiguration.defaultGroupName)
    #expect(delegate.layoutsDraftConfigurationForTesting?.general.activeLayoutGroup == "missing-group")

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func layoutsTabReflectsExternalActiveGroupChangesImmediately() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-layouts-active-group-sync-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    delegate.selectSettingsTabForTesting(index: 1)

    #expect(delegate.layoutsSettingsActiveGroupNameForTesting == AppConfiguration.defaultGroupName)
    _ = try #require(delegate.cycleToNextLayoutGroupForTesting())
    #expect(delegate.layoutsSettingsActiveGroupNameForTesting == AppConfiguration.fullscreenGroupName)

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func settingsImmediateApplyDoesNotPersistLayoutsDraftChanges() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-immediate-apply-layout-boundary-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    delegate.selectSettingsTabForTesting(index: 1)
    delegate.mutateLayoutsDraftForTesting { configuration in
        configuration.layoutGroups.append(LayoutGroup(name: "Draft", includeInGroupCycle: false, sets: []))
        configuration.general.activeLayoutGroup = "Draft"
    }

    delegate.selectSettingsTabForTesting(index: 0)
    delegate.setGeneralEnabledFromSettingsForTesting(false)

    let persistedConfiguration = try store.load()
    let settingsDraft = try #require(delegate.layoutsDraftConfigurationForTesting)

    #expect(delegate.configuration.general.isEnabled == false)
    #expect(delegate.configuration.layoutGroups.contains(where: { $0.name == "Draft" }) == false)
    #expect(persistedConfiguration.layoutGroups.contains(where: { $0.name == "Draft" }) == false)
    #expect(settingsDraft.layoutGroups.contains(where: { $0.name == "Draft" }))
    #expect(settingsDraft.general.activeLayoutGroup == "Draft")

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func closingSettingsWindowDiscardsUnsavedLayoutsDraft() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-close-discards-layout-draft-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()
    delegate.selectSettingsTabForTesting(index: 1)
    delegate.mutateLayoutsDraftForTesting { configuration in
        configuration.layoutGroups.append(LayoutGroup(name: "Draft", includeInGroupCycle: false, sets: []))
    }

    #expect(delegate.layoutsDraftConfigurationForTesting?.layoutGroups.contains(where: { $0.name == "Draft" }) == true)

    delegate.closeSettingsWindowForTesting()
    delegate.showSettings()

    #expect(delegate.layoutsDraftConfigurationForTesting?.layoutGroups.contains(where: { $0.name == "Draft" }) == false)
    #expect(delegate.configuration.layoutGroups.contains(where: { $0.name == "Draft" }) == false)

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func menuBarConfigurationChangesRefreshOpenSettingsImmediately() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-live-sync-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    delegate.showSettings()

    #expect(delegate.generalSettingsEnabledStateForTesting == true)

    #expect(delegate.updateGlobalEnabledStateForTesting(false) == true)
    #expect(delegate.generalSettingsEnabledStateForTesting == false)

    delegate.closeSettingsWindowForTesting()
    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateKeepsCurrentConfigurationWhenManualReloadFails() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-notify-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.isEnabled = false
    savedConfiguration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
    try store.save(savedConfiguration)
    var receivedKind: UserNotifier.Kind?
    var receivedTitle: String?
    var receivedBody: String?
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        notifyUser: { kind, title, body in
            receivedKind = kind
            receivedTitle = title
            receivedBody = body
        }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)

    try FileManager.default.removeItem(at: store.lastKnownGoodFileURL)
    try """
    {
      "general": {
        "isEnabled":
    """.write(to: store.fileURL, atomically: true, encoding: .utf8)
    let expectedResult = try store.loadWithStatus()

    delegate.reloadConfigurationFromDisk(mode: .manual)

    #expect(expectedResult.source == .builtInDefault)
    #expect(delegate.configuration.general == savedConfiguration.general)
    #expect(delegate.configuration.layoutGroups == savedConfiguration.layoutGroups)
    #expect(delegate.configuration.hotkeys.bindings.map(\.shortcut) == savedConfiguration.hotkeys.bindings.map(\.shortcut))
    #expect(delegate.configuration.hotkeys.bindings.map(\.action) == savedConfiguration.hotkeys.bindings.map(\.action))
    #expect(receivedKind == .configReloadFailed)
    #expect(receivedTitle == UICopy.configReloadFailedTitle)
    #expect(receivedBody == UICopy.configReloadFailedBody(diagnostic: expectedResult.diagnostic, skippedLayoutDiagnostics: expectedResult.skippedLayoutDiagnostics))
}

@MainActor
@Test func appDelegateWarnsWhenManualReloadSkipsInvalidLayoutFiles() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-partial-reload-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    _ = try store.load()

    try """
    {
      "name": "default",
      "sets": [
        {
          "monitor": "all",
          "layouts": [
            {
              "name": "Modified default",
              "gridColumns": 12,
              "gridRows": 6,
              "windowSelection": { "x": 0, "y": 0, "w": 12, "h": 6 }
            }
          ]
        }
      ]
    }
    """.write(
        to: store.layoutDirectoryURL.appendingPathComponent("1.grid.json"),
        atomically: true,
        encoding: .utf8
    )
    try """
    {
      "name":
    """.write(
        to: store.layoutDirectoryURL.appendingPathComponent("2.grid.json"),
        atomically: true,
        encoding: .utf8
    )

    var receivedKind: UserNotifier.Kind?
    var receivedTitle: String?
    var receivedBody: String?
    let invalidLayoutURL = store.layoutDirectoryURL.appendingPathComponent("2.grid.json")
    let invalidLayoutTextBeforeReload = try String(contentsOf: invalidLayoutURL, encoding: .utf8)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        currentMonitorMapProvider: { ["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"] },
        notifyUser: { kind, title, body in
            receivedKind = kind
            receivedTitle = title
            receivedBody = body
        }
    )

    let expectedResult = try store.loadWithStatus()
    delegate.reloadConfigurationFromDisk(mode: .manual)

    #expect(expectedResult.source == .persistedConfiguration)
    #expect(expectedResult.skippedLayoutDiagnostics.count == 1)
    #expect(delegate.configuration.layoutGroupNames() == ["default"])
    #expect(delegate.configuration.layouts.map(\.name) == ["Modified default"])
    #expect(delegate.configuration.monitors == ["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"])
    #expect(receivedKind == .configReloadSkippedLayouts)
    #expect(receivedTitle == UICopy.configReloadSkippedLayoutsTitle)
    #expect(receivedBody?.contains("2.grid.json") == true)
    #expect(FileManager.default.fileExists(atPath: invalidLayoutURL.path))
    #expect(try String(contentsOf: invalidLayoutURL, encoding: .utf8) == invalidLayoutTextBeforeReload)
}

@MainActor
@Test func appDelegateNotifiesWhenManualReloadFullySucceeds() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-full-reload-success-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    _ = try store.load()

    try """
    {
      "name": "default",
      "sets": [
        {
          "monitor": "all",
          "layouts": [
            {
              "name": "Modified default",
              "gridColumns": 12,
              "gridRows": 6,
              "windowSelection": { "x": 0, "y": 0, "w": 12, "h": 6 }
            }
          ]
        }
      ]
    }
    """.write(
        to: store.layoutDirectoryURL.appendingPathComponent("1.grid.json"),
        atomically: true,
        encoding: .utf8
    )
    try """
    {
      "name": "fullscreen",
      "sets": [
        {
          "monitor": "all",
          "layouts": [
            {
              "name": "Fullscreen",
              "gridColumns": 12,
              "gridRows": 6,
              "windowSelection": { "x": 0, "y": 0, "w": 12, "h": 6 }
            }
          ]
        }
      ]
    }
    """.write(
        to: store.layoutDirectoryURL.appendingPathComponent("2.grid.json"),
        atomically: true,
        encoding: .utf8
    )

    var receivedKind: UserNotifier.Kind?
    var receivedTitle: String?
    var receivedBody: String?
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        notifyUser: { kind, title, body in
            receivedKind = kind
            receivedTitle = title
            receivedBody = body
        }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)
    delegate.reloadConfigurationFromDisk(mode: .manual)

    #expect(delegate.configuration.layoutGroups.count == 2)
    #expect(delegate.configuration.layouts.map(\.name).contains("Modified default"))
    #expect(receivedKind == .configReloadSucceeded)
    #expect(receivedTitle == UICopy.configReloadSucceededTitle)
    #expect(receivedBody == UICopy.configReloadSucceededBody())
}

@MainActor
@Test func appDelegateManualReloadReconcilesChangedLaunchAtLoginValue() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-manual-reload-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.launchAtLogin = false
    try store.save(savedConfiguration)

    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .disabled)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    #expect(launchAtLoginService.registerCallCount == 0)

    savedConfiguration.general.launchAtLogin = true
    try store.save(savedConfiguration)
    delegate.reloadConfigurationFromDisk(mode: .manual)

    #expect(delegate.configuration.general.launchAtLogin == true)
    #expect(launchAtLoginService.registerCallCount == 1)

    #expect(delegate.updateLaunchAtLoginEnabled(false) == true)
    #expect(launchAtLoginService.unregisterCallCount == 1)
    #expect(launchAtLoginService.currentStatus == .disabled)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateLaunchKeepsInvalidLayoutFilesWhenPartialLoadSucceeds() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-partial-reload-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    _ = try store.load()

    try """
    {
      "name": "default",
      "sets": [
        {
          "monitor": "all",
          "layouts": [
            {
              "name": "Modified default",
              "gridColumns": 12,
              "gridRows": 6,
              "windowSelection": { "x": 0, "y": 0, "w": 12, "h": 6 }
            }
          ]
        }
      ]
    }
    """.write(
        to: store.layoutDirectoryURL.appendingPathComponent("1.grid.json"),
        atomically: true,
        encoding: .utf8
    )
    let invalidLayoutURL = store.layoutDirectoryURL.appendingPathComponent("2.grid.json")
    try """
    {
      "name":
    """.write(
        to: invalidLayoutURL,
        atomically: true,
        encoding: .utf8
    )

    let invalidLayoutTextBeforeLaunch = try String(contentsOf: invalidLayoutURL, encoding: .utf8)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        currentMonitorMapProvider: { ["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"] }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)

    #expect(delegate.configuration.layoutGroupNames() == ["default"])
    #expect(delegate.configuration.layouts.map(\.name) == ["Modified default"])
    #expect(delegate.configuration.monitors == ["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"])
    #expect(FileManager.default.fileExists(atPath: invalidLayoutURL.path))
    #expect(try String(contentsOf: invalidLayoutURL, encoding: .utf8) == invalidLayoutTextBeforeLaunch)
}

@MainActor
@Test func appDelegateManualReloadFailureIncludesSkippedLayoutFileDetails() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-failed-reload-skipped-layouts-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.isEnabled = false
    try store.save(savedConfiguration)

    try writeMainConfigurationJSON(
        """
        {
          "general": {
            "isEnabled": true,
            "excludedBundleIDs": ["com.apple.Spotlight"],
            "excludedWindowTitles": [],
            "mouseButtonNumber": 3,
            "activeLayoutGroup": "missing-after-skip"
          },
          "appearance": {
            "renderTriggerAreas": false,
            "triggerOpacity": 0.2,
            "triggerGap": 2,
            "triggerStrokeColor": "#00FDFFFF",
            "renderWindowHighlight": true,
            "highlightFillOpacity": 0.20,
            "highlightStrokeWidth": 3,
            "highlightStrokeColor": "#FFFFFFEB"
          },
          "dragTriggers": {
            "enableMouseButtonDrag": true,
            "enableModifierLeftMouseDrag": true,
            "modifierGroups": [["ctrl", "cmd", "shift", "alt"]],
            "activationDelayMilliseconds": 300,
            "activationMoveThreshold": 10
          },
          "hotkeys": {
            "bindings": []
          },
          "monitors": {}
        }
        """,
        to: store
    )
    try writeLayoutFile(
        "1.grid.json",
        json: """
        {
          "name":
        """,
        to: store
    )

    var receivedKind: UserNotifier.Kind?
    var receivedTitle: String?
    var receivedBody: String?
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        notifyUser: { kind, title, body in
            receivedKind = kind
            receivedTitle = title
            receivedBody = body
        }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)
    let expectedResult = try store.loadWithStatus()

    delegate.reloadConfigurationFromDisk(mode: .manual)

    #expect(expectedResult.source == .lastKnownGood)
    #expect(expectedResult.skippedLayoutDiagnostics.count == 1)
    #expect(delegate.configuration.general == savedConfiguration.general)
    #expect(receivedKind == .configReloadFailed)
    #expect(receivedTitle == UICopy.configReloadFailedTitle)
    #expect(receivedBody == UICopy.configReloadFailedBody(diagnostic: expectedResult.diagnostic, skippedLayoutDiagnostics: expectedResult.skippedLayoutDiagnostics))
    #expect(receivedBody?.contains("1.grid.json") == true)
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
    #expect(
        delegate.visibleMenuItemDescriptorsForTesting == [
            UICopy.requestAccessibilityAccessMenuTitle,
            "|",
            UICopy.quitMenuTitle,
        ]
    )

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
    #expect(delegate.visibleMenuItemDescriptorsForTesting.contains(UICopy.enableMenuTitle))

    trustState = false
    delegate.evaluateAccessibilityState()
    #expect(promptCount == 1)
    #expect(delegate.isAccessibilityPollingActiveForTesting == true)
    #expect(delegate.accessibilityPollingIntervalForTesting == 1.0)
    #expect(
        delegate.visibleMenuItemDescriptorsForTesting == [
            UICopy.requestAccessibilityAccessMenuTitle,
            "|",
            UICopy.quitMenuTitle,
        ]
    )

    trustState = true
    delegate.evaluateAccessibilityState()
    #expect(delegate.isAccessibilityPollingActiveForTesting == false)
    #expect(delegate.visibleMenuItemDescriptorsForTesting.contains(UICopy.enableMenuTitle))
    trustState = false
    delegate.evaluateAccessibilityState()
    #expect(promptCount == 2)

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateMenuEnableLaunchAtLoginPromptsForAccessibilityWithoutSaving() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-menu-prompt-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.launchAtLogin = false
    try store.save(savedConfiguration)

    var promptCount = 0
    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .disabled)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { false },
        accessibilityPromptRequester: {
            promptCount += 1
            return false
        }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)

    #expect(delegate.updateLaunchAtLoginEnabled(true) == false)
    #expect(promptCount == 1)
    #expect(launchAtLoginService.registerCallCount == 0)
    #expect(delegate.configuration.general.launchAtLogin == false)
    #expect((try store.load()).general.launchAtLogin == false)
}

@MainActor
@Test func appDelegateRequestAccessibilityAccessMenuPromptsAgainWhileAccessIsStillMissing() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-accessibility-menu-request-\(UUID().uuidString)", isDirectory: true)
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

    #expect(promptCount == 1)
    #expect(
        delegate.visibleMenuItemDescriptorsForTesting == [
            UICopy.requestAccessibilityAccessMenuTitle,
            "|",
            UICopy.quitMenuTitle,
        ]
    )

    delegate.requestAccessibilityAccessFromMenu()

    #expect(promptCount == 2)
    #expect(
        delegate.visibleMenuItemDescriptorsForTesting == [
            UICopy.requestAccessibilityAccessMenuTitle,
            "|",
            UICopy.quitMenuTitle,
        ]
    )

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateMenuEnableLaunchAtLoginUpdatesConfigurationOnSuccess() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-menu-enable-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.launchAtLogin = false
    try store.save(savedConfiguration)

    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .disabled)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { true }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)

    #expect(delegate.updateLaunchAtLoginEnabled(true) == true)
    #expect(launchAtLoginService.registerCallCount == 1)
    #expect(delegate.configuration.general.launchAtLogin == true)
    #expect((try store.load()).general.launchAtLogin == true)

    #expect(delegate.updateLaunchAtLoginEnabled(false) == true)
    #expect(launchAtLoginService.unregisterCallCount == 1)
    #expect(launchAtLoginService.currentStatus == .disabled)
}

@MainActor
@Test func appDelegateLaunchAtLoginEnableFailureRollsConfigurationBackToFalseAndNotifies() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-enable-failure-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.launchAtLogin = true
    try store.save(savedConfiguration)

    var receivedKind: UserNotifier.Kind?
    var receivedTitle: String?
    var receivedBody: String?
    let launchAtLoginService = TestLaunchAtLoginService(
        currentStatus: .disabled,
        registerResult: .requiresApproval
    )
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { true },
        notifyUser: { kind, title, body in
            receivedKind = kind
            receivedTitle = title
            receivedBody = body
        }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

    #expect(launchAtLoginService.registerCallCount == 1)
    #expect(delegate.configuration.general.launchAtLogin == false)
    #expect((try store.load()).general.launchAtLogin == false)
    #expect(receivedKind == .launchAtLoginEnableFailed)
    #expect(receivedTitle == UICopy.launchAtLoginEnableFailedTitle)
    #expect(receivedBody == UICopy.launchAtLoginEnableFailedBody(details: "System approval is still required."))

    delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
}

@MainActor
@Test func appDelegateMenuDisableLaunchAtLoginKeepsConfigurationWhenUnregisterFails() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-disable-failure-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.launchAtLogin = true
    try store.save(savedConfiguration)

    var receivedKind: UserNotifier.Kind?
    var receivedTitle: String?
    var receivedBody: String?
    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .enabled)
    launchAtLoginService.unregisterError = TestLaunchAtLoginError(message: "permission denied")
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { true },
        notifyUser: { kind, title, body in
            receivedKind = kind
            receivedTitle = title
            receivedBody = body
        }
    )

    delegate.reloadConfigurationFromDisk(mode: .launch)

    #expect(delegate.updateLaunchAtLoginEnabled(false) == false)
    #expect(launchAtLoginService.unregisterCallCount == 1)
    #expect(delegate.configuration.general.launchAtLogin == true)
    #expect((try store.load()).general.launchAtLogin == true)
    #expect(receivedKind == .launchAtLoginDisableFailed)
    #expect(receivedTitle == UICopy.launchAtLoginDisableFailedTitle)
    #expect(receivedBody == UICopy.launchAtLoginDisableFailedBody(details: "permission denied"))
}

@MainActor
@Test func appDelegateStopsGlobalInputMonitoringWhenDisabled() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-disable-monitoring-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .disabled)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
        accessibilityStatusProvider: { true }
    )

    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    #expect(delegate.shouldMonitorGlobalInputForTesting == true)

    var disabledConfiguration = try store.load()
    disabledConfiguration.general.isEnabled = false
    try store.save(disabledConfiguration)

    delegate.reloadConfigurationFromDisk(mode: .launch)

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
    let launchAtLoginService = TestLaunchAtLoginService(currentStatus: .disabled)
    let delegate = AppDelegate(
        configurationStore: store,
        openURL: { _ in true },
        launchAtLoginService: launchAtLoginService,
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

    #expect(delegate.configuration.dragTriggers.enableMouseButtonDrag == true)
    #expect(delegate.updateMouseButtonDragEnabled(false) == false)
    #expect(delegate.configuration.dragTriggers.enableMouseButtonDrag == true)
}

@MainActor
@Test func appDelegateClearsRecordedLayoutCycleStateAfterReloadingChangedLayouts() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-layout-reset-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let delegate = AppDelegate(configurationStore: store, openURL: { _ in true })
    delegate.reloadConfigurationFromDisk(mode: .launch)

    delegate.recordLayoutIDForTesting("layout-2", windowIdentity: "window-a")
    #expect(delegate.nextLayoutIDForTesting(windowIdentity: "window-a") == "layout-3")

    var reorderedConfiguration = delegate.configuration
    reorderedConfiguration.moveLayout(id: "layout-2", to: reorderedConfiguration.layouts.count)
    try store.save(reorderedConfiguration)

    delegate.reloadConfigurationFromDisk(mode: .launch)

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
    delegate.reloadConfigurationFromDisk(mode: .launch)

    delegate.updateMouseButtonDragEnabled(false)
    delegate.updateModifierLeftMouseDragEnabled(false)
    delegate.updatePreferLayoutMode(false)

    let reloadedConfiguration = try store.load()

    #expect(delegate.configuration.dragTriggers.enableMouseButtonDrag == false)
    #expect(delegate.configuration.dragTriggers.enableModifierLeftMouseDrag == false)
    #expect(delegate.configuration.dragTriggers.preferLayoutMode == false)
    #expect(reloadedConfiguration.dragTriggers.enableMouseButtonDrag == false)
    #expect(reloadedConfiguration.dragTriggers.enableModifierLeftMouseDrag == false)
    #expect(reloadedConfiguration.dragTriggers.preferLayoutMode == false)
}
