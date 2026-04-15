import Foundation
import Testing
@testable import GridMove

@MainActor
@Test func settingsViewModelExposesFiveSidebarSections() async throws {
    #expect(SettingsViewModel.Section.allCases.count == 5)
    #expect(SettingsViewModel.Section.allCases.last == .about)
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
