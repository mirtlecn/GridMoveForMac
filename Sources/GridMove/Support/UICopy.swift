import Foundation

enum UICopy {
    static let appName = "GridMove"
    static let applicationMenuTitle = "Application"
    static let enableMenuTitle = "Enable"
    static let settingsMenuTitle = "Settings…"
    static let quitMenuTitle = "Quit"
    static let quitAppMenuTitle = "Quit GridMove"

    static let settingsWindowTitle = "GridMove Settings"
    static let onboardingWindowTitle = "GridMove Setup"
    static let onboardingTitle = "Accessibility access is required"
    static let onboardingBody = "GridMove needs Accessibility permission to find windows under the pointer, focus them, and apply layouts. Open System Settings and allow GridMove in Privacy & Security > Accessibility."
    static let requestAccessibilityAccess = "Request accessibility access"
    static let openAccessibilitySettings = "Open accessibility settings"

    static let generalSectionTitle = "General"
    static let layoutsSectionTitle = "Layouts"
    static let appearanceSectionTitle = "Appearance"
    static let hotkeysSectionTitle = "Hotkeys"
    static let aboutSectionTitle = "About"

    static let enableTitle = "Enable"
    static let enableSubtitle = "Allow drag triggers, layout hotkeys, and command line layout actions."
    static let pressAndDragSectionTitle = "Press and drag"
    static let middleMouseTitle = "Middle mouse"
    static let middleMouseSubtitle = "Press middle mouse for a short time to activate the grid."
    static let modifierLeftMouseTitle = "Modifier + left mouse"
    static let modifierLeftMouseSubtitle = "Hold pre-set modifier, then press left mouse to activate."
    static let excludedWindowsSectionTitle = "Excluded windows"
    static let valueColumnTitle = "Value"
    static let typeColumnTitle = "Type"
    static let bundleIDTitle = "Bundle ID"
    static let windowTitle = "Window title"

    static let hotkeysHelpText = "To change a shortcut, double-click the key combination, then type a new shortcut."
    static let applyNextLayout = "Apply next layout"
    static let applyPreviousLayout = "Apply previous layout"
    static let unknownLayout = "Unknown layout"

    static let windowOverlayTitle = "Window overlay"
    static let triggerOverlayTitle = "Trigger overlay"
    static let resetToDefaults = "Reset to defaults"
    static let renderWindowArea = "Render window area"
    static let renderWindowAreaSubtitle = "Show the current or target window preview while dragging."
    static let fillOpacity = "Fill opacity"
    static let strokeWidth = "Stroke width"
    static let strokeColor = "Stroke color"
    static let renderTriggerArea = "Render trigger area"
    static let renderTriggerAreaSubtitle = "Show trigger regions while dragging across the screen or menu bar."
    static let strokeOpacity = "Stroke opacity"
    static let gridGap = "Grid gap"

    static let addLayout = "Add layout"
    static let confirmDelete = "Confirm delete"
    static let delete = "Delete"
    static let save = "Save"
    static let includeInCycle = "Include in cycle"
    static let name = "Name"
    static let optionalName = "Optional name"
    static let grid = "Grid"

    static let cancel = "Cancel"
    static let add = "Add"
    static let isLabel = "Is"
    static let version = "Version"
    static let typeShortcut = "Type shortcut"
    static let notSet = "Not set"

    static let excludedBundleIDAdded = "Excluded bundle ID added."
    static let excludedWindowTitleAdded = "Excluded window title added."
    static let excludedBundleIDRemoved = "Excluded bundle ID removed."
    static let excludedWindowTitleRemoved = "Excluded window title removed."
    static let dragTriggersUpdated = "Drag triggers updated."
    static let globalEnableUpdated = "Global enable updated."
    static let modifierGroupAdded = "Modifier group added."
    static let modifierGroupRemoved = "Modifier group removed."
    static let layoutAdded = "Layout added."
    static let atLeastOneLayoutRequired = "At least one layout is required."
    static let layoutRemoved = "Layout removed."
    static let layoutOrderUpdated = "Layout order updated."
    static let layoutSaved = "Layout saved."
    static let appearanceUpdated = "Appearance updated."
    static let triggerAppearanceReset = "Trigger appearance reset."
    static let windowAppearanceReset = "Window appearance reset."
    static let hotkeysUpdated = "Hotkeys updated."
    static let hotkeyRemoved = "Hotkey removed."
    static let hotkeyAdded = "Hotkey added."
    static let directActionHotkeyAdded = "Direct action hotkey added."
    static let previousLayoutHotkeyAdded = "Previous layout hotkey added."
    static let nextLayoutHotkeyAdded = "Next layout hotkey added."

    static let defaultLayoutNames = [
        "Left 1/3",
        "Left 1/2",
        "Left 2/3",
        "Center",
        "Right 2/3",
        "Right 1/2",
        "Right 1/3",
        "Right 1/3 top",
        "Right 1/3 bottom",
        "Fill all screen",
        "Fill all screen (Menu bar)",
    ]

    static func applyLayout(_ name: String) -> String {
        "Apply \(name)"
    }

    static func layoutMenuName(name: String, fallbackIdentifier: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? fallbackIdentifier : trimmedName
    }
}
