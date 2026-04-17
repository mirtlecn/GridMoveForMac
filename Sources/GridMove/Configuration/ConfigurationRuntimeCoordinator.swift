import Foundation

final class ConfigurationRuntimeCoordinator {
    struct LoadResult {
        let configuration: AppConfiguration
        let didFallBackToDefault: Bool
    }

    private let configurationStore: ConfigurationStore
    private let currentMonitorMapProvider: () -> [String: String]

    init(
        configurationStore: ConfigurationStore,
        currentMonitorMapProvider: @escaping () -> [String: String]
    ) {
        self.configurationStore = configurationStore
        self.currentMonitorMapProvider = currentMonitorMapProvider
    }

    var directoryURL: URL {
        configurationStore.directoryURL
    }

    func loadConfiguration() throws -> LoadResult {
        let result = try configurationStore.loadWithStatus()
        var configuration = result.configuration
        let didUpdateMonitorMetadata = synchronizeMonitorMetadata(configuration: &configuration)
        if didUpdateMonitorMetadata && result.didFallBackToDefault == false {
            do {
                try configurationStore.save(configuration)
            } catch {
                AppLogger.shared.error("Failed to save monitor metadata: \(error.localizedDescription)")
            }
        }

        return LoadResult(
            configuration: configuration,
            didFallBackToDefault: result.didFallBackToDefault
        )
    }

    func saveUpdatedConfiguration(
        from currentConfiguration: AppConfiguration,
        mutate: (inout AppConfiguration) -> Void
    ) throws -> AppConfiguration {
        var candidateConfiguration = currentConfiguration
        mutate(&candidateConfiguration)
        _ = synchronizeMonitorMetadata(configuration: &candidateConfiguration)
        try configurationStore.save(candidateConfiguration)
        return candidateConfiguration
    }

    private func synchronizeMonitorMetadata(configuration: inout AppConfiguration) -> Bool {
        let monitorMap = currentMonitorMapProvider()
        guard configuration.monitors != monitorMap else {
            return false
        }
        configuration.monitors = monitorMap
        return true
    }
}
