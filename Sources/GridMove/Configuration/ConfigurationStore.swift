import Foundation

final class ConfigurationStore {
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
        try ensureDirectoryExists()

        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let configurationFile = try makeDecoder().decode(
                    ConfigurationFile.self,
                    from: stripJSONComments(from: data)
                )
                return try configurationFile.makeAppConfiguration()
            } catch {
                AppLogger.shared.error("Failed to decode configuration from \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return .defaultValue
            }
        }

        let configuration = AppConfiguration.defaultValue
        try save(configuration)
        return configuration
    }

    func save(_ configuration: AppConfiguration) throws {
        try ensureDirectoryExists()
        let normalizedConfiguration = normalizeConfiguration(configuration)
        let configurationFile = ConfigurationFile(configuration: normalizedConfiguration)
        let text = configurationFile.renderedText
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
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

    private func normalizeConfiguration(_ configuration: AppConfiguration) -> AppConfiguration {
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

        let originalIDs = configuration.layouts.map(\.id)
        let newIDs = normalizedLayouts.map(\.id)
        let layoutIDMap = Dictionary(uniqueKeysWithValues: zip(originalIDs, newIDs))

        let normalizedBindings = configuration.hotkeys.bindings.enumerated().map { index, binding in
            let normalizedAction: HotkeyAction
            switch binding.action {
            case let .applyLayout(layoutID):
                normalizedAction = .applyLayout(layoutID: layoutIDMap[layoutID] ?? layoutID)
            case .cycleNext:
                normalizedAction = .cycleNext
            case .cyclePrevious:
                normalizedAction = .cyclePrevious
            }

            return ShortcutBinding(
                id: "binding-\(index + 1)",
                isEnabled: binding.isEnabled,
                shortcut: binding.shortcut,
                action: normalizedAction
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

    private func stripJSONComments(from data: Data) throws -> Data {
        let source = String(decoding: data, as: UTF8.self)
        var output = ""
        var index = source.startIndex
        var isInsideString = false
        var isEscaped = false

        while index < source.endIndex {
            let character = source[index]
            let nextIndex = source.index(after: index)
            let nextCharacter = nextIndex < source.endIndex ? source[nextIndex] : "\0"

            if isInsideString {
                output.append(character)
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                index = nextIndex
                continue
            }

            if character == "\"" {
                isInsideString = true
                output.append(character)
                index = nextIndex
                continue
            }

            if character == "/" && nextCharacter == "/" {
                index = source.index(after: nextIndex)
                while index < source.endIndex && source[index] != "\n" {
                    index = source.index(after: index)
                }
                continue
            }

            if character == "/" && nextCharacter == "*" {
                index = source.index(after: nextIndex)
                while index < source.endIndex {
                    let current = source[index]
                    let lookaheadIndex = source.index(after: index)
                    let lookahead = lookaheadIndex < source.endIndex ? source[lookaheadIndex] : "\0"
                    if current == "*" && lookahead == "/" {
                        index = source.index(after: lookaheadIndex)
                        break
                    }
                    index = lookaheadIndex
                }
                continue
            }

            output.append(character)
            index = nextIndex
        }

        return Data(output.utf8)
    }
}

private struct ConfigurationFile: Decodable {
    let general: GeneralSettings
    let appearance: AppearanceConfiguration
    let dragTriggers: DragTriggerSettings
    let hotkeys: HotkeyConfiguration
    let layouts: [LayoutConfiguration]

    init(configuration: AppConfiguration) {
        general = configuration.general
        appearance = AppearanceConfiguration(settings: configuration.appearance)
        dragTriggers = configuration.dragTriggers
        hotkeys = HotkeyConfiguration(
            bindings: configuration.hotkeys.bindings.map { binding in
                HotkeyBindingConfiguration(
                    isEnabled: binding.isEnabled,
                    shortcut: binding.shortcut,
                    action: HotkeyActionConfiguration(
                        action: binding.action,
                        layouts: configuration.layouts
                    )
                )
            }
        )
        layouts = configuration.layouts.map(LayoutConfiguration.init(layout:))
    }

    func makeAppConfiguration() throws -> AppConfiguration {
        let generatedLayouts = layouts.enumerated().map { index, layout in
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

        let generatedBindings = try hotkeys.bindings.enumerated().map { index, binding in
            ShortcutBinding(
                id: "binding-\(index + 1)",
                isEnabled: binding.isEnabled,
                shortcut: binding.shortcut,
                action: try binding.action.makeAction(layouts: generatedLayouts)
            )
        }

        return AppConfiguration(
            general: general,
            appearance: try appearance.makeSettings(),
            dragTriggers: dragTriggers,
            hotkeys: HotkeySettings(bindings: generatedBindings),
            layouts: generatedLayouts
        )
    }

    var renderedText: String {
        var lines: [String] = []
        lines.append("{")
        lines.append("  // Global enable switch and window exclusion rules.")
        lines.append("  \"general\": \(renderGeneral()),")
        lines.append("")
        lines.append("  // Overlay rendering. Stroke colors use #RRGGBBAA.")
        lines.append("  \"appearance\": \(renderAppearance()),")
        lines.append("")
        lines.append("  // Drag trigger settings. modifierGroups is a list of modifier key groups.")
        lines.append("  \"dragTriggers\": \(renderDragTriggers()),")
        lines.append("")
        lines.append("  // Hotkey bindings. action.kind supports: cycleNext, cyclePrevious, applyLayout.")
        lines.append("  // For applyLayout, action.layout is the 1-based layout number in the layouts array.")
        lines.append("  \"hotkeys\": \(renderHotkeys()),")
        lines.append("")
        lines.append("  // Layouts are applied and cycled in array order. includeInCycle=false skips next/previous cycle.")
        lines.append("  \"layouts\": \(renderLayouts())")
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    private func renderGeneral() -> String {
        """
{
    \"isEnabled\": \(jsonBool(general.isEnabled)),
    \"excludedBundleIDs\": \(jsonStringArray(general.excludedBundleIDs)),
    \"excludedWindowTitles\": \(jsonStringArray(general.excludedWindowTitles))
  }
"""
    }

    private func renderAppearance() -> String {
        """
{
    \"renderTriggerAreas\": \(jsonBool(appearance.renderTriggerAreas)),
    \"triggerOpacity\": \(jsonNumber(appearance.triggerOpacity)),
    \"triggerGap\": \(jsonNumber(appearance.triggerGap)),
    \"triggerStrokeColor\": \(jsonString(appearance.triggerStrokeColor)),
    \"renderWindowHighlight\": \(jsonBool(appearance.renderWindowHighlight)),
    \"highlightFillOpacity\": \(jsonNumber(appearance.highlightFillOpacity)),
    \"highlightStrokeWidth\": \(jsonNumber(appearance.highlightStrokeWidth)),
    \"highlightStrokeColor\": \(jsonString(appearance.highlightStrokeColor))
  }
"""
    }

    private func renderDragTriggers() -> String {
        let modifierGroups = dragTriggers.modifierGroups
            .map { "    " + jsonStringArray($0.map(\.rawValue)) }
            .joined(separator: ",\n")

        return """
{
    \"middleMouseButtonNumber\": \(jsonNumber(dragTriggers.middleMouseButtonNumber)),
    \"enableMiddleMouseDrag\": \(jsonBool(dragTriggers.enableMiddleMouseDrag)),
    \"enableModifierLeftMouseDrag\": \(jsonBool(dragTriggers.enableModifierLeftMouseDrag)),
    \"modifierGroups\": [
\(modifierGroups)
    ],
    \"activationDelaySeconds\": \(jsonNumber(dragTriggers.activationDelaySeconds)),
    \"activationMoveThreshold\": \(jsonNumber(dragTriggers.activationMoveThreshold))
  }
"""
    }

    private func renderHotkeys() -> String {
        let renderedBindings = hotkeys.bindings.map { binding in
            """
      {
        \"isEnabled\": \(jsonBool(binding.isEnabled)),
        \"shortcut\": \(renderShortcut(binding.shortcut)),
        \"action\": \(renderAction(binding.action))
      }
"""
        }.joined(separator: ",\n")

        return """
{
    \"bindings\": [
\(renderedBindings)
    ]
  }
"""
    }

    private func renderLayouts() -> String {
        let renderedLayouts = layouts.enumerated().map { index, layout in
            """
      {
        // Layout \(index + 1)
        \"name\": \(jsonString(layout.name)),
        \"gridColumns\": \(jsonNumber(layout.gridColumns)),
        \"gridRows\": \(jsonNumber(layout.gridRows)),
        \"windowSelection\": {
          \"x\": \(jsonNumber(layout.windowSelection.x)),
          \"y\": \(jsonNumber(layout.windowSelection.y)),
          \"w\": \(jsonNumber(layout.windowSelection.w)),
          \"h\": \(jsonNumber(layout.windowSelection.h))
        },
        \"triggerRegion\": \(renderTriggerRegion(layout.triggerRegion)),
        \"includeInCycle\": \(jsonBool(layout.includeInCycle))
      }
"""
        }.joined(separator: ",\n")

        return """
[
\(renderedLayouts)
  ]
"""
    }

    private func renderShortcut(_ shortcut: KeyboardShortcut?) -> String {
        guard let shortcut else {
            return "null"
        }

        return """
{
          \"modifiers\": \(jsonStringArray(shortcut.modifiers.map(\.rawValue))),
          \"key\": \(jsonString(shortcut.key))
        }
"""
    }

    private func renderAction(_ action: HotkeyActionConfiguration) -> String {
        var lines = [
            "{",
            "          \"kind\": \(jsonString(action.kind.rawValue))",
        ]

        if let layout = action.layout {
            lines[1].append(",")
            lines.append("          \"layout\": \(jsonNumber(layout))")
        }

        lines.append("        }")
        return lines.joined(separator: "\n")
    }

    private func renderTriggerRegion(_ triggerRegion: TriggerRegion) -> String {
        switch triggerRegion {
        case let .screen(selection):
            return """
{
          \"kind\": \"screen\",
          \"gridSelection\": {
            \"x\": \(jsonNumber(selection.x)),
            \"y\": \(jsonNumber(selection.y)),
            \"w\": \(jsonNumber(selection.w)),
            \"h\": \(jsonNumber(selection.h))
          }
        }
"""
        case let .menuBar(selection):
            return """
{
          \"kind\": \"menuBar\",
          \"menuBarSelection\": {
            \"x\": \(jsonNumber(selection.x)),
            \"w\": \(jsonNumber(selection.w))
          }
        }
"""
        }
    }

    private func jsonString(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [value], options: [])
        let encoded = String(decoding: data ?? Data("[]".utf8), as: UTF8.self)
        return String(encoded.dropFirst().dropLast())
    }

    private func jsonStringArray(_ values: [String]) -> String {
        let rendered = values.map(jsonString).joined(separator: ", ")
        return "[\(rendered)]"
    }

    private func jsonBool(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private func jsonNumber<T: LosslessStringConvertible>(_ value: T) -> String {
        String(value)
    }
}

private struct AppearanceConfiguration: Decodable {
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

private struct HotkeyConfiguration: Decodable {
    let bindings: [HotkeyBindingConfiguration]
}

private struct HotkeyBindingConfiguration: Decodable {
    let isEnabled: Bool
    let shortcut: KeyboardShortcut?
    let action: HotkeyActionConfiguration

    init(isEnabled: Bool, shortcut: KeyboardShortcut?, action: HotkeyActionConfiguration) {
        self.isEnabled = isEnabled
        self.shortcut = shortcut
        self.action = action
    }
}

private struct HotkeyActionConfiguration: Decodable {
    enum Kind: String, Decodable {
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

private struct LayoutConfiguration: Decodable {
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
