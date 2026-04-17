import AppKit
import Carbon.HIToolbox
import Foundation

enum ModifierKey: String, Codable, CaseIterable, Hashable {
    case ctrl
    case cmd
    case shift
    case alt

    var cgEventFlag: CGEventFlags {
        switch self {
        case .ctrl:
            return .maskControl
        case .cmd:
            return .maskCommand
        case .shift:
            return .maskShift
        case .alt:
            return .maskAlternate
        }
    }

    var displayName: String {
        switch self {
        case .ctrl:
            return "Ctrl"
        case .cmd:
            return "Cmd"
        case .shift:
            return "Shift"
        case .alt:
            return "Option"
        }
    }
}

struct KeyboardShortcut: Codable, Equatable, Hashable {
    var modifiers: [ModifierKey]
    var key: String

    var normalizedModifiers: [ModifierKey] {
        ModifierKey.allCases.filter { modifiers.contains($0) }
    }

    var menuKeyEquivalent: String {
        switch key.lowercased() {
        case "return", "enter":
            return "\r"
        case "escape", "esc":
            return String(Character(UnicodeScalar(NSDeleteCharacter)!))
        default:
            return key.lowercased()
        }
    }

    var menuModifierMask: NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []
        if normalizedModifiers.contains(.ctrl) { result.insert(.control) }
        if normalizedModifiers.contains(.alt) { result.insert(.option) }
        if normalizedModifiers.contains(.shift) { result.insert(.shift) }
        if normalizedModifiers.contains(.cmd) { result.insert(.command) }
        return result
    }
}

enum HotkeyAction: Codable, Equatable, Hashable {
    case applyLayoutByIndex(layout: Int)
    case applyLayoutByName(name: String)
    case applyLayoutByID(layoutID: String)
    case cycleNext
    case cyclePrevious

    private enum CodingKeys: String, CodingKey {
        case kind
        case layout
        case name
        case layoutID
    }

    private enum Kind: String, Codable {
        case applyLayoutByIndex
        case applyLayoutByName
        case applyLayoutByID
        case cycleNext
        case cyclePrevious
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .applyLayoutByIndex:
            let layout = try container.decode(Int.self, forKey: .layout)
            guard layout >= 1 else {
                throw DecodingError.dataCorruptedError(forKey: .layout, in: container, debugDescription: "Layout index must be positive.")
            }
            self = .applyLayoutByIndex(layout: layout)
        case .applyLayoutByName:
            self = .applyLayoutByName(name: try container.decode(String.self, forKey: .name))
        case .applyLayoutByID:
            self = .applyLayoutByID(layoutID: try container.decode(String.self, forKey: .layoutID))
        case .cycleNext:
            self = .cycleNext
        case .cyclePrevious:
            self = .cyclePrevious
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .applyLayoutByIndex(layout):
            try container.encode(Kind.applyLayoutByIndex, forKey: .kind)
            try container.encode(layout, forKey: .layout)
        case let .applyLayoutByName(name):
            try container.encode(Kind.applyLayoutByName, forKey: .kind)
            try container.encode(name, forKey: .name)
        case let .applyLayoutByID(layoutID):
            try container.encode(Kind.applyLayoutByID, forKey: .kind)
            try container.encode(layoutID, forKey: .layoutID)
        case .cycleNext:
            try container.encode(Kind.cycleNext, forKey: .kind)
        case .cyclePrevious:
            try container.encode(Kind.cyclePrevious, forKey: .kind)
        }
    }

    func displayName(layouts: [LayoutPreset]) -> String {
        switch self {
        case let .applyLayoutByIndex(layoutIndex):
            let indexedLayouts = layouts.filter(\.includeInLayoutIndex)
            if layoutIndex >= 1, layoutIndex <= indexedLayouts.count {
                return UICopy.applyLayout(indexedLayouts[layoutIndex - 1].name)
            }
            return UICopy.applyLayout(UICopy.unknownLayout)
        case let .applyLayoutByName(name):
            return UICopy.applyLayout(name)
        case let .applyLayoutByID(layoutID):
            if let layout = layouts.first(where: { $0.id == layoutID }) {
                return UICopy.applyLayout(layout.name)
            }
            return UICopy.applyLayout(UICopy.unknownLayout)
        case .cycleNext:
            return UICopy.applyNextLayout
        case .cyclePrevious:
            return UICopy.applyPreviousLayout
        }
    }
}

struct ShortcutBinding: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var isEnabled: Bool
    var shortcut: KeyboardShortcut?
    var action: HotkeyAction

    private enum CodingKeys: String, CodingKey {
        case id
        case isEnabled
        case shortcut
        case action
    }

    init(id: String = UUID().uuidString, isEnabled: Bool = true, shortcut: KeyboardShortcut?, action: HotkeyAction) {
        self.id = id
        self.isEnabled = isEnabled
        self.shortcut = shortcut
        self.action = action
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        shortcut = try container.decodeIfPresent(KeyboardShortcut.self, forKey: .shortcut)
        action = try container.decode(HotkeyAction.self, forKey: .action)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(shortcut, forKey: .shortcut)
        try container.encode(action, forKey: .action)
    }
}

struct GridSelection: Codable, Equatable, Hashable {
    var x: Int
    var y: Int
    var w: Int
    var h: Int
}

struct MenuBarSelection: Codable, Equatable, Hashable {
    var x: Int
    var w: Int
}

enum TriggerRegion: Codable, Equatable, Hashable {
    case screen(GridSelection)
    case menuBar(MenuBarSelection)

    private enum CodingKeys: String, CodingKey {
        case kind
        case gridSelection
        case menuBarSelection
    }

    private enum Kind: String, Codable {
        case screen
        case menuBar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .screen:
            self = .screen(try container.decode(GridSelection.self, forKey: .gridSelection))
        case .menuBar:
            self = .menuBar(try container.decode(MenuBarSelection.self, forKey: .menuBarSelection))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .screen(selection):
            try container.encode(Kind.screen, forKey: .kind)
            try container.encode(selection, forKey: .gridSelection)
        case let .menuBar(selection):
            try container.encode(Kind.menuBar, forKey: .kind)
            try container.encode(selection, forKey: .menuBarSelection)
        }
    }
}

struct LayoutPreset: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var gridColumns: Int
    var gridRows: Int
    var windowSelection: GridSelection
    var triggerRegion: TriggerRegion?
    var includeInLayoutIndex: Bool
    var includeInMenu: Bool

    init(
        id: String,
        name: String,
        gridColumns: Int,
        gridRows: Int,
        windowSelection: GridSelection,
        triggerRegion: TriggerRegion?,
        includeInLayoutIndex: Bool,
        includeInMenu: Bool = true
    ) {
        self.id = id
        self.name = name
        self.gridColumns = gridColumns
        self.gridRows = gridRows
        self.windowSelection = windowSelection
        self.triggerRegion = triggerRegion
        self.includeInLayoutIndex = includeInLayoutIndex
        self.includeInMenu = includeInMenu
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case gridColumns
        case gridRows
        case windowSelection
        case triggerRegion
        case includeInLayoutIndex
        case includeInMenu
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        gridColumns = try container.decode(Int.self, forKey: .gridColumns)
        gridRows = try container.decode(Int.self, forKey: .gridRows)
        windowSelection = try container.decode(GridSelection.self, forKey: .windowSelection)
        triggerRegion = try container.decodeIfPresent(TriggerRegion.self, forKey: .triggerRegion)
        includeInLayoutIndex = try container.decodeIfPresent(Bool.self, forKey: .includeInLayoutIndex) ?? true
        includeInMenu = try container.decodeIfPresent(Bool.self, forKey: .includeInMenu) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(gridColumns, forKey: .gridColumns)
        try container.encode(gridRows, forKey: .gridRows)
        try container.encode(windowSelection, forKey: .windowSelection)
        try container.encodeIfPresent(triggerRegion, forKey: .triggerRegion)
        try container.encode(includeInLayoutIndex, forKey: .includeInLayoutIndex)
        try container.encode(includeInMenu, forKey: .includeInMenu)
    }
}

enum LayoutSetMonitor: Codable, Equatable, Hashable {
    case all
    case main
    case displays([String])

    init(from decoder: Decoder) throws {
        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            var displayIDs: [String] = []
            while !unkeyedContainer.isAtEnd {
                let value = try unkeyedContainer.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty, value.lowercased() != "all", value.lowercased() != "main" else {
                    throw DecodingError.dataCorruptedError(in: unkeyedContainer, debugDescription: "Monitor arrays may only contain explicit display IDs.")
                }
                displayIDs.append(value)
            }
            guard !displayIDs.isEmpty else {
                throw DecodingError.dataCorruptedError(in: unkeyedContainer, debugDescription: "Monitor array must not be empty.")
            }
            self = .displays(displayIDs)
            return
        }

        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Monitor value must not be empty.")
        }

        switch rawValue.lowercased() {
        case "all":
            self = .all
        case "main":
            self = .main
        default:
            self = .displays([rawValue])
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .all:
            var container = encoder.singleValueContainer()
            try container.encode("all")
        case .main:
            var container = encoder.singleValueContainer()
            try container.encode("main")
        case let .displays(displayIDs):
            if displayIDs.count == 1, let firstID = displayIDs.first {
                var container = encoder.singleValueContainer()
                try container.encode(firstID)
            } else {
                var container = encoder.unkeyedContainer()
                for displayID in displayIDs {
                    try container.encode(displayID)
                }
            }
        }
    }

    var explicitDisplayIDs: [String] {
        switch self {
        case .displays(let displayIDs):
            return displayIDs
        case .all, .main:
            return []
        }
    }
}

struct LayoutSet: Codable, Equatable, Hashable {
    var monitor: LayoutSetMonitor
    var layouts: [LayoutPreset]
}

struct LayoutGroup: Codable, Equatable, Hashable {
    var name: String
    var includeInGroupCycle: Bool
    var sets: [LayoutSet]
}

struct RGBAColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var nsColor: NSColor {
        NSColor(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    var hexString: String {
        let redValue = RGBAColor.hexComponent(for: red)
        let greenValue = RGBAColor.hexComponent(for: green)
        let blueValue = RGBAColor.hexComponent(for: blue)
        let alphaValue = RGBAColor.hexComponent(for: alpha)
        return String(format: "#%02X%02X%02X%02X", redValue, greenValue, blueValue, alphaValue)
    }

    init(hexString: String) throws {
        let trimmed = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else {
            throw RGBAColorHexError.invalidFormat(hexString)
        }

        let hex = String(trimmed.dropFirst())
        let components: [UInt8]
        switch hex.count {
        case 6:
            var parsed = try RGBAColor.parseHexComponents(hex)
            parsed.append(255)
            components = parsed
        case 8:
            components = try RGBAColor.parseHexComponents(hex)
        default:
            throw RGBAColorHexError.invalidLength(hexString)
        }

        red = Double(components[0]) / 255
        green = Double(components[1]) / 255
        blue = Double(components[2]) / 255
        alpha = Double(components[3]) / 255
    }

    private static func parseHexComponents(_ hex: String) throws -> [UInt8] {
        try stride(from: 0, to: hex.count, by: 2).map { index in
            let startIndex = hex.index(hex.startIndex, offsetBy: index)
            let endIndex = hex.index(startIndex, offsetBy: 2)
            let component = String(hex[startIndex..<endIndex])
            guard let value = UInt8(component, radix: 16) else {
                throw RGBAColorHexError.invalidFormat("#\(hex)")
            }
            return value
        }
    }

    private static func hexComponent(for value: Double) -> UInt8 {
        UInt8(max(0, min(255, Int((value * 255).rounded()))))
    }
}

enum RGBAColorHexError: Error {
    case invalidFormat(String)
    case invalidLength(String)
}

struct GeneralSettings: Codable, Equatable {
    var isEnabled: Bool
    var excludedBundleIDs: [String]
    var excludedWindowTitles: [String]
    var activeLayoutGroup: String

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case excludedBundleIDs
        case excludedWindowTitles
        case activeLayoutGroup
    }

    init(
        isEnabled: Bool,
        excludedBundleIDs: [String],
        excludedWindowTitles: [String],
        activeLayoutGroup: String
    ) {
        self.isEnabled = isEnabled
        self.excludedBundleIDs = excludedBundleIDs
        self.excludedWindowTitles = excludedWindowTitles
        self.activeLayoutGroup = activeLayoutGroup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        excludedBundleIDs = try container.decode([String].self, forKey: .excludedBundleIDs)
        excludedWindowTitles = try container.decode([String].self, forKey: .excludedWindowTitles)
        activeLayoutGroup = try container.decode(String.self, forKey: .activeLayoutGroup)
    }
}

struct AppearanceSettings: Codable, Equatable {
    var renderTriggerAreas: Bool
    var triggerOpacity: Double
    var triggerGap: Double
    var triggerStrokeColor: RGBAColor
    var renderWindowHighlight: Bool
    var highlightFillOpacity: Double
    var highlightStrokeWidth: Double
    var highlightStrokeColor: RGBAColor

    private enum CodingKeys: String, CodingKey {
        case renderTriggerAreas
        case triggerOpacity
        case triggerGap
        case triggerStrokeColor
        case renderWindowHighlight
        case highlightFillOpacity
        case highlightStrokeWidth
        case highlightStrokeColor
    }

    init(
        renderTriggerAreas: Bool,
        triggerOpacity: Double,
        triggerGap: Double,
        triggerStrokeColor: RGBAColor,
        renderWindowHighlight: Bool,
        highlightFillOpacity: Double,
        highlightStrokeWidth: Double,
        highlightStrokeColor: RGBAColor
    ) {
        self.renderTriggerAreas = renderTriggerAreas
        self.triggerOpacity = triggerOpacity
        self.triggerGap = triggerGap
        self.triggerStrokeColor = triggerStrokeColor
        self.renderWindowHighlight = renderWindowHighlight
        self.highlightFillOpacity = highlightFillOpacity
        self.highlightStrokeWidth = highlightStrokeWidth
        self.highlightStrokeColor = highlightStrokeColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        renderTriggerAreas = try container.decode(Bool.self, forKey: .renderTriggerAreas)
        triggerOpacity = try container.decode(Double.self, forKey: .triggerOpacity)
        triggerGap = try container.decode(Double.self, forKey: .triggerGap)
        triggerStrokeColor = try container.decodeIfPresent(RGBAColor.self, forKey: .triggerStrokeColor) ?? RGBAColor.defaultTriggerStrokeColor
        renderWindowHighlight = try container.decode(Bool.self, forKey: .renderWindowHighlight)
        highlightFillOpacity = try container.decode(Double.self, forKey: .highlightFillOpacity)
        highlightStrokeWidth = try container.decode(Double.self, forKey: .highlightStrokeWidth)
        highlightStrokeColor = try container.decode(RGBAColor.self, forKey: .highlightStrokeColor)
    }
}

struct DragTriggerSettings: Codable, Equatable {
    var middleMouseButtonNumber: Int
    var enableMiddleMouseDrag: Bool
    var enableModifierLeftMouseDrag: Bool
    var preferLayoutMode: Bool
    var modifierGroups: [[ModifierKey]]
    var activationDelaySeconds: Double
    var activationMoveThreshold: Double

    enum CodingKeys: String, CodingKey {
        case middleMouseButtonNumber
        case enableMiddleMouseDrag
        case enableModifierLeftMouseDrag
        case preferLayoutMode
        case modifierGroups
        case activationDelaySeconds
        case activationMoveThreshold
    }

    init(
        middleMouseButtonNumber: Int,
        enableMiddleMouseDrag: Bool,
        enableModifierLeftMouseDrag: Bool,
        preferLayoutMode: Bool,
        modifierGroups: [[ModifierKey]],
        activationDelaySeconds: Double,
        activationMoveThreshold: Double
    ) {
        self.middleMouseButtonNumber = middleMouseButtonNumber
        self.enableMiddleMouseDrag = enableMiddleMouseDrag
        self.enableModifierLeftMouseDrag = enableModifierLeftMouseDrag
        self.preferLayoutMode = preferLayoutMode
        self.modifierGroups = modifierGroups
        self.activationDelaySeconds = activationDelaySeconds
        self.activationMoveThreshold = activationMoveThreshold
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        middleMouseButtonNumber = try container.decode(Int.self, forKey: .middleMouseButtonNumber)
        enableMiddleMouseDrag = try container.decode(Bool.self, forKey: .enableMiddleMouseDrag)
        enableModifierLeftMouseDrag = try container.decode(Bool.self, forKey: .enableModifierLeftMouseDrag)
        preferLayoutMode = try container.decodeIfPresent(Bool.self, forKey: .preferLayoutMode) ?? true
        modifierGroups = try container.decode([[ModifierKey]].self, forKey: .modifierGroups)
        activationDelaySeconds = try container.decode(Double.self, forKey: .activationDelaySeconds)
        activationMoveThreshold = try container.decode(Double.self, forKey: .activationMoveThreshold)
    }
}

struct HotkeySettings: Codable, Equatable {
    var bindings: [ShortcutBinding]

    func firstShortcut(for action: HotkeyAction) -> KeyboardShortcut? {
        bindings.first {
            $0.isEnabled && $0.action == action && $0.shortcut != nil
        }?.shortcut
    }
}

struct AppConfiguration: Codable, Equatable {
    static let builtInGroupName = "built-in"
    static let fullscreenGroupName = "fullscreen"

    var general: GeneralSettings
    var appearance: AppearanceSettings
    var dragTriggers: DragTriggerSettings
    var hotkeys: HotkeySettings
    var layoutGroups: [LayoutGroup]
    var monitors: [String: String]

    var activeGroup: LayoutGroup? {
        layoutGroups.first(where: { $0.name == general.activeLayoutGroup })
    }

    var layouts: [LayoutPreset] {
        flattenedLayouts(in: activeGroup)
    }

    func flattenedLayouts(in group: LayoutGroup?) -> [LayoutPreset] {
        group?.sets.flatMap(\.layouts) ?? []
    }

    func layoutGroupNames() -> [String] {
        layoutGroups.map(\.name)
    }

    func nextLayoutGroupNameInCycle() -> String? {
        layoutGroupNameInCycle(direction: 1)
    }

    func previousLayoutGroupNameInCycle() -> String? {
        layoutGroupNameInCycle(direction: -1)
    }

    private func layoutGroupNameInCycle(direction: Int) -> String? {
        guard !layoutGroups.isEmpty else {
            return nil
        }

        guard let currentIndex = layoutGroups.firstIndex(where: { $0.name == general.activeLayoutGroup }) else {
            if direction >= 0 {
                return layoutGroups.first(where: \.includeInGroupCycle)?.name
            }
            return layoutGroups.last(where: \.includeInGroupCycle)?.name
        }

        for offset in 1...layoutGroups.count {
            let nextIndex = (currentIndex + offset * direction + layoutGroups.count) % layoutGroups.count
            let nextGroup = layoutGroups[nextIndex]
            guard nextGroup.includeInGroupCycle else {
                continue
            }
            return nextGroup.name == general.activeLayoutGroup ? nil : nextGroup.name
        }

        return nil
    }

    mutating func removeLayout(id: String) {
        let currentLayouts = layouts
        guard let removedIndex = currentLayouts.firstIndex(where: { $0.id == id }) else {
            return
        }
        let removedLayout = currentLayouts[removedIndex]

        guard let location = activeGroupLayoutLocation(for: id) else {
            return
        }
        layoutGroups[location.groupIndex].sets[location.setIndex].layouts.remove(at: location.layoutIndex)

        guard removedLayout.includeInLayoutIndex else {
            return
        }

        let removedShortcutIndex = currentLayouts[..<removedIndex].filter(\.includeInLayoutIndex).count + 1

        hotkeys.bindings.removeAll { binding in
            if case let .applyLayoutByIndex(layoutIndex) = binding.action {
                return layoutIndex == removedShortcutIndex
            }
            return false
        }

        hotkeys.bindings = hotkeys.bindings.map { binding in
            guard case let .applyLayoutByIndex(layoutIndex) = binding.action, layoutIndex > removedShortcutIndex else {
                return binding
            }

            var updatedBinding = binding
            updatedBinding.action = .applyLayoutByIndex(layout: layoutIndex - 1)
            return updatedBinding
        }
    }

    mutating func moveLayout(id: String, to targetIndex: Int) {
        let currentLayouts = layouts
        guard let sourceIndex = currentLayouts.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard let sourceLocation = activeGroupLayoutLocation(for: id) else {
            return
        }

        var destinationFlattenedIndex = max(0, min(targetIndex, currentLayouts.count))
        if sourceIndex < destinationFlattenedIndex {
            destinationFlattenedIndex -= 1
        }

        let destinationLocation = activeGroupInsertionLocation(forFlattenedIndex: destinationFlattenedIndex)
        guard destinationLocation.setIndex == sourceLocation.setIndex else {
            return
        }

        var setLayouts = layoutGroups[sourceLocation.groupIndex].sets[sourceLocation.setIndex].layouts
        let movedLayout = setLayouts.remove(at: sourceLocation.layoutIndex)

        let localDestinationIndex = destinationLocation.layoutIndex
        let boundedDestinationIndex = max(0, min(localDestinationIndex, setLayouts.count))
        setLayouts.insert(movedLayout, at: boundedDestinationIndex)
        layoutGroups[sourceLocation.groupIndex].sets[sourceLocation.setIndex].layouts = setLayouts
    }

    private func activeGroupLayoutLocation(for layoutID: String) -> (groupIndex: Int, setIndex: Int, layoutIndex: Int)? {
        guard let groupIndex = layoutGroups.firstIndex(where: { $0.name == general.activeLayoutGroup }) else {
            return nil
        }

        for setIndex in layoutGroups[groupIndex].sets.indices {
            if let layoutIndex = layoutGroups[groupIndex].sets[setIndex].layouts.firstIndex(where: { $0.id == layoutID }) {
                return (groupIndex, setIndex, layoutIndex)
            }
        }

        return nil
    }

    private func activeGroupInsertionLocation(forFlattenedIndex flattenedIndex: Int) -> (setIndex: Int, layoutIndex: Int) {
        guard let group = activeGroup else {
            return (0, 0)
        }

        var remainingIndex = flattenedIndex
        for setIndex in group.sets.indices {
            let setLayouts = group.sets[setIndex].layouts
            if remainingIndex <= setLayouts.count {
                return (setIndex, remainingIndex)
            }
            remainingIndex -= setLayouts.count
        }

        if let lastSetIndex = group.sets.indices.last {
            return (lastSetIndex, group.sets[lastSetIndex].layouts.count)
        }

        return (0, 0)
    }
}
