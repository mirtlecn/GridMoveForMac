import Foundation
@testable import GridMove

@MainActor
final class TestSettingsActionRecorder {
    var applySucceeds = true
    var reloadedConfiguration: AppConfiguration?
    private(set) var appliedCandidates: [AppConfiguration] = []
    private(set) var openConfigurationDirectoryCallCount = 0

    func makeActionHandler() -> SettingsActionHandler {
        SettingsActionHandler(
            applyImmediateConfigurationHandler: { [weak self] candidate in
                guard let self else {
                    return false
                }
                appliedCandidates.append(candidate)
                return applySucceeds
            },
            reloadConfigurationHandler: { [weak self] in
                self?.reloadedConfiguration
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
