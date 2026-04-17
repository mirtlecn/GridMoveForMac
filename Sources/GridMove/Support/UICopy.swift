import Foundation

enum UICopy {
    static let appName = "GridMove"
    static let applicationMenuTitle = "Application"
    static let enableMenuTitle = "Enable"
    static let middleMouseDragMenuTitle = "Middle mouse drag"
    static let modifierLeftMouseDragMenuTitle = "Modifier + left mouse drag"
    static let preferLayoutModeMenuTitle = "Prefer layout mode"
    static let layoutGroupMenuTitle = "Layout group"
    static let reloadConfigMenuTitle = "Reload"
    static let customizeMenuTitle = "Customize... ↗"
    static let configReloadFailedTitle = "GridMove config reload failed"
    static let configReloadSkippedLayoutsTitle = "GridMove skipped invalid layout files"
    static let quitMenuTitle = "Quit"
    static let quitAppMenuTitle = "Quit GridMove"
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

    static func configReloadFailedBody(diagnostic: ConfigurationLoadDiagnostic?) -> String {
        let prefix = "Config was not applied. GridMove kept running with the current configuration."

        guard let diagnostic else {
            return prefix
        }

        if let line = diagnostic.line, let column = diagnostic.column {
            return "\(prefix) The error is at line \(line), column \(column): \(diagnostic.message)"
        }

        if let codingPath = diagnostic.codingPathDescription {
            return "\(prefix) The error is in \(codingPath): \(diagnostic.message)"
        }

        return "\(prefix) \(diagnostic.message)"
    }

    static func configReloadSkippedLayoutsBody(diagnostics: [LayoutFileDiagnostic]) -> String {
        let prefix = "Config was applied, but some layout files were skipped."
        guard !diagnostics.isEmpty else {
            return prefix
        }

        let details = diagnostics.map { diagnostic in
            let fileName = diagnostic.fileURL.lastPathComponent
            if let line = diagnostic.line, let column = diagnostic.column {
                return "\(fileName) (line \(line), column \(column)): \(diagnostic.message)"
            }
            if let codingPath = diagnostic.codingPathDescription {
                return "\(fileName) (\(codingPath)): \(diagnostic.message)"
            }
            return "\(fileName): \(diagnostic.message)"
        }
        .joined(separator: " ")

        return "\(prefix) \(details)"
    }
}
