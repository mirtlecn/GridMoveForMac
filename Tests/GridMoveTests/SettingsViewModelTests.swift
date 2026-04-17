import Foundation
import Testing
@testable import GridMove

@MainActor
@Test func settingsViewModelExposesFiveSidebarSections() async throws {
    #expect(SettingsViewModel.Section.allCases.count == 5)
    #expect(SettingsViewModel.Section.allCases.last == .about)
    #expect(SettingsViewModel.Section.appearance.title == "Appearance")
    #expect(UICopy.layoutMenuName(name: "Center", fallbackIdentifier: "layout_1") == "Center")
    #expect(UICopy.layoutMenuName(name: "   ", fallbackIdentifier: "layout_1") == "layout_1")
}

@MainActor
@Test func settingsCopyUsesSentenceCaseForVisibleLabels() async throws {
    #expect(UICopy.pressAndDragSectionTitle == "Press and drag")
    #expect(UICopy.middleMouseTitle == "Middle mouse")
    #expect(UICopy.modifierLeftMouseTitle == "Modifier + left mouse")
    #expect(UICopy.hotkeysHelpText == "To change a shortcut, double-click the key combination, then type a new shortcut.")
    #expect(UICopy.applyNextLayout == "Apply next layout")
    #expect(UICopy.applyPreviousLayout == "Apply previous layout")
    #expect(UICopy.windowOverlayTitle == "Window overlay")
    #expect(UICopy.triggerOverlayTitle == "Trigger overlay")
    #expect(UICopy.resetToDefaults == "Reset to defaults")
    #expect(UICopy.onboardingTitle == "Accessibility access is required")
    #expect(UICopy.requestAccessibilityAccess == "Request accessibility access")
    #expect(UICopy.openAccessibilitySettings == "Open accessibility settings")
    #expect(UICopy.typeShortcut == "Type shortcut")
    #expect(UICopy.notSet == "Not set")
    #expect(UICopy.notInCycle == "Not in cycle")
    #expect(UICopy.windowTitle == "Window title")
    #expect(UICopy.defaultLayoutNames[7] == "Right 1/3 top")
    #expect(UICopy.defaultLayoutNames[10] == "Fill all screen (Menu bar)")
    #expect(UICopy.applyLayout("Center") == "Apply Center")
}

@MainActor
@Test func settingsViewModelHotkeyActionOptionsUseSentenceCaseCycleLabels() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    #expect(viewModel.hotkeyActionOptions.contains(where: { $0.0 == "Apply next layout" && $0.1 == .cycleNext }))
    #expect(viewModel.hotkeyActionOptions.contains(where: { $0.0 == "Apply previous layout" && $0.1 == .cyclePrevious }))
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

@MainActor
@Test func settingsViewModelAddsLayoutAndOpensDetailEditor() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    let initialCount = viewModel.configuration.layouts.count
    viewModel.addLayout()

    #expect(viewModel.configuration.layouts.count == initialCount + 1)
    #expect(viewModel.layoutPageMode == .detail)
    #expect(viewModel.layoutDraft?.name == "")
    #expect(viewModel.selectedLayoutDisplayID == "layout_12")
}

@MainActor
@Test func settingsViewModelFormatsLayoutDisplayLabels() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    var configuration = AppConfiguration.defaultValue
    configuration.layouts[0].name = ""
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { configuration },
        onConfigurationSaved: { _ in }
    )

    #expect(viewModel.layoutItems[0].title == "layout_1")
    #expect(viewModel.layoutItems[1].title == "layout_2: Left 1/2")
}

@MainActor
@Test func settingsViewModelTracksLayoutDraftChangesAndSave() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    viewModel.openLayoutDetail(id: AppConfiguration.defaultValue.layouts[0].id)
    #expect(viewModel.hasUnsavedLayoutChanges == false)

    viewModel.updateLayoutDraft { $0.name = "Primary" }
    #expect(viewModel.hasUnsavedLayoutChanges == true)

    viewModel.saveLayoutDraft()
    #expect(viewModel.hasUnsavedLayoutChanges == false)
    #expect(viewModel.configuration.layouts[0].name == "Primary")
    #expect(viewModel.layoutPageMode == .list)
}

@MainActor
@Test func settingsViewModelKeepsLayoutsToolbarNavigationSemantics() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    let layoutID = AppConfiguration.defaultValue.layouts[0].id
    viewModel.navigateToSection(.layouts)
    viewModel.openLayoutDetail(id: layoutID)

    #expect(viewModel.layoutPageMode == .detail)
    #expect(viewModel.canNavigateToLayoutDetail == false)

    viewModel.showLayoutsList()

    #expect(viewModel.layoutPageMode == .list)
    #expect(viewModel.canNavigateToLayoutDetail == true)

    viewModel.reopenLayoutDetail()

    #expect(viewModel.layoutPageMode == .detail)
    #expect(viewModel.selectedLayoutID == layoutID)
}

@MainActor
@Test func settingsViewModelReordersLayoutsAndUpdatesDisplayOrder() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    let movedLayoutID = viewModel.configuration.layouts[2].id
    let targetLayoutID = viewModel.configuration.layouts[0].id
    viewModel.moveLayout(id: movedLayoutID, before: targetLayoutID)

    #expect(viewModel.configuration.layouts.first?.id == movedLayoutID)
    #expect(viewModel.layoutItems.first?.title == "layout_1: Left 2/3")
}

@MainActor
@Test func settingsViewModelDeletesLayoutWithConfirmation() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    let initialCount = viewModel.configuration.layouts.count
    viewModel.openLayoutDetail(id: AppConfiguration.defaultValue.layouts[0].id)
    viewModel.deleteSelectedLayout()

    #expect(viewModel.layoutDeleteArmed == true)
    #expect(viewModel.configuration.layouts.count == initialCount)

    viewModel.deleteSelectedLayout()

    #expect(viewModel.layoutDeleteArmed == false)
    #expect(viewModel.layoutPageMode == .list)
    #expect(viewModel.configuration.layouts.count == initialCount - 1)
}

@MainActor
@Test func settingsViewModelUpdatesGridDraftValues() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("codex-gridmove-settings-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = ConfigurationStore(baseDirectoryURL: temporaryDirectory)
    let viewModel = SettingsViewModel(
        configurationStore: store,
        configurationProvider: { AppConfiguration.defaultValue },
        onConfigurationSaved: { _ in }
    )

    viewModel.openLayoutDetail(id: AppConfiguration.defaultValue.layouts[0].id)
    viewModel.updateLayoutDraft {
        $0.gridColumns = 10
        $0.gridRows = 5
    }

    #expect(viewModel.layoutDraft?.gridColumns == 10)
    #expect(viewModel.layoutDraft?.gridRows == 5)
}
