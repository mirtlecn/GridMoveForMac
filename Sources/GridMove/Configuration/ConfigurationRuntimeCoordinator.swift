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
        let didUpdateMonitorMetadata = refreshMonitorMetadata(configuration: &configuration)
        if didUpdateMonitorMetadata,
           result.source == .persistedConfiguration,
           result.skippedLayoutDiagnostics.isEmpty {
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
        try configurationStore.save(candidateConfiguration)
        return candidateConfiguration
    }

    func saveConfiguration(_ configuration: AppConfiguration) throws {
        try configurationStore.save(configuration)
    }

    private func refreshMonitorMetadata(configuration: inout AppConfiguration) -> Bool {
        let connectedMonitorMap = currentMonitorMapProvider()
        guard !connectedMonitorMap.isEmpty else {
            return false
        }

        var mergedMonitorMap = configuration.monitors
        for (fingerprint, displayID) in connectedMonitorMap {
            mergedMonitorMap[fingerprint] = displayID
        }

        guard mergedMonitorMap != configuration.monitors else {
            return false
        }

        configuration.monitors = mergedMonitorMap
        return true
    }
}
