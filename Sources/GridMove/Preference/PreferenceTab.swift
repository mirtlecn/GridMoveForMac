import AppKit

enum PreferenceTab: CaseIterable {
    case general
    case layouts
    case appearance
    case hotkeys
    case about

    var title: String {
        switch self {
        case .general:
            return UICopy.generalSectionTitle
        case .layouts:
            return UICopy.layoutsSectionTitle
        case .appearance:
            return UICopy.appearanceSectionTitle
        case .hotkeys:
            return UICopy.hotkeysSectionTitle
        case .about:
            return UICopy.aboutSectionTitle
        }
    }

    var symbolName: String {
        switch self {
        case .general:
            return "gearshape"
        case .layouts:
            return "square.grid.3x2"
        case .appearance:
            return "paintpalette"
        case .hotkeys:
            return "keyboard"
        case .about:
            return "info.circle"
        }
    }
}
