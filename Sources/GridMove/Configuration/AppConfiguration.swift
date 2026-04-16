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

    var displayString: String {
        let modifierString = normalizedModifiers.map(\.displayName).joined(separator: " + ")
        let keyString = key == "return" ? "return" : key
        return modifierString.isEmpty ? keyString : "\(modifierString) + \(keyString)"
    }

    var symbolDisplayString: String {
        let modifierSymbols = normalizedModifiers.map(\.symbol).joined()
        let keySymbol = ShortcutKeyMap.symbolDisplayString(for: key)
        return modifierSymbols + keySymbol
    }
}

enum HotkeyAction: Codable, Equatable, Hashable {
    case applyLayout(layoutID: String)
    case cycleNext
    case cyclePrevious

    private enum CodingKeys: String, CodingKey {
        case kind
        case layoutID
    }

    private enum Kind: String, Codable {
        case applyLayout
        case cycleNext
        case cyclePrevious
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .applyLayout:
            self = .applyLayout(layoutID: try container.decode(String.self, forKey: .layoutID))
        case .cycleNext:
            self = .cycleNext
        case .cyclePrevious:
            self = .cyclePrevious
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .applyLayout(layoutID):
            try container.encode(Kind.applyLayout, forKey: .kind)
            try container.encode(layoutID, forKey: .layoutID)
        case .cycleNext:
            try container.encode(Kind.cycleNext, forKey: .kind)
        case .cyclePrevious:
            try container.encode(Kind.cyclePrevious, forKey: .kind)
        }
    }

    func displayName(layouts: [LayoutPreset]) -> String {
        switch self {
        case let .applyLayout(layoutID):
            return layouts.first(where: { $0.id == layoutID })?.name ?? "Unknown Layout"
        case .cycleNext:
            return "Next Layout"
        case .cyclePrevious:
            return "Previous Layout"
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
    var triggerRegion: TriggerRegion
    var includeInCycle: Bool
}

struct RGBAColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var nsColor: NSColor {
        NSColor(
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }
}

struct GeneralSettings: Codable, Equatable {
    var isEnabled: Bool
    var excludedBundleIDs: [String]
    var excludedWindowTitles: [String]

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case excludedBundleIDs
        case excludedWindowTitles
    }

    init(
        isEnabled: Bool,
        excludedBundleIDs: [String],
        excludedWindowTitles: [String]
    ) {
        self.isEnabled = isEnabled
        self.excludedBundleIDs = excludedBundleIDs
        self.excludedWindowTitles = excludedWindowTitles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        excludedBundleIDs = try container.decode([String].self, forKey: .excludedBundleIDs)
        excludedWindowTitles = try container.decode([String].self, forKey: .excludedWindowTitles)
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
    var modifierGroups: [[ModifierKey]]
    var activationDelaySeconds: Double
    var activationMoveThreshold: Double
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
    var general: GeneralSettings
    var appearance: AppearanceSettings
    var dragTriggers: DragTriggerSettings
    var hotkeys: HotkeySettings
    var layouts: [LayoutPreset]

    static let builtInExcludedBundleIDs = [
        "com.apple.Spotlight",
        "com.apple.dock",
        "com.apple.notificationcenterui",
    ]

    static let builtInExcludedWindowTitles = [
        "Notification Center",
        "通知中心",
        "Spotlight",
        "聚焦",
    ]

    static var defaultLayouts: [LayoutPreset] {
        [
            LayoutPreset(id: "layout-1", name: "Left 1/3", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 4, h: 6), triggerRegion: .screen(GridSelection(x: 0, y: 0, w: 2, h: 6)), includeInCycle: true),
            LayoutPreset(id: "layout-2", name: "Left 1/2", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 6, h: 6), triggerRegion: .screen(GridSelection(x: 2, y: 2, w: 3, h: 2)), includeInCycle: true),
            LayoutPreset(id: "layout-3", name: "Left 2/3", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 8, h: 6), triggerRegion: .screen(GridSelection(x: 2, y: 0, w: 3, h: 2)), includeInCycle: true),
            LayoutPreset(id: "layout-4", name: "Center", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 3, y: 1, w: 6, h: 4), triggerRegion: .screen(GridSelection(x: 5, y: 2, w: 2, h: 2)), includeInCycle: true),
            LayoutPreset(id: "layout-5", name: "Right 2/3", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 4, y: 0, w: 8, h: 6), triggerRegion: .screen(GridSelection(x: 7, y: 0, w: 3, h: 2)), includeInCycle: true),
            LayoutPreset(id: "layout-6", name: "Right 1/2", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 6, y: 0, w: 6, h: 6), triggerRegion: .screen(GridSelection(x: 7, y: 2, w: 3, h: 2)), includeInCycle: true),
            LayoutPreset(id: "layout-7", name: "Right 1/3", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 8, y: 0, w: 4, h: 6), triggerRegion: .screen(GridSelection(x: 10, y: 2, w: 2, h: 2)), includeInCycle: true),
            LayoutPreset(id: "layout-8", name: "Right 1/3 Top", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 8, y: 0, w: 4, h: 3), triggerRegion: .screen(GridSelection(x: 10, y: 0, w: 2, h: 2)), includeInCycle: true),
            LayoutPreset(id: "layout-9", name: "Right 1/3 Bottom", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 8, y: 3, w: 4, h: 3), triggerRegion: .screen(GridSelection(x: 10, y: 4, w: 2, h: 2)), includeInCycle: true),
            LayoutPreset(id: "layout-10", name: "Fill all screen", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6), triggerRegion: .screen(GridSelection(x: 5, y: 0, w: 2, h: 2)), includeInCycle: true),
            LayoutPreset(id: "layout-11", name: "Fill all screen (Menu Bar)", gridColumns: 12, gridRows: 6, windowSelection: GridSelection(x: 0, y: 0, w: 12, h: 6), triggerRegion: .menuBar(MenuBarSelection(x: 1, w: 4)), includeInCycle: false),
        ]
    }

    static var defaultBindings: [ShortcutBinding] {
        let layoutIDs = defaultLayouts.map(\.id)
        return [
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "l"), action: .cycleNext),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "j"), action: .cyclePrevious),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "\\"), action: .applyLayout(layoutID: layoutIDs[3])),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "["), action: .applyLayout(layoutID: layoutIDs[1])),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "]"), action: .applyLayout(layoutID: layoutIDs[5])),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: ";"), action: .applyLayout(layoutID: layoutIDs[2])),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "'"), action: .applyLayout(layoutID: layoutIDs[6])),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "-"), action: .applyLayout(layoutID: layoutIDs[0])),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "="), action: .applyLayout(layoutID: layoutIDs[4])),
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.ctrl, .cmd, .shift, .alt], key: "return"), action: .applyLayout(layoutID: layoutIDs[9])),
        ]
    }

    static let defaultValue = AppConfiguration(
        general: GeneralSettings(
            isEnabled: true,
            excludedBundleIDs: ["com.apple.Spotlight"],
            excludedWindowTitles: []
        ),
        appearance: AppearanceSettings(
            renderTriggerAreas: true,
            triggerOpacity: 0.2,
            triggerGap: 2,
            triggerStrokeColor: .defaultTriggerStrokeColor,
            renderWindowHighlight: true,
            highlightFillOpacity: 0.08,
            highlightStrokeWidth: 3,
            highlightStrokeColor: RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)
        ),
        dragTriggers: DragTriggerSettings(
            middleMouseButtonNumber: 2,
            enableMiddleMouseDrag: true,
            enableModifierLeftMouseDrag: true,
            modifierGroups: [
                [.ctrl, .cmd, .shift, .alt],
            ],
            activationDelaySeconds: 0.3,
            activationMoveThreshold: 10
        ),
        hotkeys: HotkeySettings(bindings: defaultBindings),
        layouts: defaultLayouts
    )

    mutating func removeLayout(id: String) {
        layouts.removeAll { $0.id == id }
        hotkeys.bindings.removeAll { binding in
            if case let .applyLayout(layoutID) = binding.action {
                return layoutID == id
            }
            return false
        }
    }

    mutating func moveLayout(id: String, to targetIndex: Int) {
        guard let sourceIndex = layouts.firstIndex(where: { $0.id == id }) else {
            return
        }

        var destinationIndex = targetIndex
        if sourceIndex < destinationIndex {
            destinationIndex -= 1
        }
        destinationIndex = max(0, min(destinationIndex, layouts.count - 1))

        let movedLayout = layouts.remove(at: sourceIndex)
        layouts.insert(movedLayout, at: destinationIndex)
    }
}

private extension RGBAColor {
    static var defaultTriggerStrokeColor: RGBAColor {
        let resolvedColor = NSColor.controlAccentColor.usingColorSpace(.deviceRGB) ?? .systemBlue
        return RGBAColor(
            red: resolvedColor.redComponent,
            green: resolvedColor.greenComponent,
            blue: resolvedColor.blueComponent,
            alpha: 0.2
        )
    }
}

private extension ModifierKey {
    var symbol: String {
        switch self {
        case .ctrl:
            return "⌃"
        case .cmd:
            return "⌘"
        case .shift:
            return "⇧"
        case .alt:
            return "⌥"
        }
    }
}

enum ShortcutKeyMap {
    static func keyCode(for key: String) -> CGKeyCode? {
        switch key.lowercased() {
        case "a": return CGKeyCode(kVK_ANSI_A)
        case "b": return CGKeyCode(kVK_ANSI_B)
        case "c": return CGKeyCode(kVK_ANSI_C)
        case "d": return CGKeyCode(kVK_ANSI_D)
        case "e": return CGKeyCode(kVK_ANSI_E)
        case "f": return CGKeyCode(kVK_ANSI_F)
        case "g": return CGKeyCode(kVK_ANSI_G)
        case "h": return CGKeyCode(kVK_ANSI_H)
        case "i": return CGKeyCode(kVK_ANSI_I)
        case "j": return CGKeyCode(kVK_ANSI_J)
        case "k": return CGKeyCode(kVK_ANSI_K)
        case "l": return CGKeyCode(kVK_ANSI_L)
        case "m": return CGKeyCode(kVK_ANSI_M)
        case "n": return CGKeyCode(kVK_ANSI_N)
        case "o": return CGKeyCode(kVK_ANSI_O)
        case "p": return CGKeyCode(kVK_ANSI_P)
        case "q": return CGKeyCode(kVK_ANSI_Q)
        case "r": return CGKeyCode(kVK_ANSI_R)
        case "s": return CGKeyCode(kVK_ANSI_S)
        case "t": return CGKeyCode(kVK_ANSI_T)
        case "u": return CGKeyCode(kVK_ANSI_U)
        case "v": return CGKeyCode(kVK_ANSI_V)
        case "w": return CGKeyCode(kVK_ANSI_W)
        case "x": return CGKeyCode(kVK_ANSI_X)
        case "y": return CGKeyCode(kVK_ANSI_Y)
        case "z": return CGKeyCode(kVK_ANSI_Z)
        case "-": return CGKeyCode(kVK_ANSI_Minus)
        case "=": return CGKeyCode(kVK_ANSI_Equal)
        case "[": return CGKeyCode(kVK_ANSI_LeftBracket)
        case "]": return CGKeyCode(kVK_ANSI_RightBracket)
        case "\\": return CGKeyCode(kVK_ANSI_Backslash)
        case ";": return CGKeyCode(kVK_ANSI_Semicolon)
        case "'": return CGKeyCode(kVK_ANSI_Quote)
        case ",": return CGKeyCode(kVK_ANSI_Comma)
        case ".": return CGKeyCode(kVK_ANSI_Period)
        case "/": return CGKeyCode(kVK_ANSI_Slash)
        case "return", "enter":
            return CGKeyCode(kVK_Return)
        case "escape", "esc":
            return CGKeyCode(kVK_Escape)
        default:
            return nil
        }
    }

    static func displayString(for key: String) -> String {
        key == "return" ? "return" : key
    }

    static func symbolDisplayString(for key: String) -> String {
        switch key.lowercased() {
        case "return", "enter":
            return "↩"
        case "escape", "esc":
            return "⎋"
        case "space":
            return "␠"
        default:
            return key.uppercased()
        }
    }

    static func keyName(for keyCode: CGKeyCode) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "a"
        case kVK_ANSI_B: return "b"
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_D: return "d"
        case kVK_ANSI_E: return "e"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_G: return "g"
        case kVK_ANSI_H: return "h"
        case kVK_ANSI_I: return "i"
        case kVK_ANSI_J: return "j"
        case kVK_ANSI_K: return "k"
        case kVK_ANSI_L: return "l"
        case kVK_ANSI_M: return "m"
        case kVK_ANSI_N: return "n"
        case kVK_ANSI_O: return "o"
        case kVK_ANSI_P: return "p"
        case kVK_ANSI_Q: return "q"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_T: return "t"
        case kVK_ANSI_U: return "u"
        case kVK_ANSI_V: return "v"
        case kVK_ANSI_W: return "w"
        case kVK_ANSI_X: return "x"
        case kVK_ANSI_Y: return "y"
        case kVK_ANSI_Z: return "z"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_Return: return "return"
        case kVK_Escape: return "escape"
        default: return nil
        }
    }
}
