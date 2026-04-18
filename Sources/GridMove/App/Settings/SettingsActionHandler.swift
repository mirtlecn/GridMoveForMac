import Foundation

@MainActor
protocol SettingsActionHandling {
    func applyImmediateConfiguration(_ candidate: AppConfiguration) -> Bool
    func reloadConfiguration() -> AppConfiguration?
    func openConfigurationDirectory() -> Bool
}

@MainActor
struct SettingsActionHandler: SettingsActionHandling {
    let applyImmediateConfigurationHandler: (AppConfiguration) -> Bool
    let reloadConfigurationHandler: () -> AppConfiguration?
    let openConfigurationDirectoryHandler: () -> Bool

    func applyImmediateConfiguration(_ candidate: AppConfiguration) -> Bool {
        applyImmediateConfigurationHandler(candidate)
    }

    func reloadConfiguration() -> AppConfiguration? {
        reloadConfigurationHandler()
    }

    func openConfigurationDirectory() -> Bool {
        openConfigurationDirectoryHandler()
    }
}
