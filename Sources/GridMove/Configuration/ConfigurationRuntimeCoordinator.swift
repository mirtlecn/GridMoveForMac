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
        _ = synchronizeMonitorMetadata(configuration: &candidateConfiguration)
        try configurationStore.save(candidateConfiguration)
        return candidateConfiguration
    }

    func saveConfiguration(_ configuration: AppConfiguration) throws {
        try configurationStore.save(configuration)
    }

    private func synchronizeMonitorMetadata(configuration: inout AppConfiguration) -> Bool {
        let monitorMap = currentMonitorMapProvider()
        let didMigrateDisplayIDs = migrateExplicitMonitorIDs(
            configuration: &configuration,
            currentMonitorMap: monitorMap
        )

        let didUpdateMonitorMetadata = configuration.monitors != monitorMap
        guard didMigrateDisplayIDs || didUpdateMonitorMetadata else {
            return false
        }

        if didUpdateMonitorMetadata {
            configuration.monitors = monitorMap
        }
        return true
    }

    private func migrateExplicitMonitorIDs(
        configuration: inout AppConfiguration,
        currentMonitorMap: [String: String]
    ) -> Bool {
        let displayIDMappings = migratedDisplayIDMappings(
            savedMonitorMap: configuration.monitors,
            currentMonitorMap: currentMonitorMap
        )
        guard !displayIDMappings.isEmpty else {
            return false
        }

        var didChange = false
        for groupIndex in configuration.layoutGroups.indices {
            for setIndex in configuration.layoutGroups[groupIndex].sets.indices {
                guard case let .displays(displayIDs) = configuration.layoutGroups[groupIndex].sets[setIndex].monitor else {
                    continue
                }

                let migratedDisplayIDs = displayIDs.map { displayIDMappings[$0] ?? $0 }
                guard migratedDisplayIDs != displayIDs else {
                    continue
                }

                configuration.layoutGroups[groupIndex].sets[setIndex].monitor = .displays(migratedDisplayIDs)
                didChange = true
            }
        }

        return didChange
    }

    private func migratedDisplayIDMappings(
        savedMonitorMap: [String: String],
        currentMonitorMap: [String: String]
    ) -> [String: String] {
        var mappings: [String: String] = [:]

        for (monitorName, savedDisplayID) in savedMonitorMap {
            guard let currentDisplayID = currentMonitorMap[monitorName], currentDisplayID != savedDisplayID else {
                continue
            }
            mappings[savedDisplayID] = currentDisplayID
        }

        let savedEntriesByBaseName = Dictionary(
            grouping: savedMonitorMap.map { (name: $0.key, displayID: $0.value) },
            by: { baseDisplayName(forMonitorKey: $0.name, displayID: $0.displayID) }
        )
        let currentEntriesByBaseName = Dictionary(
            grouping: currentMonitorMap.map { (name: $0.key, displayID: $0.value) },
            by: { baseDisplayName(forMonitorKey: $0.name, displayID: $0.displayID) }
        )

        for (baseName, savedEntries) in savedEntriesByBaseName {
            guard
                savedEntries.count == 1,
                let currentEntries = currentEntriesByBaseName[baseName],
                currentEntries.count == 1,
                let savedEntry = savedEntries.first,
                let currentEntry = currentEntries.first,
                currentEntry.displayID != savedEntry.displayID
            else {
                continue
            }

            mappings[savedEntry.displayID] = currentEntry.displayID
        }

        return mappings
    }

    private func baseDisplayName(forMonitorKey key: String, displayID: String) -> String {
        let suffix = " (\(displayID))"
        guard key.hasSuffix(suffix) else {
            return key
        }
        return String(key.dropLast(suffix.count))
    }
}
