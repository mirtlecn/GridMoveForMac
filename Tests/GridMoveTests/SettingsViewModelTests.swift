import Foundation
import Testing
@testable import GridMove

@MainActor
@Test func settingsViewModelExposesFiveSidebarSections() async throws {
    #expect(SettingsViewModel.Section.allCases.count == 5)
    #expect(SettingsViewModel.Section.allCases.last == .about)
    #expect(SettingsViewModel.Section.appearance.title == "Appearance")
}

@MainActor
@Test func settingsViewModelAddsAndRemovesExcludedWindows() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    viewModel.addExcludedWindow(kind: .bundleID, value: "com.example.Test")
    viewModel.addExcludedWindow(kind: .windowTitle, value: "Sample Window")

    #expect(viewModel.configuration.general.excludedBundleIDs.contains("com.example.Test"))
    #expect(viewModel.configuration.general.excludedWindowTitles.contains("Sample Window"))
    #expect(viewModel.excludedWindowItems.count == 3)

    viewModel.selectedExcludedWindowID = viewModel.excludedWindowItems.first(where: { $0.value == "Sample Window" })?.id
    viewModel.removeSelectedExcludedWindow()

    #expect(!viewModel.configuration.general.excludedWindowTitles.contains("Sample Window"))
}

@MainActor
@Test func settingsViewModelAddsAndRemovesModifierGroups() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    let initialCount = viewModel.modifierGroupItems.count
    viewModel.addModifierGroup([.cmd, .shift])

    #expect(viewModel.modifierGroupItems.count == initialCount + 1)
    #expect(viewModel.modifierGroupItems.contains(where: { $0.keys == [.cmd, .shift] }))

    viewModel.selectedModifierGroupID = viewModel.modifierGroupItems.first(where: { $0.keys == [.cmd, .shift] })?.id
    viewModel.removeSelectedModifierGroup()

    #expect(viewModel.modifierGroupItems.count == initialCount)
    #expect(!viewModel.modifierGroupItems.contains(where: { $0.keys == [.cmd, .shift] }))
}

@MainActor
@Test func settingsViewModelTracksSectionNavigationHistory() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    #expect(viewModel.selectedSection == .general)
    #expect(viewModel.canNavigateBack == false)
    #expect(viewModel.canNavigateForward == false)

    viewModel.navigateToSection(.layouts)
    viewModel.navigateToSection(.hotkeys)

    #expect(viewModel.selectedSection == .hotkeys)
    #expect(viewModel.canNavigateBack == true)
    #expect(viewModel.canNavigateForward == false)

    viewModel.navigateBack()
    #expect(viewModel.selectedSection == .layouts)
    #expect(viewModel.canNavigateForward == true)

    viewModel.navigateForward()
    #expect(viewModel.selectedSection == .hotkeys)
}

@MainActor
@Test func settingsViewModelResetsAppearanceTabsToDefaults() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    viewModel.updateAppearance {
        $0.renderTriggerAreas = false
        $0.triggerOpacity = 0.7
        $0.triggerGap = 9
        $0.renderWindowHighlight = false
        $0.highlightFillOpacity = 0.5
        $0.highlightStrokeWidth = 8
    }

    viewModel.resetTriggerAppearanceToDefaults()
    #expect(viewModel.configuration.appearance.renderTriggerAreas == AppConfiguration.defaultValue.appearance.renderTriggerAreas)
    #expect(viewModel.configuration.appearance.triggerOpacity == AppConfiguration.defaultValue.appearance.triggerOpacity)
    #expect(viewModel.configuration.appearance.triggerGap == AppConfiguration.defaultValue.appearance.triggerGap)

    viewModel.resetWindowAppearanceToDefaults()
    #expect(viewModel.configuration.appearance.renderWindowHighlight == AppConfiguration.defaultValue.appearance.renderWindowHighlight)
    #expect(viewModel.configuration.appearance.highlightFillOpacity == AppConfiguration.defaultValue.appearance.highlightFillOpacity)
    #expect(viewModel.configuration.appearance.highlightStrokeWidth == AppConfiguration.defaultValue.appearance.highlightStrokeWidth)
}

@MainActor
@Test func settingsViewModelAddsSelectableEmptyHotkeyBinding() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    let initialCount = viewModel.hotkeyItems.count
    viewModel.addHotkeyBinding()

    #expect(viewModel.hotkeyItems.count == initialCount + 1)
    #expect(viewModel.hotkeyItems.first?.shortcut == nil)
    #expect(viewModel.selectedHotkeyBindingID == viewModel.hotkeyItems.first?.id)
}
