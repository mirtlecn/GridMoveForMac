import Foundation

final class ConfigurationRuntimeCoordinator {
    struct LoadResult {
        let configuration: AppConfiguration
        let source: ConfigurationLoadSource
        let diagnostic: ConfigurationLoadDiagnostic?
        let skippedLayoutDiagnostics: [LayoutFileDiagnostic]
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
        if didUpdateMonitorMetadata && result.source == .persistedConfiguration {
            do {
                try configurationStore.save(configuration)
            } catch {
                AppLogger.shared.error("Failed to save monitor metadata: \(error.localizedDescription)")
            }
        }

        return LoadResult(
            configuration: configuration,
            source: result.source,
            diagnostic: result.diagnostic,
            skippedLayoutDiagnostics: result.skippedLayoutDiagnostics
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

    func saveConfiguration(_ configuration: AppConfiguration) throws {
        try configurationStore.save(configuration)
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
