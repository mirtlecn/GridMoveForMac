import Foundation

struct ConfigurationFile: Codable {
    let general: GeneralSettings
    let appearance: AppearanceConfiguration
    let dragTriggers: DragTriggerSettings
    let hotkeys: HotkeyConfiguration
    let monitors: [String: String]

    private enum CodingKeys: String, CodingKey {
        case general
        case appearance
        case dragTriggers
        case hotkeys
        case monitors
    }

    init(
        general: GeneralSettings,
        appearance: AppearanceConfiguration,
        dragTriggers: DragTriggerSettings,
        hotkeys: HotkeyConfiguration,
        monitors: [String: String]
    ) {
        self.general = general
        self.appearance = appearance
        self.dragTriggers = dragTriggers
        self.hotkeys = hotkeys
        self.monitors = monitors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let anyContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        if anyContainer.allKeys.contains(where: { $0.stringValue == "layoutGroups" }) {
            throw ConfigurationFileError.embeddedLayoutGroupsNotSupported
        }

        general = try container.decode(GeneralSettings.self, forKey: .general)
        appearance = try container.decode(AppearanceConfiguration.self, forKey: .appearance)
        dragTriggers = try container.decode(DragTriggerSettings.self, forKey: .dragTriggers)
        hotkeys = try container.decode(HotkeyConfiguration.self, forKey: .hotkeys)
        monitors = try container.decode([String: String].self, forKey: .monitors)
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct AppearanceConfiguration: Codable {
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

struct HotkeyConfiguration: Codable {
    let bindings: [HotkeyBindingConfiguration]
}

struct HotkeyBindingConfiguration: Codable {
    let isEnabled: Bool
    let shortcut: KeyboardShortcut?
    let action: HotkeyActionConfiguration

    init(isEnabled: Bool, shortcut: KeyboardShortcut?, action: HotkeyActionConfiguration) {
        self.isEnabled = isEnabled
        self.shortcut = shortcut
        self.action = action
    }
}

struct HotkeyActionConfiguration: Codable {
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

struct LayoutGroupConfiguration: Codable {
    let name: String
    let includeInGroupCycle: Bool
    let sets: [LayoutSetConfiguration]

    private enum CodingKeys: String, CodingKey {
        case name
        case includeInGroupCycle
        case sets
    }

    init(group: LayoutGroup) {
        name = group.name
        includeInGroupCycle = group.includeInGroupCycle
        sets = group.sets.map(LayoutSetConfiguration.init(set:))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        includeInGroupCycle = try container.decodeIfPresent(Bool.self, forKey: .includeInGroupCycle) ?? true
        sets = try container.decode([LayoutSetConfiguration].self, forKey: .sets)
    }
}

struct LayoutSetConfiguration: Codable {
    let monitor: LayoutSetMonitor
    let layouts: [LayoutConfiguration]

    init(set: LayoutSet) {
        monitor = set.monitor
        layouts = set.layouts.map(LayoutConfiguration.init(layout:))
    }
}

struct LayoutConfiguration: Codable {
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
