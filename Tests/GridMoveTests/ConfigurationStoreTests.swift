import Foundation
import Testing
@testable import GridMove

@Test func configurationStoreWritesDefaultJSONAndCanReload() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let initialConfiguration = try store.load()
    #expect(initialConfiguration.general.activeLayoutGroup == AppConfiguration.builtInGroupName)
    #expect(initialConfiguration.layoutGroups.count == 2)
    #expect(initialConfiguration.layoutGroups[0].sets.count == 1)
    #expect(initialConfiguration.layouts.count == 11)
    #expect(initialConfiguration.layoutGroupNames() == [AppConfiguration.builtInGroupName, AppConfiguration.fullscreenGroupName])
    #expect(FileManager.default.fileExists(atPath: store.fileURL.path))

    let initialText = try String(contentsOf: store.fileURL, encoding: .utf8)
    #expect(initialText.contains("\"layoutGroups\""))
    #expect(initialText.contains("\"activeLayoutGroup\""))
    #expect(initialText.contains("\"applyLayoutByIndex\""))
    #expect(initialText.contains("\"includeInGroupCycle\""))
    #expect(initialText.contains("\"includeInLayoutIndex\""))
    #expect(initialText.contains("\"monitor\""))
    #expect(!initialText.contains("\"includeInCycle\""))
    #expect(!initialText.contains("\"id\":"))
    #expect(!initialText.contains("//"))

    var updatedConfiguration = initialConfiguration
    updatedConfiguration.general.excludedWindowTitles = ["Test Title"]
    updatedConfiguration.general.activeLayoutGroup = AppConfiguration.builtInGroupName
    updatedConfiguration.appearance.triggerGap = 6
    updatedConfiguration.dragTriggers.preferLayoutMode = false
    updatedConfiguration.dragTriggers.modifierGroups = [[.alt]]
    updatedConfiguration.monitors = ["Built-in Retina Display": "12345"]

    try store.save(updatedConfiguration)
    let reloadedConfiguration = try store.load()

    #expect(reloadedConfiguration.general == updatedConfiguration.general)
    #expect(reloadedConfiguration.appearance.triggerGap == updatedConfiguration.appearance.triggerGap)
    #expect(reloadedConfiguration.dragTriggers.preferLayoutMode == updatedConfiguration.dragTriggers.preferLayoutMode)
    #expect(reloadedConfiguration.dragTriggers.modifierGroups == updatedConfiguration.dragTriggers.modifierGroups)
    #expect(reloadedConfiguration.monitors == updatedConfiguration.monitors)
    #expect(reloadedConfiguration.layouts.map(\.id) == (1...updatedConfiguration.layouts.count).map { "layout-\($0)" })
    #expect(reloadedConfiguration.hotkeys.bindings.map(\.id) == (1...updatedConfiguration.hotkeys.bindings.count).map { "binding-\($0)" })
}

@Test func configurationStoreReturnsDefaultAndPreservesBrokenJSON() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-invalid-json-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

    let invalidJSON = """
    {
      "general": {
        "isEnabled": true,
    """
    try invalidJSON.write(to: store.fileURL, atomically: true, encoding: .utf8)

    let configuration = try store.load()
    let reloadedText = try String(contentsOf: store.fileURL, encoding: .utf8)

    #expect(configuration == .defaultValue)
    #expect(reloadedText == invalidJSON)
}

@Test func configurationStoreLoadsPureJSONWithGroupsAndOptionalTriggers() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-pure-json-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

    let json = """
    {
      "general": {
        "isEnabled": true,
        "excludedBundleIDs": ["com.apple.Spotlight"],
        "excludedWindowTitles": [],
        "activeLayoutGroup": "work"
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
        "middleMouseButtonNumber": 2,
        "enableMiddleMouseDrag": true,
        "enableModifierLeftMouseDrag": true,
        "modifierGroups": [["ctrl", "cmd", "shift", "alt"], ["ctrl", "shift", "alt"]],
        "activationDelaySeconds": 0.3,
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
      "layoutGroups": [
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
      ],
      "monitors": {
        "Built-in Retina Display": "12345"
      }
    }
    """

    try json.write(to: store.fileURL, atomically: true, encoding: .utf8)
    let configuration = try store.load()

    #expect(configuration.general.activeLayoutGroup == "work")
    #expect(configuration.layoutGroups[0].includeInGroupCycle == false)
    #expect(configuration.layouts.map(\.id) == ["layout-1", "layout-2"])
    #expect(configuration.hotkeys.bindings.map(\.id) == ["binding-1"])
    #expect(configuration.hotkeys.bindings[0].action == .applyLayoutByIndex(layout: 2))
    #expect(configuration.dragTriggers.preferLayoutMode == true)
    #expect(configuration.layouts[1].triggerRegion == nil)
    #expect(configuration.layouts[1].includeInLayoutIndex == false)
    #expect(configuration.layouts[0].includeInMenu == true)
    #expect(configuration.layouts[1].includeInMenu == true)
    #expect(configuration.monitors == ["Built-in Retina Display": "12345"])
    #expect(configuration.appearance.triggerStrokeColor.hexString == "#007AFF33")
    #expect(configuration.appearance.highlightStrokeColor.hexString == "#FFFFFFEB")
}

@Test func configurationStoreAllowsDuplicateLayoutNamesWithinOneGroup() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-duplicate-layout-names-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

    let json = """
    {
      "general": {
        "isEnabled": true,
        "excludedBundleIDs": ["com.apple.Spotlight"],
        "excludedWindowTitles": [],
        "activeLayoutGroup": "work"
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
        "middleMouseButtonNumber": 2,
        "enableMiddleMouseDrag": true,
        "enableModifierLeftMouseDrag": true,
        "modifierGroups": [["ctrl", "cmd", "shift", "alt"]],
        "activationDelaySeconds": 0.3,
        "activationMoveThreshold": 10
      },
      "hotkeys": {
        "bindings": []
      },
      "layoutGroups": [
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
      ],
      "monitors": {}
    }
    """

    try json.write(to: store.fileURL, atomically: true, encoding: .utf8)
    let result = try store.loadWithStatus()

    #expect(result.didFallBackToDefault == false)
    #expect(result.configuration.general.activeLayoutGroup == "work")
    #expect(result.configuration.layoutGroups[0].includeInGroupCycle == true)
    #expect(result.configuration.layoutGroups[0].sets[0].layouts.map(\.name) == ["Center", "Center"])
}

@Test func configurationStoreRejectsCommentedJSON() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-comment-json-reject-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

    let json = """
    {
      // comments are not allowed
      "general": {
        "isEnabled": true,
        "excludedBundleIDs": ["com.apple.Spotlight"],
        "excludedWindowTitles": [],
        "activeLayoutGroup": "built-in"
      }
    }
    """

    try json.write(to: store.fileURL, atomically: true, encoding: .utf8)
    let result = try store.loadWithStatus()

    #expect(result.didFallBackToDefault == true)
    #expect(result.configuration == .defaultValue)
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
    #expect(configuration.general.activeLayoutGroup == AppConfiguration.builtInGroupName)
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
    #expect(configuration.appearance.triggerStrokeColor.alpha == 0.2)
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

    #expect(standardShortcut.menuKeyEquivalent == "\\")
    #expect(standardShortcut.menuModifierMask == [.control, .option, .shift, .command])
    #expect(returnShortcut.menuKeyEquivalent == "\r")
}

@Test func generalSettingsDecodeMissingEnableFlagWithDefaultValue() async throws {
    let json = """
    {
      "excludedBundleIDs": ["com.apple.Spotlight"],
      "excludedWindowTitles": [],
      "activeLayoutGroup": "built-in"
    }
    """

    let data = try #require(json.data(using: .utf8))
    let settings = try JSONDecoder().decode(GeneralSettings.self, from: data)

    #expect(settings.isEnabled)
    #expect(settings.activeLayoutGroup == "built-in")
    #expect(settings.excludedBundleIDs == ["com.apple.Spotlight"])
    #expect(settings.excludedWindowTitles.isEmpty)
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
      "renderTriggerAreas": false,
      "triggerOpacity": 0.2,
      "triggerGap": 2,
      "renderWindowHighlight": true,
      "highlightFillOpacity": 0.08,
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

    #expect(settings.triggerStrokeColor.alpha == 0.2)
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
    #expect(try decoder.decode(LayoutSetMonitor.self, from: encoder.encode(LayoutSetMonitor.displays(["12345"]))) == .displays(["12345"]))
    #expect(try decoder.decode(LayoutSetMonitor.self, from: encoder.encode(LayoutSetMonitor.displays(["12345", "67890"]))) == .displays(["12345", "67890"]))
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
