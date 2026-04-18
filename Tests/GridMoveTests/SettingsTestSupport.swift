import Foundation
@testable import GridMove

@MainActor
final class TestSettingsActionRecorder {
    var applySucceeds = true
    var saveLayoutsSucceeds = true
    var reloadedConfiguration: AppConfiguration?
    var refreshedMonitorConfiguration: AppConfiguration?
    var restoredConfiguration: AppConfiguration?
    private(set) var appliedCandidates: [AppConfiguration] = []
    private(set) var savedLayoutsCandidates: [AppConfiguration] = []
    private(set) var openConfigurationDirectoryCallCount = 0
    private(set) var refreshMonitorMetadataCallCount = 0
    private(set) var restoreDefaultConfigurationCallCount = 0

    func makeActionHandler() -> SettingsActionHandler {
        SettingsActionHandler(
            applyImmediateConfigurationHandler: { [weak self] candidate in
                guard let self else {
                    return false
                }
                appliedCandidates.append(candidate)
                return applySucceeds
            },
            saveLayoutsConfigurationHandler: { [weak self] candidate in
                guard let self else {
                    return false
                }
                savedLayoutsCandidates.append(candidate)
                return saveLayoutsSucceeds
            },
            refreshMonitorMetadataHandler: { [weak self] in
                guard let self else {
                    return nil
                }
                refreshMonitorMetadataCallCount += 1
                return refreshedMonitorConfiguration
            },
            reloadConfigurationHandler: { [weak self] in
                self?.reloadedConfiguration
            },
            restoreDefaultConfigurationHandler: { [weak self] in
                guard let self else {
                    return nil
                }
                restoreDefaultConfigurationCallCount += 1
                return restoredConfiguration
            },
            openConfigurationDirectoryHandler: { [weak self] in
                guard let self else {
                    return false
                }
                openConfigurationDirectoryCallCount += 1
                return true
            }
        )
    }
}
