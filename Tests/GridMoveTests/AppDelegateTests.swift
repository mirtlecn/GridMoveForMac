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
            name: "built-in",
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
        "Apply Fullscreen main",
        "Apply Main left 1/2",
        "Apply Main right 1/2",
        "Apply Fullscreen other",
    ])
    #expect(layoutActions == [
        .applyLayoutByID(layoutID: "layout-12"),
        .applyLayoutByID(layoutID: "layout-13"),
        .applyLayoutByID(layoutID: "layout-14"),
        .applyLayoutByID(layoutID: "layout-16"),
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
    #expect(layoutActionItems.map(\.title).contains("Apply Fill all screen (Menu bar)") == false)
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
      "name": "built-in",
      "sets": [
        {
          "monitor": "all",
          "layouts": [
            {
              "name": "Modified built-in",
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
    #expect(delegate.configuration.layoutGroupNames() == ["built-in"])
    #expect(delegate.configuration.layouts.map(\.name) == ["Modified built-in"])
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
      "name": "built-in",
      "sets": [
        {
          "monitor": "all",
          "layouts": [
            {
              "name": "Modified built-in",
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
    #expect(delegate.configuration.layouts.map(\.name).contains("Modified built-in"))
    #expect(receivedKind == .configReloadSucceeded)
    #expect(receivedTitle == UICopy.configReloadSucceededTitle)
    #expect(receivedBody == UICopy.configReloadSucceededBody())
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
      "name": "built-in",
      "sets": [
        {
          "monitor": "all",
          "layouts": [
            {
              "name": "Modified built-in",
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

    #expect(delegate.configuration.layoutGroupNames() == ["built-in"])
    #expect(delegate.configuration.layouts.map(\.name) == ["Modified built-in"])
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
            "triggerStrokeColor": "#007AFF33",
            "renderWindowHighlight": true,
            "highlightFillOpacity": 0.08,
            "highlightStrokeWidth": 3,
            "highlightStrokeColor": "#FFFFFFEB"
          },
          "dragTriggers": {
            "enableMouseButtonDrag": true,
            "enableModifierLeftMouseDrag": true,
            "modifierGroups": [["ctrl", "cmd", "shift", "alt"]],
            "activationDelaySeconds": 0.3,
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
