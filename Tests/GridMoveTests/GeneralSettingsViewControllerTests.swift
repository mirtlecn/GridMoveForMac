import AppKit
import Testing
@testable import GridMove

@MainActor
struct GeneralSettingsViewControllerTests {
    @Test func generalSettingsWritesRealConfigurationFields() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.setEnabledForTesting(false)
        controller.setLaunchAtLoginForTesting(false)
        controller.setMouseButtonDragForTesting(false)
        controller.setMouseButtonNumberForTesting(5)
        controller.setModifierLeftMouseDragForTesting(false)
        controller.setPreferLayoutModeForTesting(false)
        controller.addExcludedBundleIDForTesting("com.example.Hidden")
        controller.addExcludedWindowTitleForTesting("Floating Panel")

        #expect(state.configuration.general.isEnabled == false)
        #expect(state.configuration.general.launchAtLogin == false)
        #expect(state.configuration.dragTriggers.enableMouseButtonDrag == false)
        #expect(state.configuration.general.mouseButtonNumber == 5)
        #expect(state.configuration.dragTriggers.enableModifierLeftMouseDrag == false)
        #expect(state.configuration.dragTriggers.preferLayoutMode == false)
        #expect(state.configuration.general.excludedBundleIDs.contains("com.example.Hidden"))
        #expect(state.configuration.general.excludedWindowTitles.contains("Floating Panel"))
    }

    @Test func modifierGroupSheetDisablesConfirmationForEmptySelection() async throws {
        let contentView = ModifierGroupSheetContentView()

        #expect(contentView.isConfirmationEnabled == false)
        #expect(contentView.selectedModifiers.isEmpty)
    }

    @Test func generalSettingsDeduplicatesModifierGroups() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        let existingGroup = state.configuration.dragTriggers.modifierGroups[0]
        controller.addModifierGroupForTesting(existingGroup)
        controller.addModifierGroupForTesting([.ctrl, .shift])

        #expect(state.configuration.dragTriggers.modifierGroups.filter { $0 == existingGroup }.count == 1)
        #expect(state.configuration.dragTriggers.modifierGroups.contains([.ctrl, .shift]))
    }

    @Test func generalSettingsRollsBackAfterFailedApply() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        recorder.applySucceeds = false
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.setMouseButtonNumberForTesting(5)

        #expect(state.configuration.general.mouseButtonNumber == GeneralSettings.defaultMouseButtonNumber)
    }
}
