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

@Test func configurationStoreWritesDefaultJSONAndCanReload() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let initialConfiguration = try store.load()
    #expect(initialConfiguration.general.activeLayoutGroup == AppConfiguration.defaultGroupName)
    #expect(initialConfiguration.layoutGroups.count == 2)
    #expect(initialConfiguration.layoutGroups[0].sets.count == 1)
    #expect(initialConfiguration.layouts.count == 11)
    #expect(initialConfiguration.layoutGroupNames() == [AppConfiguration.defaultGroupName, AppConfiguration.fullscreenGroupName])
    #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
    #expect(FileManager.default.fileExists(atPath: store.layoutDirectoryURL.path))
    #expect(FileManager.default.fileExists(atPath: store.lastKnownGoodFileURL.path))
    #expect(FileManager.default.fileExists(atPath: store.lastKnownGoodLayoutDirectoryURL.path))

    let initialText = try String(contentsOf: store.fileURL, encoding: .utf8)
    #expect(initialText.contains("\"activeLayoutGroup\""))
    #expect(initialText.contains("\"launchAtLogin\""))
    #expect(initialText.contains("\"mouseButtonNumber\""))
    #expect(initialText.contains("\"triggerHighlightMode\""))
    #expect(initialText.contains("\"triggerFillOpacity\""))
    #expect(initialText.contains("\"triggerStrokeWidth\""))
    #expect(initialText.contains("\"applyLayoutByIndex\""))
    #expect(!initialText.contains("\"layoutGroups\""))
    #expect(!initialText.contains("\"includeInCycle\""))
    #expect(!initialText.contains("\"id\":"))
    #expect(!initialText.contains("//"))

    let layoutFiles = try FileManager.default.contentsOfDirectory(
        at: store.layoutDirectoryURL,
        includingPropertiesForKeys: nil
    )
    .map(\.lastPathComponent)
    .sorted()
    #expect(layoutFiles == ["1.grid.json", "2.grid.json"])

    let firstLayoutText = try String(
        contentsOf: store.layoutDirectoryURL.appendingPathComponent("1.grid.json"),
        encoding: .utf8
    )
    let secondLayoutText = try String(
        contentsOf: store.layoutDirectoryURL.appendingPathComponent("2.grid.json"),
        encoding: .utf8
    )
    #expect(firstLayoutText.contains("\"name\""))
    #expect(firstLayoutText.contains(AppConfiguration.defaultGroupName))
    #expect(firstLayoutText.contains("\"includeInGroupCycle\""))
    #expect(secondLayoutText.contains(AppConfiguration.fullscreenGroupName))
    #expect(secondLayoutText.contains("\"monitor\""))

    var updatedConfiguration = initialConfiguration
    updatedConfiguration.general.launchAtLogin = false
    updatedConfiguration.general.excludedWindowTitles = ["Test Title"]
    updatedConfiguration.general.activeLayoutGroup = AppConfiguration.defaultGroupName
    updatedConfiguration.appearance.triggerGap = 6
    updatedConfiguration.appearance.layoutGap = 4
    updatedConfiguration.dragTriggers.preferLayoutMode = false
    updatedConfiguration.dragTriggers.modifierGroups = [[.alt]]
    updatedConfiguration.monitors = ["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"]

    try store.save(updatedConfiguration)
    let reloadedConfiguration = try store.load()

    #expect(reloadedConfiguration.general == updatedConfiguration.general)
    #expect(reloadedConfiguration.general.mouseButtonNumber == updatedConfiguration.general.mouseButtonNumber)
    #expect(reloadedConfiguration.appearance.triggerGap == updatedConfiguration.appearance.triggerGap)
    #expect(reloadedConfiguration.appearance.layoutGap == updatedConfiguration.appearance.layoutGap)
    #expect(reloadedConfiguration.dragTriggers.preferLayoutMode == updatedConfiguration.dragTriggers.preferLayoutMode)
    #expect(
        reloadedConfiguration.dragTriggers.applyLayoutImmediatelyWhileDragging
            == updatedConfiguration.dragTriggers.applyLayoutImmediatelyWhileDragging
    )
    #expect(reloadedConfiguration.dragTriggers.modifierGroups == updatedConfiguration.dragTriggers.modifierGroups)
    #expect(reloadedConfiguration.monitors == updatedConfiguration.monitors)
    #expect(reloadedConfiguration.layouts.map(\.id) == (1...updatedConfiguration.layouts.count).map { "layout-\($0)" })
    #expect(reloadedConfiguration.hotkeys.bindings.map(\.id) == (1...updatedConfiguration.hotkeys.bindings.count).map { "binding-\($0)" })
}

@Test func configurationStoreIgnoresUnknownFieldsInMainAndLayoutFiles() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-unknown-fields-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    try writeMainConfigurationJSON(
        """
        {
          "general": {
            "isEnabled": true,
            "launchAtLogin": false,
            "excludedBundleIDs": [],
            "excludedWindowTitles": [],
            "activeLayoutGroup": "work",
            "mouseButtonNumber": 3
          },
          "appearance": {
            "triggerHighlightMode": "none",
            "triggerFillOpacity": 0.08,
            "triggerGap": 2,
            "triggerStrokeWidth": 2,
            "triggerStrokeColor": "#00FDFFFF",
            "layoutGap": 1,
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
          "monitors": {},
          "unusedRootField": 1
        }
        """,
        to: store
    )
    try writeLayoutFile(
        "1.grid.json",
        json: """
        {
          "name": "work",
          "includeInGroupCycle": false,
          "protect": false,
          "sets": [],
          "unusedLayoutField": "ignored"
        }
        """,
        to: store
    )

    let configuration = try store.load()
    #expect(configuration.general.activeLayoutGroup == "work")
    #expect(configuration.layoutGroups.map(\.name) == ["work"])
}

@Test func defaultConfigurationMarksBuiltInGroupsAsProtected() async throws {
    let defaultConfiguration = AppConfiguration.defaultValue

    #expect(defaultConfiguration.layoutGroups.first(where: { $0.name == AppConfiguration.defaultGroupName })?.protect == true)
    #expect(defaultConfiguration.layoutGroups.first(where: { $0.name == AppConfiguration.fullscreenGroupName })?.protect == true)
}

@Test func configurationStoreDecodesMissingAndInvalidProtectAsFalse() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-protect-default-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let mainJSON = """
    {
      "general": {
        "isEnabled": true,
        "excludedBundleIDs": [],
        "excludedWindowTitles": [],
        "launchAtLogin": true,
        "mouseButtonNumber": 3,
        "activeLayoutGroup": "work"
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
    """

    let missingProtectJSON = """
    {
      "name": "work",
      "includeInGroupCycle": false,
      "sets": []
    }
    """

    let invalidProtectJSON = """
    {
      "name": "play",
      "protect": "yes",
      "includeInGroupCycle": false,
      "sets": []
    }
    """

    try writeMainConfigurationJSON(mainJSON.replacingOccurrences(of: "\"work\"", with: "\"play\"", options: [], range: nil), to: store)
    try writeLayoutFile("1.grid.json", json: missingProtectJSON, to: store)
    try writeLayoutFile("2.grid.json", json: invalidProtectJSON, to: store)

    let configuration = try store.load()

    #expect(configuration.layoutGroups.first(where: { $0.name == "work" })?.protect == false)
    #expect(configuration.layoutGroups.first(where: { $0.name == "play" })?.protect == false)
}

@Test func configurationStoreDecodesMissingAndInvalidLaunchAtLoginAsFalse() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-launch-at-login-default-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let baseJSON = """
    {
      "general": {
        "isEnabled": true,
        "excludedBundleIDs": [],
        "excludedWindowTitles": [],
        "mouseButtonNumber": 3,
        "activeLayoutGroup": "work"
      },
      "appearance": {
        "renderTriggerAreas": false,
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
    """

    let invalidLaunchAtLoginJSON = baseJSON.replacingOccurrences(
        of: "\"mouseButtonNumber\": 3,",
        with: "\"launchAtLogin\": \"yes\",\n        \"mouseButtonNumber\": 3,"
    )

    try writeMainConfigurationJSON(baseJSON, to: store)
    try writeLayoutFile(
        "1.grid.json",
        json: """
        {
          "name": "work",
          "includeInGroupCycle": false,
          "sets": []
        }
        """,
        to: store
    )
    #expect((try store.load()).general.launchAtLogin == false)

    try writeMainConfigurationJSON(invalidLaunchAtLoginJSON, to: store)
    #expect((try store.load()).general.launchAtLogin == false)
}

@Test func configurationStoreSavesEmptyGroupsAndSetsWithSequentialManagedFiles() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-empty-layout-groups-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var configuration = AppConfiguration.defaultValue
    configuration.layoutGroups.append(
        LayoutGroup(name: "empty-group", includeInGroupCycle: false, sets: [])
    )
    configuration.layoutGroups.append(
        LayoutGroup(name: "empty-set-group", includeInGroupCycle: false, sets: [LayoutSet(monitor: .all, layouts: [])])
    )
    configuration.general.activeLayoutGroup = AppConfiguration.defaultGroupName

    try store.save(configuration)

    let reloadedConfiguration = try store.load()
    let layoutFiles = try FileManager.default.contentsOfDirectory(
        at: store.layoutDirectoryURL,
        includingPropertiesForKeys: nil
    ).map(\.lastPathComponent).sorted()

    #expect(reloadedConfiguration.layoutGroups.map(\.name) == [
        AppConfiguration.defaultGroupName,
        AppConfiguration.fullscreenGroupName,
        "empty-group",
        "empty-set-group",
    ])
    #expect(reloadedConfiguration.layoutGroups[2].sets.isEmpty)
    #expect(reloadedConfiguration.layoutGroups[3].sets == [LayoutSet(monitor: .all, layouts: [])])
    #expect(layoutFiles == ["1.grid.json", "2.grid.json", "3.grid.json", "4.grid.json"])
}

@Test func configurationStoreReturnsBuiltInDefaultAndDiagnosticForBrokenJSONWithoutRecoverySnapshot() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-invalid-json-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let invalidJSON = """
    {
      "general": {
        "isEnabled": true,
    """
    try writeMainConfigurationJSON(invalidJSON, to: store)

    let result = try store.loadWithStatus()
    let reloadedText = try String(contentsOf: store.fileURL, encoding: .utf8)

    #expect(result.source == .builtInDefault)
    #expect(result.configuration == .defaultValue)
    #expect(result.diagnostic != nil)
    #expect(result.diagnostic?.line != nil)
    #expect(result.diagnostic?.column != nil)
    #expect(reloadedText == invalidJSON)
}

@Test func configurationStoreReturnsLastKnownGoodAndDiagnosticForBrokenJSON() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-last-known-good-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var savedConfiguration = AppConfiguration.defaultValue
    savedConfiguration.general.isEnabled = false
    savedConfiguration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
    try store.save(savedConfiguration)

    try """
    {
      "general": {
        "isEnabled":
    """.write(to: store.fileURL, atomically: true, encoding: .utf8)

    let result = try store.loadWithStatus()

    #expect(result.source == .lastKnownGood)
    #expect(result.configuration.general.isEnabled == false)
    #expect(result.configuration.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
    #expect(result.diagnostic != nil)
    #expect(result.diagnostic?.line != nil)
    #expect(result.diagnostic?.column != nil)
}

@Test func configurationStoreLoadsPureJSONWithGroupsAndOptionalTriggers() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-pure-json-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let mainJSON = """
    {
      "general": {
        "isEnabled": true,
        "excludedBundleIDs": ["com.apple.Spotlight"],
        "excludedWindowTitles": [],
        "mouseButtonNumber": 3,
        "activeLayoutGroup": "work"
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
        "modifierGroups": [["ctrl", "cmd", "shift", "alt"], ["ctrl", "shift", "alt"]],
        "activationDelayMilliseconds": 300,
        "activationMoveThreshold": 10
      },
      "hotkeys": {
        "bindings": [
          {
            "isEnabled": true,
            "shortcut": {
              "modifiers": ["ctrl", "cmd", "shift", "alt"],
              "key": "\\\\"
            },
            "action": {
              "kind": "applyLayoutByIndex",
              "layout": 2
            }
          }
        ]
      },
      "monitors": {
        "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"
      }
    }
    """

    let layoutJSON = """
    {
      "name": "work",
      "includeInGroupCycle": false,
      "sets": [
        {
          "monitor": "main",
          "layouts": [
            {
              "name": "Left 1/3",
              "gridColumns": 12,
              "gridRows": 6,
              "windowSelection": { "x": 0, "y": 0, "w": 4, "h": 6 },
              "triggerRegion": {
                "kind": "screen",
                "gridSelection": { "x": 0, "y": 0, "w": 2, "h": 6 }
              },
              "includeInLayoutIndex": true
            },
            {
              "name": "Center",
              "gridColumns": 12,
              "gridRows": 6,
              "windowSelection": { "x": 3, "y": 1, "w": 6, "h": 4 },
              "includeInLayoutIndex": false
            }
          ]
        }
      ]
    }
    """

    try writeMainConfigurationJSON(mainJSON, to: store)
    try writeLayoutFile("1.grid.json", json: layoutJSON, to: store)
    let configuration = try store.load()

    #expect(configuration.general.activeLayoutGroup == "work")
    #expect(configuration.general.launchAtLogin == false)
    #expect(configuration.general.mouseButtonNumber == 3)
    #expect(configuration.layoutGroups[0].includeInGroupCycle == false)
    #expect(configuration.layouts.map(\.id) == ["layout-1", "layout-2"])
    #expect(configuration.hotkeys.bindings.map(\.id) == ["binding-1"])
    #expect(configuration.hotkeys.bindings[0].action == .applyLayoutByIndex(layout: 2))
    #expect(configuration.dragTriggers.preferLayoutMode == true)
    #expect(configuration.dragTriggers.applyLayoutImmediatelyWhileDragging == false)
    #expect(configuration.layouts[1].triggerRegion == nil)
    #expect(configuration.layouts[1].includeInLayoutIndex == false)
    #expect(configuration.layouts[0].includeInMenu == true)
    #expect(configuration.layouts[1].includeInMenu == true)
    #expect(configuration.monitors == ["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4": "Built-in Retina Display"])
    #expect(configuration.appearance.triggerStrokeColor.hexString == "#00FDFFFF")
    #expect(configuration.appearance.highlightStrokeColor.hexString == "#FFFFFFEB")
}

@Test func configurationStoreAllowsDuplicateLayoutNamesWithinOneGroup() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-duplicate-layout-names-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let mainJSON = """
    {
      "general": {
        "isEnabled": true,
        "excludedBundleIDs": ["com.apple.Spotlight"],
        "excludedWindowTitles": [],
        "mouseButtonNumber": 3,
        "activeLayoutGroup": "work"
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
    """

    let layoutJSON = """
    {
      "name": "work",
      "sets": [
        {
          "monitor": "main",
          "layouts": [
            {
              "name": "Center",
              "gridColumns": 12,
              "gridRows": 6,
              "windowSelection": { "x": 0, "y": 0, "w": 6, "h": 6 }
            },
            {
              "name": "Center",
              "gridColumns": 12,
              "gridRows": 6,
              "windowSelection": { "x": 6, "y": 0, "w": 6, "h": 6 }
            }
          ]
        }
      ]
    }
    """

    try writeMainConfigurationJSON(mainJSON, to: store)
    try writeLayoutFile("1.grid.json", json: layoutJSON, to: store)
    let result = try store.loadWithStatus()

    #expect(result.source == .persistedConfiguration)
    #expect(result.diagnostic == nil)
    #expect(result.configuration.general.activeLayoutGroup == "work")
    #expect(result.configuration.layoutGroups[0].includeInGroupCycle == true)
    #expect(result.configuration.layoutGroups[0].sets[0].layouts.map(\.name) == ["Center", "Center"])
}

@Test func dragTriggerSettingsDecodeMissingAndInvalidImmediateApplyDefaultsToFalse() async throws {
    let missingFieldJSON = """
    {
      "enableMouseButtonDrag": true,
      "enableModifierLeftMouseDrag": true,
      "preferLayoutMode": true,
      "modifierGroups": [["ctrl", "cmd", "shift", "alt"]],
      "activationDelayMilliseconds": 300,
      "activationMoveThreshold": 10
    }
    """
    let invalidFieldJSON = """
    {
      "enableMouseButtonDrag": true,
      "enableModifierLeftMouseDrag": true,
      "preferLayoutMode": true,
      "applyLayoutImmediatelyWhileDragging": "invalid",
      "modifierGroups": [["ctrl", "cmd", "shift", "alt"]],
      "activationDelayMilliseconds": 300,
      "activationMoveThreshold": 10
    }
    """

    let decoder = JSONDecoder()
    let missingFieldSettings = try decoder.decode(DragTriggerSettings.self, from: Data(missingFieldJSON.utf8))
    let invalidFieldSettings = try decoder.decode(DragTriggerSettings.self, from: Data(invalidFieldJSON.utf8))

    #expect(missingFieldSettings.applyLayoutImmediatelyWhileDragging == false)
    #expect(invalidFieldSettings.applyLayoutImmediatelyWhileDragging == false)
}

@Test func configurationStoreRejectsCommentedJSON() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-comment-json-reject-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let json = """
    {
      // comments are not allowed
      "general": {
        "isEnabled": true,
        "excludedBundleIDs": ["com.apple.Spotlight"],
        "excludedWindowTitles": [],
        "activeLayoutGroup": "default"
      }
    }
    """

    try writeMainConfigurationJSON(json, to: store)
    let result = try store.loadWithStatus()

    #expect(result.source == .builtInDefault)
    #expect(result.configuration == .defaultValue)
    #expect(result.diagnostic != nil)
    #expect(result.diagnostic?.line != nil)
    #expect(result.diagnostic?.column != nil)
}

@Test func configurationStoreIgnoresNonMatchingLayoutFilesAndSortsManagedFilesNumerically() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-layout-order-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    try writeMainConfigurationJSON(
        """
        {
          "general": {
            "isEnabled": true,
            "excludedBundleIDs": ["com.apple.Spotlight"],
            "excludedWindowTitles": [],
            "mouseButtonNumber": 3,
            "activeLayoutGroup": "two"
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
        "10.grid.json",
        json: """
        {
          "name": "ten",
          "sets": [
            {
              "monitor": "all",
              "layouts": [
                {
                  "name": "Ten",
                  "gridColumns": 12,
                  "gridRows": 6,
                  "windowSelection": { "x": 0, "y": 0, "w": 12, "h": 6 }
                }
              ]
            }
          ]
        }
        """,
        to: store
    )
    try writeLayoutFile(
        "2.grid.json",
        json: """
        {
          "name": "two",
          "sets": [
            {
              "monitor": "all",
              "layouts": [
                {
                  "name": "Two",
                  "gridColumns": 12,
                  "gridRows": 6,
                  "windowSelection": { "x": 0, "y": 0, "w": 12, "h": 6 }
                }
              ]
            }
          ]
        }
        """,
        to: store
    )
    try writeLayoutFile("notes.json", json: "{\"ignored\":true}", to: store)
    try writeLayoutFile("03.grid.json", json: "{\"ignored\":true}", to: store)

    let configuration = try store.load()

    #expect(configuration.layoutGroupNames() == ["two", "ten"])
    #expect(
        configuration.layoutGroups.flatMap { group in
            group.sets.flatMap(\.layouts).map(\.name)
        } == ["Two", "Ten"]
    )
}

@Test func configurationStoreSkipsInvalidLayoutFilesWhenMergedConfigurationRemainsValid() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-skip-invalid-layout-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    try writeMainConfigurationJSON(
        """
        {
          "general": {
            "isEnabled": true,
            "excludedBundleIDs": ["com.apple.Spotlight"],
            "excludedWindowTitles": [],
            "mouseButtonNumber": 3,
            "activeLayoutGroup": "work"
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
          "name": "work",
          "sets": [
            {
              "monitor": "all",
              "layouts": [
                {
                  "name": "Valid",
                  "gridColumns": 12,
                  "gridRows": 6,
                  "windowSelection": { "x": 0, "y": 0, "w": 12, "h": 6 }
                }
              ]
            }
          ]
        }
        """,
        to: store
    )
    try writeLayoutFile(
        "2.grid.json",
        json: """
        {
          "name":
        """,
        to: store
    )

    let result = try store.loadWithStatus()

    #expect(result.source == .persistedConfiguration)
    #expect(result.diagnostic == nil)
    #expect(result.skippedLayoutDiagnostics.count == 1)
    #expect(result.skippedLayoutDiagnostics[0].fileURL.lastPathComponent == "2.grid.json")
    #expect(result.configuration.layoutGroupNames() == ["work"])
}

@Test func configurationStoreFallsBackWhenSkippingInvalidLayoutFilesBreaksValidation() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-invalid-layout-breaks-validation-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

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

    let result = try store.loadWithStatus()

    #expect(result.source == .builtInDefault)
    #expect(result.configuration == .defaultValue)
    #expect(result.diagnostic?.message.contains("missing layout group") == true)
    #expect(result.skippedLayoutDiagnostics.count == 1)
    #expect(result.skippedLayoutDiagnostics[0].fileURL.lastPathComponent == "1.grid.json")
}

@Test func configurationStoreRejectsLegacyEmbeddedLayoutGroupsInConfigJSON() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-legacy-layoutgroups-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

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
            "modifierGroups": [["ctrl", "cmd", "shift", "alt"]],
            "activationDelayMilliseconds": 300,
            "activationMoveThreshold": 10
          },
          "hotkeys": {
            "bindings": []
          },
          "layoutGroups": [],
          "monitors": {}
        }
        """,
        to: store
    )

    let result = try store.loadWithStatus()

    #expect(result.source == .builtInDefault)
    #expect(result.configuration == .defaultValue)
    #expect(result.diagnostic?.message.contains("must not contain embedded layoutGroups") == true)
}

@Test func configurationStoreSaveRewritesManagedLayoutFilesAndPreservesUnmanagedFiles() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-rewrite-layout-files-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    _ = try store.load()
    try writeLayoutFile("3.grid.json", json: "{\"stale\":true}", to: store)
    try writeLayoutFile("custom-note.json", json: "{\"keep\":true}", to: store)

    var configuration = AppConfiguration.defaultValue
    configuration.layoutGroups = [configuration.layoutGroups[0]]
    configuration.general.activeLayoutGroup = AppConfiguration.defaultGroupName

    try store.save(configuration)

    let layoutFiles = try FileManager.default.contentsOfDirectory(
        at: store.layoutDirectoryURL,
        includingPropertiesForKeys: nil
    )
    .map(\.lastPathComponent)
    .sorted()

    #expect(layoutFiles == ["1.grid.json", "custom-note.json"])
}

@Test func configurationStoreReportsFilesystemErrorsForUnreadableManagedLayoutEntries() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-layout-read-error-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    try writeMainConfigurationJSON(
        """
        {
          "general": {
            "isEnabled": true,
            "excludedBundleIDs": ["com.apple.Spotlight"],
            "excludedWindowTitles": [],
            "mouseButtonNumber": 3,
            "activeLayoutGroup": "work"
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
    try FileManager.default.createDirectory(
        at: store.layoutDirectoryURL.appendingPathComponent("1.grid.json"),
        withIntermediateDirectories: true
    )
    try writeLayoutFile(
        "2.grid.json",
        json: """
        {
          "name": "work",
          "sets": [
            {
              "monitor": "all",
              "layouts": [
                {
                  "name": "Valid",
                  "gridColumns": 12,
                  "gridRows": 6,
                  "windowSelection": { "x": 0, "y": 0, "w": 12, "h": 6 }
                }
              ]
            }
          ]
        }
        """,
        to: store
    )

    let expectedMessage: String
    do {
        _ = try Data(contentsOf: store.layoutDirectoryURL.appendingPathComponent("1.grid.json"))
        Issue.record("Expected reading a directory as a file to fail.")
        return
    } catch {
        expectedMessage = error.localizedDescription
    }

    let result = try store.loadWithStatus()

    #expect(result.source == .persistedConfiguration)
    #expect(result.skippedLayoutDiagnostics.count == 1)
    #expect(result.skippedLayoutDiagnostics[0].fileURL.lastPathComponent == "1.grid.json")
    #expect(result.skippedLayoutDiagnostics[0].message == expectedMessage)
    #expect(result.skippedLayoutDiagnostics[0].line == nil)
    #expect(result.skippedLayoutDiagnostics[0].column == nil)
}

@Test func configurationStoreRestoresManagedLayoutFilesWhenConfigWriteFails() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-save-rollback-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    _ = try store.load()
    try writeLayoutFile("3.grid.json", json: "{\"stale\":true}", to: store)

    let layoutFile1URL = store.layoutDirectoryURL.appendingPathComponent("1.grid.json")
    let layoutFile2URL = store.layoutDirectoryURL.appendingPathComponent("2.grid.json")
    let layoutFile3URL = store.layoutDirectoryURL.appendingPathComponent("3.grid.json")
    let layoutFile1TextBeforeSave = try String(contentsOf: layoutFile1URL, encoding: .utf8)
    let layoutFile2TextBeforeSave = try String(contentsOf: layoutFile2URL, encoding: .utf8)
    let layoutFile3TextBeforeSave = try String(contentsOf: layoutFile3URL, encoding: .utf8)

    try FileManager.default.removeItem(at: store.fileURL)
    try FileManager.default.createDirectory(at: store.fileURL, withIntermediateDirectories: true)

    var configuration = AppConfiguration.defaultValue
    configuration.layoutGroups = [configuration.layoutGroups[0]]
    configuration.general.activeLayoutGroup = AppConfiguration.defaultGroupName

    do {
        try store.save(configuration)
        Issue.record("Expected save to fail when config.json is replaced by a directory.")
    } catch {
        let layoutFiles = try FileManager.default.contentsOfDirectory(
            at: store.layoutDirectoryURL,
            includingPropertiesForKeys: nil
        )
        .map(\.lastPathComponent)
        .sorted()

        #expect(layoutFiles == ["1.grid.json", "2.grid.json", "3.grid.json"])
        #expect(try String(contentsOf: layoutFile1URL, encoding: .utf8) == layoutFile1TextBeforeSave)
        #expect(try String(contentsOf: layoutFile2URL, encoding: .utf8) == layoutFile2TextBeforeSave)
        #expect(try String(contentsOf: layoutFile3URL, encoding: .utf8) == layoutFile3TextBeforeSave)
    }
}

@Test func defaultConfigurationKeepsExpectedShortcutAndModifierDefaults() async throws {
    let configuration = AppConfiguration.defaultValue

    let cycleBindings = configuration.hotkeys.bindings.filter {
        $0.action == .cycleNext || $0.action == .cyclePrevious
    }
    let hasAltLayoutBinding = configuration.hotkeys.bindings.contains(where: { binding in
        binding.shortcut?.modifiers == [.alt]
    })
    let hasHyperLayoutFourBinding = configuration.hotkeys.bindings.contains(where: { binding in
        binding.shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "\\")
            && binding.action == .applyLayoutByIndex(layout: 4)
    })
    let hasFullscreenOrCloseBinding = configuration.hotkeys.bindings.contains(where: { binding in
        guard let key = binding.shortcut?.key else {
            return false
        }
        return key == "/" || key == "x"
    })

    #expect(cycleBindings.count == 2)
    #expect(configuration.general.isEnabled)
    #expect(configuration.general.activeLayoutGroup == AppConfiguration.defaultGroupName)
    #expect(configuration.layoutGroups.count == 2)
    #expect(configuration.layoutGroups[0].includeInGroupCycle == true)
    #expect(configuration.layoutGroups[0].sets.count == 1)
    #expect(configuration.layoutGroups[0].sets[0].monitor == .all)
    #expect(configuration.layoutGroups[1].name == AppConfiguration.fullscreenGroupName)
    #expect(configuration.layoutGroups[1].includeInGroupCycle == true)
    #expect(configuration.layoutGroups[1].sets.map(\.monitor) == [.main, .all])
    #expect(configuration.layoutGroups[1].sets[0].layouts.map(\.name) == [
        "Fullscreen main",
        "Main left 1/2",
        "Main right 1/2",
        "Fullscreen main (menu bar)",
    ])
    #expect(configuration.layoutGroups[1].sets[1].layouts.map(\.name) == [
        "Fullscreen other",
        "Fullscreen other (menu bar)",
    ])
    #expect(configuration.layoutGroups[0].sets[0].layouts[10].includeInLayoutIndex == false)
    #expect(configuration.layoutGroups[0].sets[0].layouts[10].includeInMenu == false)
    #expect(configuration.layoutGroups[1].sets[0].layouts[3].includeInLayoutIndex == false)
    #expect(configuration.layoutGroups[1].sets[0].layouts[3].includeInMenu == false)
    #expect(configuration.layoutGroups[1].sets[1].layouts[1].includeInLayoutIndex == false)
    #expect(configuration.layoutGroups[1].sets[1].layouts[1].includeInMenu == false)
    #expect(!hasAltLayoutBinding)
    #expect(hasHyperLayoutFourBinding)
    #expect(!hasFullscreenOrCloseBinding)
    #expect(configuration.dragTriggers.preferLayoutMode == true)
    #expect(configuration.dragTriggers.modifierGroups == [[.ctrl, .cmd, .shift, .alt], [.ctrl, .shift, .alt]])
    #expect(configuration.appearance.renderTriggerAreas == false)
    #expect(configuration.appearance.triggerGap == 0)
    #expect(configuration.appearance.triggerStrokeColor.hexString == "#00FDFFFF")
}

@MainActor
@Test func emptyModifierGroupDoesNotMatchPlainLeftClick() async throws {
    #expect(
        DragGridController.matchesAnyModifierGroup(
            flags: [],
            groups: [[]]
        ) == false
    )
    #expect(
        DragGridController.matchesAnyModifierGroup(
            flags: [],
            groups: [[.ctrl, .cmd, .shift, .alt]]
        ) == false
    )
    #expect(
        DragGridController.matchesAnyModifierGroup(
            flags: [.ctrl, .cmd, .shift, .alt],
            groups: [[], [.ctrl, .cmd, .shift, .alt]]
        ) == true
    )
}

@Test func hotkeySettingsReturnsFirstConfiguredShortcutForAction() async throws {
    let settings = HotkeySettings(bindings: [
        ShortcutBinding(isEnabled: true, shortcut: nil, action: .cycleNext),
        ShortcutBinding(isEnabled: false, shortcut: KeyboardShortcut(modifiers: [.alt], key: "l"), action: .cycleNext),
        ShortcutBinding(isEnabled: true, shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "l"), action: .cycleNext),
        ShortcutBinding(isEnabled: true, shortcut: KeyboardShortcut(modifiers: [.alt], key: "j"), action: .cyclePrevious),
    ])

    #expect(settings.firstShortcut(for: .cycleNext) == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "l"))
    #expect(settings.firstShortcut(for: .cyclePrevious) == KeyboardShortcut(modifiers: [.alt], key: "j"))
}

@Test func keyboardShortcutProvidesMenuShortcutComponents() async throws {
    let standardShortcut = KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "\\")
    let returnShortcut = KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "return")
    let functionShortcut = KeyboardShortcut(modifiers: [.cmd], key: "f1")
    let keypadShortcut = KeyboardShortcut(modifiers: [.cmd], key: "keypad1")
    let insertShortcut = KeyboardShortcut(modifiers: [.cmd], key: "insert")

    #expect(standardShortcut.menuKeyEquivalent == "\\")
    #expect(standardShortcut.menuModifierMask == [.control, .option, .shift, .command])
    #expect(returnShortcut.menuKeyEquivalent == "\r")
    #expect(functionShortcut.menuKeyEquivalent.count == 1)
    #expect(keypadShortcut.menuKeyEquivalent == "1")
    #expect(insertShortcut.menuKeyEquivalent.count == 1)
}

@Test func shortcutKeyMapSupportsNumberRowFunctionKeysAndKeypad() async throws {
    let numberKeyCode = try #require(ShortcutKeyMap.keyCode(for: "1"))
    let functionKeyCode = try #require(ShortcutKeyMap.keyCode(for: "f1"))
    let keypadKeyCode = try #require(ShortcutKeyMap.keyCode(for: "keypad1"))
    let insertKeyCode = try #require(ShortcutKeyMap.keyCode(for: "insert"))

    #expect(ShortcutKeyMap.keyCode(for: "kp1") == keypadKeyCode)
    #expect(ShortcutKeyMap.keyCode(for: "enter") == ShortcutKeyMap.keyCode(for: "return"))
    #expect(ShortcutKeyMap.keyCode(for: "backspace") == ShortcutKeyMap.keyCode(for: "delete"))
    #expect(ShortcutKeyMap.keyCode(for: "pageup") == ShortcutKeyMap.keyCode(for: "pageUp"))
    #expect(ShortcutKeyMap.keyCode(for: "pgup") == ShortcutKeyMap.keyCode(for: "pageUp"))
    #expect(ShortcutKeyMap.keyCode(for: "pgdn") == ShortcutKeyMap.keyCode(for: "pageDown"))
    #expect(ShortcutKeyMap.keyCode(for: "help") == insertKeyCode)
    #expect(ShortcutKeyMap.keyCode(for: "ins") == insertKeyCode)

    #expect(ShortcutKeyMap.keyName(for: numberKeyCode) == "1")
    #expect(ShortcutKeyMap.keyName(for: functionKeyCode) == "f1")
    #expect(ShortcutKeyMap.keyName(for: keypadKeyCode) == "keypad1")
    #expect(ShortcutKeyMap.keyName(for: try #require(ShortcutKeyMap.keyCode(for: "pageUp"))) == "pageUp")
    #expect(ShortcutKeyMap.keyName(for: insertKeyCode) == "insert")
}

@Test func generalSettingsDecodeMissingEnableFlagWithDefaultValue() async throws {
    let json = """
    {
      "excludedBundleIDs": ["com.apple.Spotlight"],
      "excludedWindowTitles": [],
      "activeLayoutGroup": "default"
    }
    """

    let data = try #require(json.data(using: .utf8))
    let settings = try JSONDecoder().decode(GeneralSettings.self, from: data)

    #expect(settings.isEnabled)
    #expect(settings.mouseButtonNumber == 3)
    #expect(settings.activeLayoutGroup == "default")
    #expect(settings.excludedBundleIDs == ["com.apple.Spotlight"])
    #expect(settings.excludedWindowTitles.isEmpty)
}

@Test func generalSettingsDecodeInvalidMouseButtonNumberFallsBackToDefaultValue() async throws {
    let invalidValueJSON = """
    {
      "isEnabled": true,
      "excludedBundleIDs": [],
      "excludedWindowTitles": [],
      "mouseButtonNumber": 2,
      "activeLayoutGroup": "default"
    }
    """
    let invalidTypeJSON = """
    {
      "isEnabled": true,
      "excludedBundleIDs": [],
      "excludedWindowTitles": [],
      "mouseButtonNumber": "side",
      "activeLayoutGroup": "default"
    }
    """

    let invalidValueData = try #require(invalidValueJSON.data(using: .utf8))
    let invalidTypeData = try #require(invalidTypeJSON.data(using: .utf8))

    let invalidValueSettings = try JSONDecoder().decode(GeneralSettings.self, from: invalidValueData)
    let invalidTypeSettings = try JSONDecoder().decode(GeneralSettings.self, from: invalidTypeData)

    #expect(invalidValueSettings.mouseButtonNumber == 3)
    #expect(invalidTypeSettings.mouseButtonNumber == 3)
}

@Test func removingLayoutAlsoRemovesDirectBindingsForThatLayout() async throws {
    var configuration = AppConfiguration.defaultValue

    configuration.removeLayout(id: "layout-8")

    #expect(!configuration.layouts.contains(where: { $0.id == "layout-8" }))
    #expect(!configuration.hotkeys.bindings.contains(where: { $0.action == .applyLayoutByIndex(layout: 8) }))
    #expect(configuration.hotkeys.bindings.contains(where: { $0.action == .cycleNext }))
}

@Test func removingLastIndexedLayoutDoesNotCrashAndShiftsBindings() async throws {
    var configuration = AppConfiguration.defaultValue

    configuration.removeLayout(id: "layout-10")

    #expect(!configuration.layouts.contains(where: { $0.id == "layout-10" }))
    #expect(!configuration.hotkeys.bindings.contains(where: { $0.action == .applyLayoutByIndex(layout: 10) }))
    #expect(!configuration.hotkeys.bindings.contains(where: { $0.action == .applyLayoutByIndex(layout: 9) }))
    #expect(configuration.layouts.last?.id == "layout-11")
}

@Test func removingLayoutExcludedFromIndexesLeavesDirectBindingsUnchanged() async throws {
    var configuration = AppConfiguration.defaultValue
    let bindingsBeforeRemoval = configuration.hotkeys.bindings

    configuration.removeLayout(id: "layout-11")

    #expect(!configuration.layouts.contains(where: { $0.id == "layout-11" }))
    #expect(configuration.hotkeys.bindings == bindingsBeforeRemoval)
}

@Test func removingLayoutFromMultiSetGroupKeepsOtherSetsIntact() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName

    let otherSetLayoutIDsBeforeRemoval = try #require(configuration.activeGroup?.sets.last?.layouts.map(\.id))

    configuration.removeLayout(id: "layout-13")

    let activeGroup = try #require(configuration.activeGroup)
    #expect(activeGroup.sets[0].layouts.map(\.id) == ["layout-12", "layout-14", "layout-15"])
    #expect(activeGroup.sets[1].layouts.map(\.id) == otherSetLayoutIDsBeforeRemoval)
}

@Test func movingLayoutInsideSameSetDoesNotCrossSetBoundaries() async throws {
    var configuration = AppConfiguration.defaultValue
    configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName

    configuration.moveLayout(id: "layout-14", to: 1)

    let reorderedGroup = try #require(configuration.activeGroup)
    #expect(reorderedGroup.sets[0].layouts.map(\.id) == ["layout-12", "layout-14", "layout-13", "layout-15"])
    #expect(reorderedGroup.sets[1].layouts.map(\.id) == ["layout-16", "layout-17"])

    configuration.moveLayout(id: "layout-14", to: configuration.layouts.count)

    let unchangedGroup = try #require(configuration.activeGroup)
    #expect(unchangedGroup.sets[0].layouts.map(\.id) == ["layout-12", "layout-14", "layout-13", "layout-15"])
    #expect(unchangedGroup.sets[1].layouts.map(\.id) == ["layout-16", "layout-17"])
}

@Test func appearanceSettingsDecodeMissingTriggerStrokeColorWithDefaultValue() async throws {
    let json = """
    {
      "triggerHighlightMode": "none",
      "triggerFillOpacity": 0.08,
      "triggerGap": 2,
      "renderWindowHighlight": true,
      "highlightFillOpacity": 0.20,
      "highlightStrokeWidth": 3,
      "highlightStrokeColor": {
        "red": 1,
        "green": 1,
        "blue": 1,
        "alpha": 0.92
      }
    }
    """

    let data = try #require(json.data(using: .utf8))
    let settings = try JSONDecoder().decode(AppearanceSettings.self, from: data)

    #expect(settings.triggerStrokeColor.hexString == "#00FDFFFF")
    #expect(settings.triggerFillOpacity == 0.08)
    #expect(settings.layoutGap == 1)
}

@Test func appearanceSettingsDecodeInvalidLayoutGapFallsBackToDefaultValue() async throws {
    let json = """
    {
      "triggerHighlightMode": "invalid",
      "triggerFillOpacity": 0.25,
      "triggerGap": 2,
      "triggerStrokeWidth": 5,
      "triggerStrokeColor": {
        "red": 0,
        "green": 0.4784313725,
        "blue": 1,
        "alpha": 0.2
      },
      "layoutGap": "invalid",
      "renderWindowHighlight": true,
      "highlightFillOpacity": 0.20,
      "highlightStrokeWidth": 3,
      "highlightStrokeColor": {
        "red": 1,
        "green": 1,
        "blue": 1,
        "alpha": 0.92
      }
    }
    """

    let data = try #require(json.data(using: .utf8))
    let settings = try JSONDecoder().decode(AppearanceSettings.self, from: data)

    #expect(settings.triggerHighlightMode == .all)
    #expect(settings.triggerFillOpacity == 0.25)
    #expect(settings.triggerStrokeWidth == 5)
    #expect(settings.layoutGap == 1)
}

@Test func appearanceConfigurationDecodeInvalidLayoutGapFallsBackToDefaultValue() async throws {
    let json = """
    {
      "triggerHighlightMode": "invalid",
      "triggerFillOpacity": 0.25,
      "triggerGap": 2,
      "triggerStrokeWidth": 4,
      "triggerStrokeColor": "#00FDFFFF",
      "layoutGap": "invalid",
      "renderWindowHighlight": true,
      "highlightFillOpacity": 0.20,
      "highlightStrokeWidth": 3,
      "highlightStrokeColor": "#FFFFFFEB"
    }
    """

    let data = try #require(json.data(using: .utf8))
    let configuration = try JSONDecoder().decode(AppearanceConfiguration.self, from: data)

    #expect(configuration.triggerHighlightMode == "all")
    #expect(configuration.triggerFillOpacity == 0.25)
    #expect(configuration.triggerStrokeWidth == 4)
    #expect(configuration.layoutGap == 1)
}

@Test func triggerRegionRoundTripsThroughJSON() async throws {
    let screenRegion = TriggerRegion.screen(GridSelection(x: 1, y: 2, w: 3, h: 4))
    let menuBarRegion = TriggerRegion.menuBar(MenuBarSelection(x: 2, w: 5))

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let screenData = try encoder.encode(screenRegion)
    let menuBarData = try encoder.encode(menuBarRegion)

    #expect(try decoder.decode(TriggerRegion.self, from: screenData) == screenRegion)
    #expect(try decoder.decode(TriggerRegion.self, from: menuBarData) == menuBarRegion)
}

@Test func layoutSetMonitorRoundTripsThroughJSON() async throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    #expect(try decoder.decode(LayoutSetMonitor.self, from: encoder.encode(LayoutSetMonitor.all)) == .all)
    #expect(try decoder.decode(LayoutSetMonitor.self, from: encoder.encode(LayoutSetMonitor.main)) == .main)
    #expect(
        try decoder.decode(
            LayoutSetMonitor.self,
            from: encoder.encode(LayoutSetMonitor.displays(["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4"]))
        ) == .displays(["f8a3198a-7f52-4f69-9f4e-9840d7ee3da4"])
    )
    #expect(
        try decoder.decode(
            LayoutSetMonitor.self,
            from: encoder.encode(
                LayoutSetMonitor.displays([
                    "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4",
                    "9b249d3c-1111-2222-3333-444455556666",
                ])
            )
        ) == .displays([
            "f8a3198a-7f52-4f69-9f4e-9840d7ee3da4",
            "9b249d3c-1111-2222-3333-444455556666",
        ])
    )
}

@Test func hotkeyActionRoundTripsThroughJSON() async throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let applyLayout = HotkeyAction.applyLayoutByIndex(layout: 4)
    let cycleNext = HotkeyAction.cycleNext
    let cyclePrevious = HotkeyAction.cyclePrevious

    #expect(try decoder.decode(HotkeyAction.self, from: encoder.encode(applyLayout)) == applyLayout)
    #expect(try decoder.decode(HotkeyAction.self, from: encoder.encode(cycleNext)) == cycleNext)
    #expect(try decoder.decode(HotkeyAction.self, from: encoder.encode(cyclePrevious)) == cyclePrevious)
}

@Test func rgbaColorSupportsHexStrings() async throws {
    let eightDigit = try RGBAColor(hexString: "#FFFFFFEB")
    let sixDigit = try RGBAColor(hexString: "#007AFF")

    #expect(eightDigit.hexString == "#FFFFFFEB")
    #expect(sixDigit.hexString == "#007AFFFF")
}
