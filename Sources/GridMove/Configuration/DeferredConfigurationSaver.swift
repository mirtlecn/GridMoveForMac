import Foundation

actor DeferredConfigurationSaver {
    private let configurationStore: ConfigurationStore

    init(baseDirectoryURL: URL) {
        self.configurationStore = ConfigurationStore(baseDirectoryURL: baseDirectoryURL)
    }

    func persist(_ configuration: AppConfiguration) {
        do {
            try configurationStore.save(configuration)
        } catch {
            AppLogger.shared.error("Failed to save deferred configuration: \(error.localizedDescription)")
        }
    }

    func waitForPendingSaves() {}
}
