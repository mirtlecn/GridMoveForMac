import Foundation
import Testing
@testable import GridMove

@MainActor
private final class SettingsNotificationObserver: NSObject {
    private(set) var notificationCount = 0

    @objc
    func handleStateDidChange(_ notification: Notification) {
        notificationCount += 1
    }
}

@MainActor
struct SettingsPrototypeStateTests {
    @Test func reloadSynchronizesDraftAndCommittedConfiguration() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        var updatedConfiguration = AppConfiguration.defaultValue
        updatedConfiguration.general.mouseButtonNumber = 5

        state.reload(from: updatedConfiguration)

        #expect(state.configuration == updatedConfiguration)
        #expect(state.committedConfiguration == updatedConfiguration)
    }

    @Test func immediateApplySuccessUpdatesCommittedSnapshot() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()

        let didApply = state.applyImmediateMutation(using: recorder.makeActionHandler()) { configuration in
            configuration.general.mouseButtonNumber = 5
        }

        #expect(didApply == true)
        #expect(state.configuration.general.mouseButtonNumber == 5)
        #expect(state.committedConfiguration.general.mouseButtonNumber == 5)
        #expect(recorder.appliedCandidates.last?.general.mouseButtonNumber == 5)
    }

    @Test func immediateApplyPreservesUnsavedLayoutsDraftAndDoesNotSaveIt() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()

        state.applyLayoutsMutation { configuration in
            configuration.layoutGroups.append(LayoutGroup(name: "Draft", includeInGroupCycle: false, sets: []))
            configuration.general.activeLayoutGroup = "Draft"
        }

        let didApply = state.applyImmediateMutation(using: recorder.makeActionHandler()) { configuration in
            configuration.general.mouseButtonNumber = 5
        }

        #expect(didApply == true)
        #expect(state.configuration.general.mouseButtonNumber == 5)
        #expect(state.configuration.layoutGroups.contains(where: { $0.name == "Draft" }))
        #expect(state.configuration.general.activeLayoutGroup == "Draft")
        #expect(state.committedConfiguration.layoutGroups.contains(where: { $0.name == "Draft" }) == false)
        #expect(state.committedConfiguration.general.activeLayoutGroup == AppConfiguration.builtInGroupName)
        #expect(recorder.appliedCandidates.last?.layoutGroups.contains(where: { $0.name == "Draft" }) == false)
    }

    @Test func immediateApplyFailureRollsBackToCommittedSnapshot() async throws {
        var committedConfiguration = AppConfiguration.defaultValue
        committedConfiguration.general.mouseButtonNumber = 4
        let state = SettingsPrototypeState(configuration: committedConfiguration)
        let recorder = TestSettingsActionRecorder()
        recorder.applySucceeds = false

        let didApply = state.applyImmediateMutation(using: recorder.makeActionHandler()) { configuration in
            configuration.general.mouseButtonNumber = 5
        }

        #expect(didApply == false)
        #expect(state.configuration.general.mouseButtonNumber == 4)
        #expect(state.committedConfiguration.general.mouseButtonNumber == 4)
        #expect(recorder.appliedCandidates.last?.general.mouseButtonNumber == 5)
    }

    @Test func statePostsChangeNotificationOnReloadAndRollback() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        recorder.applySucceeds = false
        let observer = SettingsNotificationObserver()
        NotificationCenter.default.addObserver(
            observer,
            selector: #selector(SettingsNotificationObserver.handleStateDidChange(_:)),
            name: .settingsPrototypeStateDidChange,
            object: state
        )

        state.reload(from: .defaultValue)
        _ = state.applyImmediateMutation(using: recorder.makeActionHandler()) { configuration in
            configuration.general.isEnabled = false
        }

        #expect(observer.notificationCount == 2)
    }

    @Test func layoutsDraftCommitSuccessUpdatesCommittedSnapshot() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()

        state.applyLayoutsMutation { configuration in
            configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
        }

        let didCommit = state.commitLayoutsDraft(using: recorder.makeActionHandler())

        #expect(didCommit == true)
        #expect(state.configuration.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
        #expect(state.committedConfiguration.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
        #expect(recorder.savedLayoutsCandidates.last?.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
    }

    @Test func layoutsDraftCommitFailureKeepsDraftChanges() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        let recorder = TestSettingsActionRecorder()
        recorder.saveLayoutsSucceeds = false

        state.applyLayoutsMutation { configuration in
            configuration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
        }

        let didCommit = state.commitLayoutsDraft(using: recorder.makeActionHandler())

        #expect(didCommit == false)
        #expect(state.configuration.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
        #expect(state.committedConfiguration.general.activeLayoutGroup == AppConfiguration.builtInGroupName)
        #expect(state.hasLayoutsDraftChanges == true)
    }

    @Test func syncExternalConfigurationUpdatesActiveGroupWithoutOverwritingDraftLayouts() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        state.applyLayoutsMutation { configuration in
            configuration.layoutGroups.append(
                LayoutGroup(name: "Work", includeInGroupCycle: false, sets: [])
            )
        }

        var externalConfiguration = AppConfiguration.defaultValue
        externalConfiguration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName
        externalConfiguration.general.mouseButtonNumber = 5

        state.syncExternalConfiguration(externalConfiguration)

        #expect(state.configuration.general.activeLayoutGroup == AppConfiguration.fullscreenGroupName)
        #expect(state.configuration.general.mouseButtonNumber == 5)
        #expect(state.configuration.layoutGroups.contains(where: { $0.name == "Work" }))
    }

    @Test func syncExternalConfigurationFallsBackWhenExternalActiveGroupIsMissingFromDraft() async throws {
        let state = SettingsPrototypeState(configuration: .defaultValue)
        state.applyLayoutsMutation { configuration in
            configuration.layoutGroups.removeAll { $0.name == AppConfiguration.fullscreenGroupName }
            configuration.general.activeLayoutGroup = AppConfiguration.builtInGroupName
        }

        var externalConfiguration = AppConfiguration.defaultValue
        externalConfiguration.general.activeLayoutGroup = AppConfiguration.fullscreenGroupName

        state.syncExternalConfiguration(externalConfiguration)

        #expect(state.configuration.general.activeLayoutGroup == AppConfiguration.builtInGroupName)
    }
}
