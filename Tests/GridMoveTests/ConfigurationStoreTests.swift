import Foundation
import Testing
@testable import GridMove

@Test func configurationStoreWritesDefaultPlistAndCanReload() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-tests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)

    let initialConfiguration = try store.load()
    #expect(initialConfiguration.layouts.count == 10)
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

    let hasAltCommaLayoutBinding = configuration.hotkeys.bindings.contains { binding in
        binding.shortcut == KeyboardShortcut(modifiers: [.alt], key: ",")
            && binding.action == .applyLayout(layoutID: "layout-8")
    }
    let hasFullscreenOrCloseBinding = configuration.hotkeys.bindings.contains { binding in
        let key = binding.shortcut.key
        return key == "/" || key == "x"
    }

    #expect(hasAltCommaLayoutBinding)
    #expect(!hasFullscreenOrCloseBinding)
    #expect(configuration.dragTriggers.modifierGroups == [[.ctrl, .cmd, .shift, .alt], [.alt]])
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
