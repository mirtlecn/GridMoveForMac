import Foundation
import Testing
@testable import GridMove

@MainActor
private func makePreferenceViewModel() -> (PreferenceViewModel, URL) {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-preference-viewmodel-\(UUID().uuidString)", isDirectory: true)
    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = PreferenceViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )
    return (viewModel, temporaryDirectory)
}

@MainActor
@Test func preferenceViewModelUpdatesGeneralToggleAndPersists() async throws {
    let (viewModel, temporaryDirectory) = makePreferenceViewModel()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    viewModel.updateGeneralEnabled(false)

    #expect(viewModel.configuration.general.isEnabled == false)
}

@MainActor
@Test func preferenceViewModelAddsHotkeyBindingFromPlaceholderRow() async throws {
    let (viewModel, temporaryDirectory) = makePreferenceViewModel()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let rowID = try #require(
        viewModel.hotkeyRows.first(where: { $0.bindingID == nil && $0.shortcut == nil })?.id
    )
    let initialCount = viewModel.configuration.hotkeys.bindings.count

    viewModel.updateHotkeyShortcut(
        id: rowID,
        shortcut: KeyboardShortcut(modifiers: [.cmd, .shift], key: "9")
    )

    #expect(viewModel.configuration.hotkeys.bindings.count == initialCount + 1)
}

@MainActor
@Test func preferenceViewModelCanAddAndDeleteExtraHotkeyRows() async throws {
    let (viewModel, temporaryDirectory) = makePreferenceViewModel()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let initialCount = viewModel.configuration.hotkeys.bindings.count
    viewModel.addHotkeyRow(defaultAction: .cycleNext)
    let extraRow = try #require(viewModel.hotkeyRows.last(where: { $0.isAdditional }))

    #expect(viewModel.configuration.hotkeys.bindings.count == initialCount + 1)

    viewModel.deleteHotkeyRow(id: extraRow.id)

    #expect(viewModel.configuration.hotkeys.bindings.count == initialCount)
}

@MainActor
@Test func preferenceViewModelBuildsOnePrimaryGroupPerAction() async throws {
    let (viewModel, temporaryDirectory) = makePreferenceViewModel()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    #expect(viewModel.hotkeyGroups.count == viewModel.allHotkeyActions.count)
    #expect(viewModel.hotkeyGroups.allSatisfy { $0.primaryRow.isAdditional == false })
}

@MainActor
@Test func preferenceViewModelClearingShortcutDisablesExistingBinding() async throws {
    let (viewModel, temporaryDirectory) = makePreferenceViewModel()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let row = try #require(viewModel.hotkeyRows.first(where: { $0.shortcut != nil }))
    let bindingID = try #require(row.bindingID)

    viewModel.updateHotkeyShortcut(id: row.id, shortcut: nil)

    let binding = try #require(viewModel.configuration.hotkeys.bindings.first(where: { $0.id == bindingID }))
    #expect(binding.shortcut == nil)
    #expect(binding.isEnabled == false)
}

@MainActor
@Test func preferenceHotkeyIconCatalogProvidesImagesForDefaultActions() async throws {
    let configuration = AppConfiguration.defaultValue

    let firstLayoutImage = PreferenceHotkeyIconCatalog.image(
        for: .applyLayout(layoutID: configuration.layouts[0].id),
        configuration: configuration
    )
    let previousImage = PreferenceHotkeyIconCatalog.image(
        for: .cyclePrevious,
        configuration: configuration
    )
    let nextImage = PreferenceHotkeyIconCatalog.image(
        for: .cycleNext,
        configuration: configuration
    )

    #expect(firstLayoutImage != nil)
    #expect(previousImage != nil)
    #expect(nextImage != nil)
}
