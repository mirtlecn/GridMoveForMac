import Foundation
import Testing
@testable import GridMove

@Test func configurationStoreWritesDefaultPlistAndCanReload() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let initialConfiguration = try store.load()
    #expect(initialConfiguration.layouts.count == 11)
    #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
    #expect(store.fileURL.lastPathComponent == "config.plist")

    var updatedConfiguration = initialConfiguration
    updatedConfiguration.general.excludedWindowTitles = ["Test Title"]
    updatedConfiguration.appearance.triggerGap = 6
    updatedConfiguration.dragTriggers.modifierGroups = [[.alt]]

    try store.save(updatedConfiguration)
    let reloadedConfiguration = try store.load()

    #expect(reloadedConfiguration == updatedConfiguration)
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

@Test func generalSettingsDecodeMissingEnableFlagWithDefaultValue() async throws {
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>excludedBundleIDs</key>
      <array>
        <string>com.apple.Spotlight</string>
      </array>
      <key>excludedWindowTitles</key>
      <array/>
    </dict>
    </plist>
    """

    let data = try #require(plist.data(using: .utf8))
    let settings = try PropertyListDecoder().decode(GeneralSettings.self, from: data)

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
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>renderTriggerAreas</key>
      <true/>
      <key>triggerOpacity</key>
      <real>0.2</real>
      <key>triggerGap</key>
      <real>2</real>
      <key>renderWindowHighlight</key>
      <true/>
      <key>highlightFillOpacity</key>
      <real>0.08</real>
      <key>highlightStrokeWidth</key>
      <real>3</real>
      <key>highlightStrokeColor</key>
      <dict>
        <key>red</key>
        <real>1</real>
        <key>green</key>
        <real>1</real>
        <key>blue</key>
        <real>1</real>
        <key>alpha</key>
        <real>0.92</real>
      </dict>
    </dict>
    </plist>
    """

    let data = try #require(plist.data(using: .utf8))
    let settings = try PropertyListDecoder().decode(AppearanceSettings.self, from: data)

    #expect(settings.triggerStrokeColor.alpha == 0.2)
}
