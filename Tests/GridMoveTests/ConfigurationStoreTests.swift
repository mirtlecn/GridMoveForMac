import Foundation
import Testing
@testable import GridMove

@Test func configurationStoreWritesDefaultJSONAndCanReload() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let initialConfiguration = try store.load()
    #expect(initialConfiguration.layouts.count == 11)
    #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
    #expect(store.fileURL.lastPathComponent == "config.json")
    let initialText = try String(contentsOf: store.fileURL, encoding: .utf8)
    #expect(initialText.contains("\"triggerStrokeColor\""))
    #expect(initialText.contains("#007AFF33"))
    #expect(initialText.contains("\"highlightStrokeColor\""))
    #expect(initialText.contains("#FFFFFFEB"))
    #expect(initialText.contains("\"renderTriggerAreas\""))
    #expect(initialText.contains("false"))
    #expect(!initialText.contains("\"id\":"))
    #expect(initialText.contains("\"layout\""))
    #expect(initialText.contains("4"))
    #expect(initialText.contains("\"includeInCycle\""))
    #expect(initialText.contains("false"))
    #expect(initialText.contains("\"preferLayoutMode\""))
    #expect(initialText.contains("true"))
    #expect(!initialText.contains("//"))

    var updatedConfiguration = initialConfiguration
    updatedConfiguration.general.excludedWindowTitles = ["Test Title"]
    updatedConfiguration.appearance.triggerGap = 6
    updatedConfiguration.dragTriggers.preferLayoutMode = false
    updatedConfiguration.dragTriggers.modifierGroups = [[.alt]]

    try store.save(updatedConfiguration)
    let reloadedConfiguration = try store.load()

    #expect(reloadedConfiguration.general == updatedConfiguration.general)
    #expect(reloadedConfiguration.appearance.triggerGap == updatedConfiguration.appearance.triggerGap)
    #expect(reloadedConfiguration.dragTriggers.preferLayoutMode == updatedConfiguration.dragTriggers.preferLayoutMode)
    #expect(reloadedConfiguration.dragTriggers.modifierGroups == updatedConfiguration.dragTriggers.modifierGroups)
    #expect(reloadedConfiguration.layouts.map(\.name) == updatedConfiguration.layouts.map(\.name))
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

@Test func configurationStoreLoadsPureJSONWithoutUserVisibleIDs() async throws {
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
        "excludedWindowTitles": []
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
              "kind": "applyLayout",
              "layout": 2
            }
          }
        ]
      },
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
          "includeInCycle": true
        },
        {
          "name": "Center",
          "gridColumns": 12,
          "gridRows": 6,
          "windowSelection": { "x": 3, "y": 1, "w": 6, "h": 4 },
          "triggerRegion": {
            "kind": "menuBar",
            "menuBarSelection": { "x": 1, "w": 4 }
          },
          "includeInCycle": false
        }
      ]
    }
    """

    try json.write(to: store.fileURL, atomically: true, encoding: .utf8)
    let configuration = try store.load()

    #expect(configuration.layouts.map(\.id) == ["layout-1", "layout-2"])
    #expect(configuration.hotkeys.bindings.map(\.id) == ["binding-1"])
    #expect(configuration.hotkeys.bindings[0].action == .applyLayout(layoutID: "layout-2"))
    #expect(configuration.dragTriggers.preferLayoutMode == true)
    #expect(configuration.layouts[1].includeInCycle == false)
    #expect(configuration.appearance.triggerStrokeColor.hexString == "#007AFF33")
    #expect(configuration.appearance.highlightStrokeColor.hexString == "#FFFFFFEB")
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
        "excludedWindowTitles": []
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
    let hasAltLayoutBinding = configuration.hotkeys.bindings.contains { binding in
        binding.shortcut?.modifiers == [.alt]
    }
    let hasHyperLayoutFourBinding = configuration.hotkeys.bindings.contains { binding in
        binding.shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "\\")
            && binding.action == .applyLayout(layoutID: "layout-4")
    }
    let hasFullscreenOrCloseBinding = configuration.hotkeys.bindings.contains { binding in
        guard let key = binding.shortcut?.key else {
            return false
        }
        return key == "/" || key == "x"
    }

    #expect(cycleBindings.count == 2)
    #expect(configuration.general.isEnabled)
    #expect(cycleBindings.contains {
        $0.shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "l")
            && $0.action == .cycleNext
    })
    #expect(cycleBindings.contains {
        $0.shortcut == KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "j")
            && $0.action == .cyclePrevious
    })
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
      "excludedWindowTitles": []
    }
    """

    let data = try #require(json.data(using: .utf8))
    let settings = try JSONDecoder().decode(GeneralSettings.self, from: data)

    #expect(settings.isEnabled)
    #expect(settings.excludedBundleIDs == ["com.apple.Spotlight"])
    #expect(settings.excludedWindowTitles.isEmpty)
}

@Test func removingLayoutAlsoRemovesDirectBindingsForThatLayout() async throws {
    var configuration = AppConfiguration.defaultValue

    configuration.removeLayout(id: "layout-8")

    #expect(!configuration.layouts.contains(where: { $0.id == "layout-8" }))
    #expect(!configuration.hotkeys.bindings.contains {
        if case let .applyLayout(layoutID) = $0.action {
            return layoutID == "layout-8"
        }
        return false
    })
    #expect(configuration.hotkeys.bindings.contains(where: { $0.action == .cycleNext }))
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

@Test func hotkeyActionRoundTripsThroughJSON() async throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let applyLayout = HotkeyAction.applyLayout(layoutID: "layout-4")
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
