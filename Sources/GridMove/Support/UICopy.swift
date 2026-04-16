import Foundation

enum UICopy {
    static let appName = "GridMove"
    static let applicationMenuTitle = "Application"
    static let enableMenuTitle = "Enable"
    static let reloadConfigMenuTitle = "Reload config"
    static let customizeMenuTitle = "Customize"
    static let customizeAppMenuTitle = "Customize…"
    static let quitMenuTitle = "Quit"
    static let quitAppMenuTitle = "Quit GridMove"
    static let onboardingWindowTitle = "GridMove Setup"
    static let onboardingTitle = "Accessibility access is required"
    static let onboardingBody = "GridMove needs Accessibility permission to find windows under the pointer, focus them, and apply layouts. Open System Settings and allow GridMove in Privacy & Security > Accessibility."
    static let requestAccessibilityAccess = "Request accessibility access"
    static let openAccessibilitySettings = "Open accessibility settings"
    static let applyNextLayout = "Apply next layout"
    static let applyPreviousLayout = "Apply previous layout"
    static let unknownLayout = "Unknown layout"

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
