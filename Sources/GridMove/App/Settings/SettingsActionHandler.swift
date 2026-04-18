import Foundation

@MainActor
protocol SettingsActionHandling {
    func applyImmediateConfiguration(_ candidate: AppConfiguration) -> Bool
    func saveLayoutsConfiguration(_ candidate: AppConfiguration) -> Bool
    func refreshMonitorMetadata() -> AppConfiguration?
    func reloadConfiguration() -> AppConfiguration?
    func restoreDefaultConfiguration() -> AppConfiguration?
    func openConfigurationDirectory() -> Bool
}

@MainActor
struct SettingsActionHandler: SettingsActionHandling {
    let applyImmediateConfigurationHandler: (AppConfiguration) -> Bool
    let saveLayoutsConfigurationHandler: (AppConfiguration) -> Bool
    let refreshMonitorMetadataHandler: () -> AppConfiguration?
    let reloadConfigurationHandler: () -> AppConfiguration?
    let restoreDefaultConfigurationHandler: () -> AppConfiguration?
    let openConfigurationDirectoryHandler: () -> Bool

    func applyImmediateConfiguration(_ candidate: AppConfiguration) -> Bool {
        applyImmediateConfigurationHandler(candidate)
    }

    func saveLayoutsConfiguration(_ candidate: AppConfiguration) -> Bool {
        saveLayoutsConfigurationHandler(candidate)
    }

    func refreshMonitorMetadata() -> AppConfiguration? {
        refreshMonitorMetadataHandler()
    }

    func reloadConfiguration() -> AppConfiguration? {
        reloadConfigurationHandler()
    }

    func restoreDefaultConfiguration() -> AppConfiguration? {
        restoreDefaultConfigurationHandler()
    }

    func openConfigurationDirectory() -> Bool {
        openConfigurationDirectoryHandler()
    }
}
