import AppKit
import Testing
@testable import GridMove

@MainActor
struct GeneralSettingsViewControllerTests {
    @Test func selectableListControlUsesPreferredWidthInsteadOfRequiredMinimum() async throws {
        let control = SelectableListControlView(items: [], width: 420, showsButtons: false)

        #expect(control.preferredWidthConstraintPriorityForTesting == .defaultHigh)
    }

    @Test func settingsSelectableListCellUsesCompactFontSize() async throws {
        let cellView = makeSettingsTableCellView(
            identifier: NSUserInterfaceItemIdentifier("SelectableListCell"),
            text: "com.apple.Spotlight"
        )

        #expect(cellView.textField?.font?.pointSize == 12)
    }

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
        controller.setActivationDelayMillisecondsForTesting(120)
        controller.setModifierLeftMouseDragForTesting(false)
        controller.setPreferLayoutModeForTesting(false)
        controller.setApplyLayoutImmediatelyWhileDraggingForTesting(false)
        controller.addExcludedBundleIDForTesting("com.example.Hidden")
        controller.addExcludedWindowTitleForTesting("Floating Panel")

        #expect(state.configuration.general.isEnabled == false)
        #expect(state.configuration.general.launchAtLogin == false)
        #expect(state.configuration.dragTriggers.enableMouseButtonDrag == false)
        #expect(state.configuration.general.mouseButtonNumber == 5)
        #expect(state.configuration.dragTriggers.activationDelayMilliseconds == 120)
        #expect(state.configuration.dragTriggers.enableModifierLeftMouseDrag == false)
        #expect(state.configuration.dragTriggers.preferLayoutMode == false)
        #expect(state.configuration.dragTriggers.applyLayoutImmediatelyWhileDragging == false)
        #expect(state.configuration.general.excludedBundleIDs.contains("com.example.Hidden"))
        #expect(state.configuration.general.excludedWindowTitles.contains("Floating Panel"))
    }

    @Test func preferLayoutModeShowsStateSpecificDescription() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        #expect(controller.preferLayoutModeDescriptionForTesting == UICopy.preferLayoutModeEnabledDescription)

        controller.setPreferLayoutModeForTesting(true)

        #expect(controller.preferLayoutModeDescriptionForTesting == UICopy.preferLayoutModeEnabledDescription)
    }

    @Test func enableShowsStaticDescription() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        #expect(controller.enableDescriptionForTesting == UICopy.enableMenuDescription)

        controller.setEnabledForTesting(false)

        #expect(controller.enableDescriptionForTesting == UICopy.enableMenuDescription)
    }

    @Test func modifierGroupSheetDisablesConfirmationForEmptySelection() async throws {
        let contentView = ModifierGroupSheetContentView()

        #expect(contentView.isConfirmationEnabled == false)
        #expect(contentView.selectedModifiers.isEmpty)
    }

    @Test func exclusionSheetDisablesConfirmationForEmptyValue() async throws {
        let contentView = ExclusionEntrySheetContentView(initialKind: .bundleID)

        #expect(contentView.isConfirmationEnabled == false)

        contentView.setValueForTesting("com.example.App")
        #expect(contentView.isConfirmationEnabled == true)

        contentView.setValueForTesting("   ")
        #expect(contentView.isConfirmationEnabled == false)
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

    @Test func generalSettingsShowsPersistedActivationDelayMilliseconds() async throws {
        var configuration = AppConfiguration.defaultValue
        configuration.dragTriggers.activationDelayMilliseconds = 640
        let state = SettingsPrototypeState(configuration: configuration)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        #expect(controller.activationDelayMillisecondsValueForTesting == 640)
    }

    @Test func generalSettingsNormalizesInvalidActivationDelayInputToDefault() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.setRawActivationDelayMillisecondsForTesting("invalid")

        #expect(state.configuration.dragTriggers.activationDelayMilliseconds == DragTriggerSettings.defaultActivationDelayMilliseconds)
        #expect(controller.activationDelayMillisecondsValueForTesting == DragTriggerSettings.defaultActivationDelayMilliseconds)
    }

    @Test func generalSettingsDoesNotWriteEmptyExclusionValues() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.submitExclusionForTesting(kind: .bundleID, value: "   ")
        controller.submitExclusionForTesting(kind: .windowTitle, value: "")

        #expect(state.configuration.general.excludedBundleIDs == AppConfiguration.defaultValue.general.excludedBundleIDs)
        #expect(state.configuration.general.excludedWindowTitles == AppConfiguration.defaultValue.general.excludedWindowTitles)
    }

    @Test func generalSettingsKeepsExclusionSelectionWhenRemovalFails() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.addExcludedBundleIDForTesting("com.example.Hidden")
        recorder.applySucceeds = false

        controller.removeSelectedExclusionForTesting()

        #expect(state.configuration.general.excludedBundleIDs.contains("com.example.Hidden"))
        #expect(controller.selectedExcludedBundleIDIndexForTesting == 1)
        #expect(controller.selectedExcludedWindowTitleIndexForTesting == nil)
        #expect(controller.isExclusionRemoveEnabledForTesting == true)
    }

    @Test func generalSettingsShowsPersistedMouseButtonNumberAboveFive() async throws {
        var configuration = AppConfiguration.defaultValue
        configuration.general.mouseButtonNumber = 6
        let state = SettingsPrototypeState(configuration: configuration)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        #expect(controller.mouseButtonNumberValueForTesting == 6)
    }

    @Test func generalSettingsNormalizesInvalidMouseButtonNumberInputToThree() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.setRawMouseButtonNumberForTesting("invalid")

        #expect(state.configuration.general.mouseButtonNumber == GeneralSettings.defaultMouseButtonNumber)
        #expect(controller.mouseButtonNumberValueForTesting == GeneralSettings.defaultMouseButtonNumber)
    }

    @Test func generalSettingsMouseButtonNumberDoesNotWrapBelowMinimum() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        let controller = GeneralSettingsViewController(
            prototypeState: state,
            actionHandler: recorder.makeActionHandler()
        )
        controller.loadViewIfNeeded()

        controller.setMouseButtonNumberForTesting(GeneralSettings.defaultMouseButtonNumber)
        controller.decrementMouseButtonNumberForTesting()

        #expect(state.configuration.general.mouseButtonNumber == GeneralSettings.defaultMouseButtonNumber)
        #expect(controller.mouseButtonNumberValueForTesting == GeneralSettings.defaultMouseButtonNumber)
    }
}
