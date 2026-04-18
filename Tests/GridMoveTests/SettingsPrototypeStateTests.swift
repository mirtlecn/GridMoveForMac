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
}
