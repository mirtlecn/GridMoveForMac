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
        let configurationFile = ConfigurationSchemaConverter.makeConfigurationFile(from: configuration)
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
    let layouts: [LayoutConfiguration]
}

private enum ConfigurationSchemaConverter {
    static func makeConfigurationFile(from configuration: AppConfiguration) -> ConfigurationFile {
        let normalizedConfiguration = normalizeConfiguration(configuration)
        return ConfigurationFile(
            general: normalizedConfiguration.general,
            appearance: AppearanceConfiguration(settings: normalizedConfiguration.appearance),
            dragTriggers: normalizedConfiguration.dragTriggers,
            hotkeys: HotkeyConfiguration(
                bindings: normalizedConfiguration.hotkeys.bindings.map { binding in
                    HotkeyBindingConfiguration(
                        isEnabled: binding.isEnabled,
                        shortcut: binding.shortcut,
                        action: HotkeyActionConfiguration(
                            action: binding.action,
                            layouts: normalizedConfiguration.layouts
                        )
                    )
                }
            ),
            layouts: normalizedConfiguration.layouts.map(LayoutConfiguration.init(layout:))
        )
    }

    static func makeAppConfiguration(from configurationFile: ConfigurationFile) throws -> AppConfiguration {
        let generatedLayouts = configurationFile.layouts.enumerated().map { index, layout in
            LayoutPreset(
                id: "layout-\(index + 1)",
                name: layout.name,
                gridColumns: layout.gridColumns,
                gridRows: layout.gridRows,
                windowSelection: layout.windowSelection,
                triggerRegion: layout.triggerRegion,
                includeInCycle: layout.includeInCycle
            )
        }

        let generatedBindings = try configurationFile.hotkeys.bindings.enumerated().map { index, binding in
            ShortcutBinding(
                id: "binding-\(index + 1)",
                isEnabled: binding.isEnabled,
                shortcut: binding.shortcut,
                action: try binding.action.makeAction(layouts: generatedLayouts)
            )
        }

        return AppConfiguration(
            general: configurationFile.general,
            appearance: try configurationFile.appearance.makeSettings(),
            dragTriggers: configurationFile.dragTriggers,
            hotkeys: HotkeySettings(bindings: generatedBindings),
            layouts: generatedLayouts
        )
    }

    private static func normalizeConfiguration(_ configuration: AppConfiguration) -> AppConfiguration {
        let normalizedLayouts = configuration.layouts.enumerated().map { index, layout in
            LayoutPreset(
                id: "layout-\(index + 1)",
                name: layout.name,
                gridColumns: layout.gridColumns,
                gridRows: layout.gridRows,
                windowSelection: layout.windowSelection,
                triggerRegion: layout.triggerRegion,
                includeInCycle: layout.includeInCycle
            )
        }

        let layoutIDMap = Dictionary(
            uniqueKeysWithValues: zip(configuration.layouts.map(\.id), normalizedLayouts.map(\.id))
        )

        let normalizedBindings = configuration.hotkeys.bindings.enumerated().map { index, binding in
            ShortcutBinding(
                id: "binding-\(index + 1)",
                isEnabled: binding.isEnabled,
                shortcut: binding.shortcut,
                action: normalizeAction(binding.action, layoutIDMap: layoutIDMap)
            )
        }

        return AppConfiguration(
            general: configuration.general,
            appearance: configuration.appearance,
            dragTriggers: configuration.dragTriggers,
            hotkeys: HotkeySettings(bindings: normalizedBindings),
            layouts: normalizedLayouts
        )
    }

    private static func normalizeAction(_ action: HotkeyAction, layoutIDMap: [String: String]) -> HotkeyAction {
        switch action {
        case let .applyLayout(layoutID):
            return .applyLayout(layoutID: layoutIDMap[layoutID] ?? layoutID)
        case .cycleNext:
            return .cycleNext
        case .cyclePrevious:
            return .cyclePrevious
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
        case applyLayout
        case cycleNext
        case cyclePrevious
    }

    let kind: Kind
    let layout: Int?

    init(action: HotkeyAction, layouts: [LayoutPreset]) {
        switch action {
        case let .applyLayout(layoutID):
            kind = .applyLayout
            layout = layouts.firstIndex(where: { $0.id == layoutID }).map { $0 + 1 }
        case .cycleNext:
            kind = .cycleNext
            layout = nil
        case .cyclePrevious:
            kind = .cyclePrevious
            layout = nil
        }
    }

    func makeAction(layouts: [LayoutPreset]) throws -> HotkeyAction {
        switch kind {
        case .cycleNext:
            return .cycleNext
        case .cyclePrevious:
            return .cyclePrevious
        case .applyLayout:
            guard let layout, layout >= 1, layout <= layouts.count else {
                throw ConfigurationFileError.invalidLayoutReference(layout ?? -1)
            }
            return .applyLayout(layoutID: layouts[layout - 1].id)
        }
    }
}

private struct LayoutConfiguration: Codable {
    let name: String
    let gridColumns: Int
    let gridRows: Int
    let windowSelection: GridSelection
    let triggerRegion: TriggerRegion
    let includeInCycle: Bool

    init(layout: LayoutPreset) {
        name = layout.name
        gridColumns = layout.gridColumns
        gridRows = layout.gridRows
        windowSelection = layout.windowSelection
        triggerRegion = layout.triggerRegion
        includeInCycle = layout.includeInCycle
    }
}

private enum ConfigurationFileError: Error {
    case invalidLayoutReference(Int)
}
