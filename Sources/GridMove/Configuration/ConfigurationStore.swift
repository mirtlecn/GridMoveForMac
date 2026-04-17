import Foundation

final class ConfigurationStore {
    struct LoadResult {
        let configuration: AppConfiguration
        let didFallBackToDefault: Bool
    }

    private let fileManager: FileManager
    let directoryURL: URL
    let fileURL: URL

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let baseURL = baseDirectoryURL
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("GridMove", isDirectory: true)
        directoryURL = baseURL
        fileURL = baseURL.appendingPathComponent("config.json")
    }

    func load() throws -> AppConfiguration {
        try loadWithStatus().configuration
    }

    func loadWithStatus() throws -> LoadResult {
        try ensureDirectoryExists()

        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let configurationFile = try makeDecoder().decode(ConfigurationFile.self, from: data)
                return LoadResult(
                    configuration: try ConfigurationSchemaConverter.makeAppConfiguration(from: configurationFile),
                    didFallBackToDefault: false
                )
            } catch {
                AppLogger.shared.error("Failed to decode configuration from \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return LoadResult(configuration: .defaultValue, didFallBackToDefault: true)
            }
        }

        let configuration = AppConfiguration.defaultValue
        try save(configuration)
        return LoadResult(configuration: configuration, didFallBackToDefault: false)
    }

    func save(_ configuration: AppConfiguration) throws {
        try ensureDirectoryExists()
        let configurationFile = try ConfigurationSchemaConverter.makeConfigurationFile(from: configuration)
        let data = try makeEncoder().encode(configurationFile)
        try data.write(to: fileURL, options: .atomic)
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private struct ConfigurationFile: Codable {
    let general: GeneralSettings
    let appearance: AppearanceConfiguration
    let dragTriggers: DragTriggerSettings
    let hotkeys: HotkeyConfiguration
    let layoutGroups: [LayoutGroupConfiguration]
    let monitors: [String: String]
}

private enum ConfigurationSchemaConverter {
    static func makeConfigurationFile(from configuration: AppConfiguration) throws -> ConfigurationFile {
        let normalizedConfiguration = try normalizeConfiguration(configuration)
        return ConfigurationFile(
            general: normalizedConfiguration.general,
            appearance: AppearanceConfiguration(settings: normalizedConfiguration.appearance),
            dragTriggers: normalizedConfiguration.dragTriggers,
            hotkeys: HotkeyConfiguration(
                bindings: normalizedConfiguration.hotkeys.bindings.map { binding in
                    HotkeyBindingConfiguration(
                        isEnabled: binding.isEnabled,
                        shortcut: binding.shortcut,
                        action: HotkeyActionConfiguration(action: binding.action)
                    )
                }
            ),
            layoutGroups: normalizedConfiguration.layoutGroups.map(LayoutGroupConfiguration.init(group:)),
            monitors: normalizedConfiguration.monitors
        )
    }

    static func makeAppConfiguration(from configurationFile: ConfigurationFile) throws -> AppConfiguration {
        let generatedLayoutGroups = normalizeLayoutGroups(configurationFile.layoutGroups)
        let generatedBindings = try configurationFile.hotkeys.bindings.enumerated().map { index, binding in
            ShortcutBinding(
                id: "binding-\(index + 1)",
                isEnabled: binding.isEnabled,
                shortcut: binding.shortcut,
                action: try binding.action.makeAction()
            )
        }

        let configuration = AppConfiguration(
            general: configurationFile.general,
            appearance: try configurationFile.appearance.makeSettings(),
            dragTriggers: configurationFile.dragTriggers,
            hotkeys: HotkeySettings(bindings: generatedBindings),
            layoutGroups: generatedLayoutGroups,
            monitors: configurationFile.monitors
        )
        try validateConfiguration(configuration)
        return configuration
    }

    private static func normalizeConfiguration(_ configuration: AppConfiguration) throws -> AppConfiguration {
        let normalizedLayoutGroups = normalizeLayoutGroups(configuration.layoutGroups.map(LayoutGroupConfiguration.init(group:)))
        let normalizedBindings = configuration.hotkeys.bindings.enumerated().map { index, binding in
            ShortcutBinding(
                id: "binding-\(index + 1)",
                isEnabled: binding.isEnabled,
                shortcut: binding.shortcut,
                action: binding.action
            )
        }

        let normalizedConfiguration = AppConfiguration(
            general: configuration.general,
            appearance: configuration.appearance,
            dragTriggers: configuration.dragTriggers,
            hotkeys: HotkeySettings(bindings: normalizedBindings),
            layoutGroups: normalizedLayoutGroups,
            monitors: configuration.monitors
        )
        try validateConfiguration(normalizedConfiguration)
        return normalizedConfiguration
    }

    private static func normalizeLayoutGroups(_ groups: [LayoutGroupConfiguration]) -> [LayoutGroup] {
        var nextLayoutIndex = 1
        return groups.map { groupConfiguration in
            let sets = groupConfiguration.sets.map { setConfiguration in
                let layouts = setConfiguration.layouts.map { layoutConfiguration in
                    defer { nextLayoutIndex += 1 }
                    return LayoutPreset(
                        id: "layout-\(nextLayoutIndex)",
                        name: layoutConfiguration.name,
                        gridColumns: layoutConfiguration.gridColumns,
                        gridRows: layoutConfiguration.gridRows,
                        windowSelection: layoutConfiguration.windowSelection,
                        triggerRegion: layoutConfiguration.triggerRegion,
                        includeInLayoutIndex: layoutConfiguration.includeInLayoutIndex,
                        includeInMenu: layoutConfiguration.includeInMenu
                    )
                }
                return LayoutSet(monitor: setConfiguration.monitor, layouts: layouts)
            }
            return LayoutGroup(name: groupConfiguration.name, sets: sets)
        }
    }

    private static func validateConfiguration(_ configuration: AppConfiguration) throws {
        guard configuration.layoutGroups.contains(where: { $0.name == configuration.general.activeLayoutGroup }) else {
            throw ConfigurationFileError.missingActiveLayoutGroup(configuration.general.activeLayoutGroup)
        }

        let groupNames = configuration.layoutGroups.map(\.name)
        guard Set(groupNames).count == groupNames.count else {
            throw ConfigurationFileError.duplicateLayoutGroupName
        }

        for group in configuration.layoutGroups {
            var explicitDisplayIDs: Set<String> = []
            var hasMainSet = false
            var hasAllSet = false

            for set in group.sets {
                switch set.monitor {
                case .all:
                    guard !hasAllSet else {
                        throw ConfigurationFileError.overlappingMonitorBindings(group.name)
                    }
                    hasAllSet = true
                case .main:
                    guard !hasMainSet else {
                        throw ConfigurationFileError.overlappingMonitorBindings(group.name)
                    }
                    hasMainSet = true
                case let .displays(displayIDs):
                    for displayID in displayIDs {
                        guard !explicitDisplayIDs.contains(displayID) else {
                            throw ConfigurationFileError.overlappingMonitorBindings(group.name)
                        }
                        explicitDisplayIDs.insert(displayID)
                    }
                }
            }
        }
    }
}

private struct AppearanceConfiguration: Codable {
    let renderTriggerAreas: Bool
    let triggerOpacity: Double
    let triggerGap: Double
    let triggerStrokeColor: String
    let renderWindowHighlight: Bool
    let highlightFillOpacity: Double
    let highlightStrokeWidth: Double
    let highlightStrokeColor: String

    init(settings: AppearanceSettings) {
        renderTriggerAreas = settings.renderTriggerAreas
        triggerOpacity = settings.triggerOpacity
        triggerGap = settings.triggerGap
        triggerStrokeColor = settings.triggerStrokeColor.hexString
        renderWindowHighlight = settings.renderWindowHighlight
        highlightFillOpacity = settings.highlightFillOpacity
        highlightStrokeWidth = settings.highlightStrokeWidth
        highlightStrokeColor = settings.highlightStrokeColor.hexString
    }

    func makeSettings() throws -> AppearanceSettings {
        AppearanceSettings(
            renderTriggerAreas: renderTriggerAreas,
            triggerOpacity: triggerOpacity,
            triggerGap: triggerGap,
            triggerStrokeColor: try RGBAColor(hexString: triggerStrokeColor),
            renderWindowHighlight: renderWindowHighlight,
            highlightFillOpacity: highlightFillOpacity,
            highlightStrokeWidth: highlightStrokeWidth,
            highlightStrokeColor: try RGBAColor(hexString: highlightStrokeColor)
        )
    }
}

private struct HotkeyConfiguration: Codable {
    let bindings: [HotkeyBindingConfiguration]
}

private struct HotkeyBindingConfiguration: Codable {
    let isEnabled: Bool
    let shortcut: KeyboardShortcut?
    let action: HotkeyActionConfiguration

    init(isEnabled: Bool, shortcut: KeyboardShortcut?, action: HotkeyActionConfiguration) {
        self.isEnabled = isEnabled
        self.shortcut = shortcut
        self.action = action
    }
}

private struct HotkeyActionConfiguration: Codable {
    enum Kind: String, Codable {
        case applyLayoutByIndex
        case cycleNext
        case cyclePrevious
    }

    let kind: Kind
    let layout: Int?

    init(action: HotkeyAction) {
        switch action {
        case let .applyLayoutByIndex(layoutIndex):
            kind = .applyLayoutByIndex
            layout = layoutIndex
        case .cycleNext:
            kind = .cycleNext
            layout = nil
        case .cyclePrevious:
            kind = .cyclePrevious
            layout = nil
        case .applyLayoutByName, .applyLayoutByID:
            preconditionFailure("Menu-only actions must not be written into hotkey configuration.")
        }
    }

    func makeAction() throws -> HotkeyAction {
        switch kind {
        case .cycleNext:
            return .cycleNext
        case .cyclePrevious:
            return .cyclePrevious
        case .applyLayoutByIndex:
            guard let layout, layout >= 1 else {
                throw ConfigurationFileError.invalidLayoutReference(layout ?? -1)
            }
            return .applyLayoutByIndex(layout: layout)
        }
    }
}

private struct LayoutGroupConfiguration: Codable {
    let name: String
    let sets: [LayoutSetConfiguration]

    init(group: LayoutGroup) {
        name = group.name
        sets = group.sets.map(LayoutSetConfiguration.init(set:))
    }
}

private struct LayoutSetConfiguration: Codable {
    let monitor: LayoutSetMonitor
    let layouts: [LayoutConfiguration]

    init(set: LayoutSet) {
        monitor = set.monitor
        layouts = set.layouts.map(LayoutConfiguration.init(layout:))
    }
}

private struct LayoutConfiguration: Codable {
    let name: String
    let gridColumns: Int
    let gridRows: Int
    let windowSelection: GridSelection
    let triggerRegion: TriggerRegion?
    let includeInLayoutIndex: Bool
    let includeInMenu: Bool

    private enum CodingKeys: String, CodingKey {
        case name
        case gridColumns
        case gridRows
        case windowSelection
        case triggerRegion
        case includeInLayoutIndex
        case includeInMenu
    }

    init(layout: LayoutPreset) {
        name = layout.name
        gridColumns = layout.gridColumns
        gridRows = layout.gridRows
        windowSelection = layout.windowSelection
        triggerRegion = layout.triggerRegion
        includeInLayoutIndex = layout.includeInLayoutIndex
        includeInMenu = layout.includeInMenu
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        gridColumns = try container.decode(Int.self, forKey: .gridColumns)
        gridRows = try container.decode(Int.self, forKey: .gridRows)
        windowSelection = try container.decode(GridSelection.self, forKey: .windowSelection)
        triggerRegion = try container.decodeIfPresent(TriggerRegion.self, forKey: .triggerRegion)
        includeInLayoutIndex = try container.decodeIfPresent(Bool.self, forKey: .includeInLayoutIndex) ?? true
        includeInMenu = try container.decodeIfPresent(Bool.self, forKey: .includeInMenu) ?? true
    }
}

private enum ConfigurationFileError: Error {
    case invalidLayoutReference(Int)
    case missingActiveLayoutGroup(String)
    case duplicateLayoutGroupName
    case overlappingMonitorBindings(String)
}
