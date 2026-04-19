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
        case "tab":
            return "\t"
        case "space":
            return " "
        case "delete":
            return String(Character(UnicodeScalar(NSBackspaceCharacter)!))
        case "forwarddelete":
            return String(Character(UnicodeScalar(NSDeleteFunctionKey)!))
        case "left":
            return String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!))
        case "right":
            return String(Character(UnicodeScalar(NSRightArrowFunctionKey)!))
        case "up":
            return String(Character(UnicodeScalar(NSUpArrowFunctionKey)!))
        case "down":
            return String(Character(UnicodeScalar(NSDownArrowFunctionKey)!))
        case "home":
            return String(Character(UnicodeScalar(NSHomeFunctionKey)!))
        case "end":
            return String(Character(UnicodeScalar(NSEndFunctionKey)!))
        case "pageup":
            return String(Character(UnicodeScalar(NSPageUpFunctionKey)!))
        case "pagedown":
            return String(Character(UnicodeScalar(NSPageDownFunctionKey)!))
        case "insert", "help":
            return String(Character(UnicodeScalar(NSHelpFunctionKey)!))
        case "f1":
            return String(Character(UnicodeScalar(NSF1FunctionKey)!))
        case "f2":
            return String(Character(UnicodeScalar(NSF2FunctionKey)!))
        case "f3":
            return String(Character(UnicodeScalar(NSF3FunctionKey)!))
        case "f4":
            return String(Character(UnicodeScalar(NSF4FunctionKey)!))
        case "f5":
            return String(Character(UnicodeScalar(NSF5FunctionKey)!))
        case "f6":
            return String(Character(UnicodeScalar(NSF6FunctionKey)!))
        case "f7":
            return String(Character(UnicodeScalar(NSF7FunctionKey)!))
        case "f8":
            return String(Character(UnicodeScalar(NSF8FunctionKey)!))
        case "f9":
            return String(Character(UnicodeScalar(NSF9FunctionKey)!))
        case "f10":
            return String(Character(UnicodeScalar(NSF10FunctionKey)!))
        case "f11":
            return String(Character(UnicodeScalar(NSF11FunctionKey)!))
        case "f12":
            return String(Character(UnicodeScalar(NSF12FunctionKey)!))
        case "f13":
            return String(Character(UnicodeScalar(NSF13FunctionKey)!))
        case "f14":
            return String(Character(UnicodeScalar(NSF14FunctionKey)!))
        case "f15":
            return String(Character(UnicodeScalar(NSF15FunctionKey)!))
        case "f16":
            return String(Character(UnicodeScalar(NSF16FunctionKey)!))
        case "f17":
            return String(Character(UnicodeScalar(NSF17FunctionKey)!))
        case "f18":
            return String(Character(UnicodeScalar(NSF18FunctionKey)!))
        case "f19":
            return String(Character(UnicodeScalar(NSF19FunctionKey)!))
        case "f20":
            return String(Character(UnicodeScalar(NSF20FunctionKey)!))
        case "keypadenter":
            return "\u{03}"
        case "keypaddecimal":
            return "."
        case "keypadmultiply":
            return "*"
        case "keypadplus":
            return "+"
        case "keypaddivide":
            return "/"
        case "keypadminus":
            return "-"
        case "keypadequals":
            return "="
        case "keypad0":
            return "0"
        case "keypad1":
            return "1"
        case "keypad2":
            return "2"
        case "keypad3":
            return "3"
        case "keypad4":
            return "4"
        case "keypad5":
            return "5"
        case "keypad6":
            return "6"
        case "keypad7":
            return "7"
        case "keypad8":
            return "8"
        case "keypad9":
            return "9"
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

enum TriggerHighlightMode: String, Codable, CaseIterable, Equatable, Hashable {
    case all
    case current
    case none
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
    var protect: Bool
    var sets: [LayoutSet]

    init(
        name: String,
        includeInGroupCycle: Bool,
        protect: Bool = false,
        sets: [LayoutSet]
    ) {
        self.name = name
        self.includeInGroupCycle = includeInGroupCycle
        self.protect = protect
        self.sets = sets
    }
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
    static let defaultMouseButtonNumber = 3

    var isEnabled: Bool
    var launchAtLogin: Bool
    var excludedBundleIDs: [String]
    var excludedWindowTitles: [String]
    var activeLayoutGroup: String
    var mouseButtonNumber: Int

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case launchAtLogin
        case excludedBundleIDs
        case excludedWindowTitles
        case activeLayoutGroup
        case mouseButtonNumber
    }

    init(
        isEnabled: Bool,
        launchAtLogin: Bool,
        excludedBundleIDs: [String],
        excludedWindowTitles: [String],
        activeLayoutGroup: String,
        mouseButtonNumber: Int
    ) {
        self.isEnabled = isEnabled
        self.launchAtLogin = launchAtLogin
        self.excludedBundleIDs = excludedBundleIDs
        self.excludedWindowTitles = excludedWindowTitles
        self.activeLayoutGroup = activeLayoutGroup
        self.mouseButtonNumber = Self.sanitizedMouseButtonNumber(mouseButtonNumber)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        launchAtLogin = (try? container.decode(Bool.self, forKey: .launchAtLogin)) ?? false
        excludedBundleIDs = try container.decode([String].self, forKey: .excludedBundleIDs)
        excludedWindowTitles = try container.decode([String].self, forKey: .excludedWindowTitles)
        activeLayoutGroup = try container.decode(String.self, forKey: .activeLayoutGroup)
        mouseButtonNumber = Self.sanitizedMouseButtonNumber(try? container.decode(Int.self, forKey: .mouseButtonNumber))
    }

    private static func sanitizedMouseButtonNumber(_ value: Int?) -> Int {
        guard let value, value >= defaultMouseButtonNumber else {
            return defaultMouseButtonNumber
        }
        return value
    }
}

struct AppearanceSettings: Codable, Equatable {
    var triggerHighlightMode: TriggerHighlightMode
    var triggerFillOpacity: Double
    var triggerGap: Int
    var triggerStrokeWidth: Int
    var triggerStrokeColor: RGBAColor
    var layoutGap: Int
    var renderWindowHighlight: Bool
    var highlightFillOpacity: Double
    var highlightStrokeWidth: Int
    var highlightStrokeColor: RGBAColor

    private enum CodingKeys: String, CodingKey {
        case triggerHighlightMode
        case triggerFillOpacity
        case triggerGap
        case triggerStrokeWidth
        case triggerStrokeColor
        case layoutGap
        case renderWindowHighlight
        case highlightFillOpacity
        case highlightStrokeWidth
        case highlightStrokeColor
    }

    init(
        triggerHighlightMode: TriggerHighlightMode,
        triggerFillOpacity: Double,
        triggerGap: Int,
        triggerStrokeWidth: Int,
        triggerStrokeColor: RGBAColor,
        layoutGap: Int = AppearanceValueNormalizer.defaultLayoutGap,
        renderWindowHighlight: Bool,
        highlightFillOpacity: Double,
        highlightStrokeWidth: Int,
        highlightStrokeColor: RGBAColor
    ) {
        self.triggerHighlightMode = triggerHighlightMode
        self.triggerFillOpacity = AppearanceValueNormalizer.normalizeOpacity(triggerFillOpacity)
        self.triggerGap = AppearanceValueNormalizer.normalizeNonNegativeInt(triggerGap, defaultValue: 0)
        self.triggerStrokeWidth = AppearanceValueNormalizer.normalizeNonNegativeInt(triggerStrokeWidth, defaultValue: 0)
        self.triggerStrokeColor = triggerStrokeColor
        self.layoutGap = AppearanceValueNormalizer.normalizeLayoutGap(layoutGap)
        self.renderWindowHighlight = renderWindowHighlight
        self.highlightFillOpacity = AppearanceValueNormalizer.normalizeOpacity(highlightFillOpacity)
        self.highlightStrokeWidth = AppearanceValueNormalizer.normalizeNonNegativeInt(highlightStrokeWidth, defaultValue: 0)
        self.highlightStrokeColor = highlightStrokeColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rawMode = try? container.decode(String.self, forKey: .triggerHighlightMode) {
            triggerHighlightMode = TriggerHighlightMode(rawValue: rawMode) ?? .all
        } else {
            triggerHighlightMode = .none
        }
        triggerFillOpacity = AppearanceValueNormalizer.decodeOpacity(from: container, forKey: .triggerFillOpacity, defaultValue: 0.08)
        triggerGap = AppearanceValueNormalizer.decodeNonNegativeInt(from: container, forKey: .triggerGap, defaultValue: 0)
        triggerStrokeWidth = AppearanceValueNormalizer.decodeNonNegativeInt(from: container, forKey: .triggerStrokeWidth, defaultValue: 2)
        triggerStrokeColor = try container.decodeIfPresent(RGBAColor.self, forKey: .triggerStrokeColor) ?? RGBAColor.defaultTriggerStrokeColor
        layoutGap = AppearanceValueNormalizer.decodeLayoutGap(from: container, forKey: .layoutGap)
        renderWindowHighlight = try container.decode(Bool.self, forKey: .renderWindowHighlight)
        highlightFillOpacity = AppearanceValueNormalizer.decodeOpacity(from: container, forKey: .highlightFillOpacity)
        highlightStrokeWidth = AppearanceValueNormalizer.decodeNonNegativeInt(from: container, forKey: .highlightStrokeWidth, defaultValue: 0)
        highlightStrokeColor = try container.decode(RGBAColor.self, forKey: .highlightStrokeColor)
    }

    var renderTriggerAreas: Bool {
        triggerHighlightMode != .none
    }

    var effectiveLayoutGap: Int {
        AppearanceValueNormalizer.normalizeLayoutGap(layoutGap)
    }

}

enum AppearanceValueNormalizer {
    static let defaultLayoutGap = 1

    static func normalizeLayoutGap(_ value: Int) -> Int {
        guard value >= 0 else {
            return defaultLayoutGap
        }

        return value
    }

    static func normalizeLayoutGap(_ value: Double) -> Int {
        guard value.isFinite, value >= 0, value.rounded(.towardZero) == value else {
            return defaultLayoutGap
        }

        return Int(value)
    }

    static func normalizeOpacity(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }

        if value <= 1 {
            return min(max(value, 0), 1)
        }

        return min(max(value / 100, 0), 1)
    }

    static func normalizeNonNegativeInt(_ value: Int, defaultValue: Int = 0) -> Int {
        guard value >= 0 else {
            return defaultValue
        }
        return value
    }

    static func normalizeNonNegativeInt(_ value: Double, defaultValue: Int = 0) -> Int {
        guard value.isFinite, value >= 0, value.rounded(.towardZero) == value else {
            return defaultValue
        }
        return Int(value)
    }

    static func decodeLayoutGap<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) -> Int {
        if let value = try? container.decode(Int.self, forKey: key) {
            return normalizeLayoutGap(value)
        }

        if let value = try? container.decode(Double.self, forKey: key) {
            return normalizeLayoutGap(value)
        }

        return defaultLayoutGap
    }

    static func decodeOpacity<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) -> Double {
        decodeOpacity(from: container, forKey: key, defaultValue: 0)
    }

    static func decodeOpacity<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: Double
    ) -> Double {
        if let value = try? container.decode(Double.self, forKey: key) {
            return normalizeOpacity(value)
        }

        if let value = try? container.decode(Int.self, forKey: key) {
            return normalizeOpacity(Double(value))
        }

        return defaultValue
    }

    static func decodeNonNegativeInt<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: Int = 0
    ) -> Int {
        if let value = try? container.decode(Int.self, forKey: key) {
            return normalizeNonNegativeInt(value, defaultValue: defaultValue)
        }

        if let value = try? container.decode(Double.self, forKey: key) {
            return normalizeNonNegativeInt(value, defaultValue: defaultValue)
        }

        return defaultValue
    }

    static func decodeBoundedInt<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key,
        defaultValue: Int,
        range: ClosedRange<Int>
    ) -> Int {
        if let value = try? container.decode(Int.self, forKey: key) {
            return normalizeBoundedInt(value, defaultValue: defaultValue, range: range)
        }

        if let value = try? container.decode(Double.self, forKey: key) {
            return normalizeBoundedInt(value, defaultValue: defaultValue, range: range)
        }

        return defaultValue
    }

    static func normalizeBoundedInt(
        _ value: Int,
        defaultValue: Int,
        range: ClosedRange<Int>
    ) -> Int {
        guard range.contains(value) else {
            return defaultValue
        }

        return value
    }

    static func normalizeBoundedInt(
        _ value: Double,
        defaultValue: Int,
        range: ClosedRange<Int>
    ) -> Int {
        guard value.isFinite else {
            return defaultValue
        }

        return normalizeBoundedInt(Int(value.rounded()), defaultValue: defaultValue, range: range)
    }
}

struct DragTriggerSettings: Codable, Equatable {
    static let defaultActivationDelayMilliseconds = 300
    static let activationDelayMillisecondsRange = 0 ... 1_000

    var enableMouseButtonDrag: Bool
    var enableModifierLeftMouseDrag: Bool
    var preferLayoutMode: Bool
    var applyLayoutImmediatelyWhileDragging: Bool
    var modifierGroups: [[ModifierKey]]
    var activationDelayMilliseconds: Int
    var activationMoveThreshold: Double

    enum CodingKeys: String, CodingKey {
        case enableMouseButtonDrag
        case enableModifierLeftMouseDrag
        case preferLayoutMode
        case applyLayoutImmediatelyWhileDragging
        case modifierGroups
        case activationDelayMilliseconds
        case activationMoveThreshold
    }

    init(
        enableMouseButtonDrag: Bool,
        enableModifierLeftMouseDrag: Bool,
        preferLayoutMode: Bool,
        applyLayoutImmediatelyWhileDragging: Bool,
        modifierGroups: [[ModifierKey]],
        activationDelayMilliseconds: Int,
        activationMoveThreshold: Double
    ) {
        self.enableMouseButtonDrag = enableMouseButtonDrag
        self.enableModifierLeftMouseDrag = enableModifierLeftMouseDrag
        self.preferLayoutMode = preferLayoutMode
        self.applyLayoutImmediatelyWhileDragging = applyLayoutImmediatelyWhileDragging
        self.modifierGroups = modifierGroups
        self.activationDelayMilliseconds = AppearanceValueNormalizer.normalizeBoundedInt(
            activationDelayMilliseconds,
            defaultValue: Self.defaultActivationDelayMilliseconds,
            range: Self.activationDelayMillisecondsRange
        )
        self.activationMoveThreshold = activationMoveThreshold
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enableMouseButtonDrag = try container.decode(Bool.self, forKey: .enableMouseButtonDrag)
        enableModifierLeftMouseDrag = try container.decode(Bool.self, forKey: .enableModifierLeftMouseDrag)
        preferLayoutMode = try container.decodeIfPresent(Bool.self, forKey: .preferLayoutMode) ?? true
        applyLayoutImmediatelyWhileDragging = (try? container.decode(Bool.self, forKey: .applyLayoutImmediatelyWhileDragging)) ?? false
        modifierGroups = try container.decode([[ModifierKey]].self, forKey: .modifierGroups)
        activationDelayMilliseconds = AppearanceValueNormalizer.decodeBoundedInt(
            from: container,
            forKey: .activationDelayMilliseconds,
            defaultValue: Self.defaultActivationDelayMilliseconds,
            range: Self.activationDelayMillisecondsRange
        )
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
    static let defaultGroupName = "default"
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
