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

    var updatedConfiguration = initialConfiguration
    updatedConfiguration.general.excludedWindowTitles = ["Test Title"]
    updatedConfiguration.appearance.triggerGap = 6
    updatedConfiguration.dragTriggers.modifierGroups = [[.alt]]

    try store.save(updatedConfiguration)
    let reloadedConfiguration = try store.load()

    #expect(reloadedConfiguration == updatedConfiguration)
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
    #expect(configuration.dragTriggers.modifierGroups == [[.ctrl, .cmd, .shift, .alt]])
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
      "renderTriggerAreas": true,
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
