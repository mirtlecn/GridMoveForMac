import Foundation

enum UICopy {
    static let appName = "GridMove"
    static let applicationMenuTitle = "Application"
    static let settingsMenuTitle = "Settings..."
    static let settingsWindowTitle = "Settings"
    static let settingsGeneralTabTitle = "General"
    static let settingsLayoutsTabTitle = "Layouts"
    static let settingsAppearanceTabTitle = "Appearance"
    static let settingsHotkeysTabTitle = "Hotkeys"
    static let settingsAboutTabTitle = "About"
    static let settingsLayoutInlineTabTitle = "Layout"
    static let settingsWindowAreaInlineTabTitle = "Window area"
    static let settingsTriggerAreaInlineTabTitle = "Trigger area"
    static let settingsDragBehaviorSectionTitle = "Drag behavior"
    static let settingsExclusionsSectionTitle = "Exclusions"
    static let settingsWindowAreaSectionTitle = "Window area"
    static let settingsTriggerAreaSectionTitle = "Trigger area"
    static let settingsModifierGroupsLabel = "Modifier groups"
    static let settingsMouseButtonNumberLabel = "Mouse button number"
    static let settingsExcludedBundleIDsLabel = "Excluded bundle IDs"
    static let settingsExcludedWindowTitlesLabel = "Excluded window titles"
    static let settingsHighlightWindowAreaTitle = "Highlight window area"
    static let settingsHighlightTriggerAreaTitle = "Highlight trigger area"
    static let settingsFillOpacityLabel = "Fill opacity"
    static let settingsStrokeWidthLabel = "Stroke width"
    static let settingsStrokeColorLabel = "Stroke color"
    static let settingsWindowGapLabel = "Window gap"
    static let settingsTriggerGapLabel = "Trigger gap"
    static let settingsNameLabel = "Name"
    static let settingsGridSizeLabel = "Grid size"
    static let settingsGridColumnsLabel = "Grid columns"
    static let settingsGridRowsLabel = "Grid rows"
    static let settingsTriggerAreaLabel = "Trigger area"
    static let settingsApplyToLabel = "Apply to"
    static let settingsIncludeInMenuLabel = "Include in menu"
    static let settingsIncludeInLayoutIndexLabel = "Include in layout index"
    static let settingsIncludeInGroupCycleLabel = "Include in group cycle"
    static let settingsIncludeInGroupCycleDescription = "Enabled groups can be cycled in layout mode with the mouse wheel or the Shift key."
    static let settingsActiveGroupLabel = "Active group"
    static let settingsMonitorLabel = "Monitor"
    static let settingsLayoutsCountLabel = "Layouts"
    static let settingsLayoutIndexLabel = "Layout index"
    static let settingsWindowLayoutTabTitle = "Window layout"
    static let settingsTriggerRegionsTabTitle = "Trigger regions"
    static let settingsAllDisplaysValue = "All displays"
    static let settingsMainDisplayValue = "Main display"
    static let settingsNoTriggerRegionValue = "No trigger region"
    static let settingsNotIncludedValue = "Not included"
    static let settingsScreenGridValue = "Screen"
    static let settingsMenuBarTriggerValue = "Menu bar"
    static let settingsNoneValue = "None"
    static let settingsAllMonitorsValue = "All monitor"
    static let settingsMainMonitorValue = "Main monitor"
    static let settingsCustomMonitorsValue = "Custom monitors"
    static let settingsStartLabel = "Start"
    static let settingsXPositionLabel = "X position"
    static let settingsYPositionLabel = "Y position"
    static let settingsWidthLabel = "Width"
    static let settingsHeightLabel = "Height"
    static let settingsAddButtonTitle = "Add"
    static let settingsAddEllipsisButtonTitle = "Add..."
    static let settingsAddGroupButtonTitle = "Add group"
    static let settingsAddDisplaySetButtonTitle = "Add monitor set"
    static let settingsAddLayoutButtonTitle = "Add layout"
    static let settingsHotkeysAddButtonTitle = "Add..."
    static let settingsClearButtonTitle = "Clear"
    static let settingsRemoveButtonTitle = "Remove"
    static let settingsDeleteButtonTitle = "Delete"
    static let settingsSaveButtonTitle = "Save"
    static let settingsCancelButtonTitle = "Cancel"
    static let settingsSlotLabel = "Slot"
    static let settingsCurrentTargetLabel = "Current target"
    static let settingsBindingsLabel = "Bindings"
    static let settingsNoShortcutsValue = "No shortcuts"
    static let settingsHotkeysPreviousTargetValue = "Previous item in current cycle"
    static let settingsHotkeysNextTargetValue = "Next item in current cycle"
    static let settingsVersionLabel = "Version"
    static let settingsAuthorLabel = "Author"
    static let settingsConfigFolderLabel = "Config folder"
    static let settingsOpenButtonTitle = "Open"
    static let settingsAdvancedSectionTitle = "Advanced"
    static let settingsRestoreSettingsButtonTitle = "Restore settings"
    static let settingsProtectedGroupTooltip = "Can not remove a protected group"
    static let settingsTypeLabel = "Type"
    static let settingsValueLabel = "Value"
    static let settingsAddModifierGroupSheetTitle = "Add modifier group"
    static let settingsAddModifierGroupSheetMessage = "Choose one or more modifier keys for this trigger group."
    static let settingsAddExclusionSheetTitle = "Add exclusion"
    static let settingsAddExclusionSheetMessage = "Choose what to exclude, then enter the value."
    static let settingsHotkeySheetTitle = "Hotkey"
    static let settingsHotkeySheetMessage = "Add or remove a hotkey"
    static let settingsBehaviorLabel = "Behavior"
    static let settingsShortcutsLabel = "Shortcuts"
    static let settingsRecordShortcutButtonTitle = "Record"
    static let settingsPressShortcutValue = "Press shortcut"
    static let settingsStatusLabel = "Status"
    static let settingsStatusValue = "Prototype only"
    static let settingsSurfaceLabel = "Current surface"
    static let settingsSurfaceValue = "Menu bar app with Settings preview"
    static let settingsPrototypePlaceholderTitle = "No controls in this prototype yet."
    static let enableMenuTitle = "Enable"
    static let enableMenuDescription = "Global switch for mouse, hotkey, and CLI actions."
    static let requestAccessibilityAccessMenuTitle = "Get accessibility access"
    static let modifierLeftMouseDragMenuTitle = "Modifier + left mouse drag"
    static let preferLayoutModeMenuTitle = "Prefer layout mode"
    static let preferLayoutModeEnabledDescription = "Start in layout mode by default. Right-click or press Option to switch to free move."
    static let preferLayoutModeDisabledDescription = "Start in free move by default. Right-click or press Option to switch to layout mode."
    static let layoutGroupMenuTitle = "Layout group"
    static let reloadConfigMenuTitle = "Reload"
    static let launchAtLoginMenuTitle = "Launch at login"
    static let configReloadSucceededTitle = "GridMove config reloaded"
    static let configReloadFailedTitle = "GridMove config reload failed"
    static let configReloadSkippedLayoutsTitle = "GridMove skipped invalid layout files"
    static let layoutsSaveFailedTitle = "GridMove could not save layouts"
    static let launchAtLoginEnableFailedTitle = "Unable to enable launch at login"
    static let launchAtLoginDisableFailedTitle = "Unable to disable launch at login"
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

    static func settingsApplyLayoutSlotTitle(_ index: Int) -> String {
        "Apply layout \(index)"
    }

    static func settingsUntitledLayoutTitle(_ index: Int) -> String {
        "Layout №\(index)"
    }

    static func mouseButtonDragMenuTitle(mouseButtonNumber: Int) -> String {
        mouseButtonNumber == 3 ? "Middle mouse drag" : "Mouse button \(mouseButtonNumber) drag"
    }

    static func layoutMenuName(name: String, fallbackIdentifier: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? fallbackIdentifier : trimmedName
    }

    static func configReloadFailedBody(
        diagnostic: ConfigurationLoadDiagnostic?,
        skippedLayoutDiagnostics: [LayoutFileDiagnostic] = []
    ) -> String {
        let prefix = "Config was not applied. GridMove kept running with the current configuration."
        let skippedDetails = skippedLayoutDiagnosticsText(diagnostics: skippedLayoutDiagnostics)

        guard let diagnostic else {
            guard let skippedDetails else {
                return prefix
            }
            return "\(prefix) Skipped layout files: \(skippedDetails)"
        }

        if let line = diagnostic.line, let column = diagnostic.column {
            let body = "\(prefix) The error is at line \(line), column \(column): \(diagnostic.message)"
            guard let skippedDetails else {
                return body
            }
            return "\(body) Skipped layout files: \(skippedDetails)"
        }

        if let codingPath = diagnostic.codingPathDescription {
            let body = "\(prefix) The error is in \(codingPath): \(diagnostic.message)"
            guard let skippedDetails else {
                return body
            }
            return "\(body) Skipped layout files: \(skippedDetails)"
        }

        let body = "\(prefix) \(diagnostic.message)"
        guard let skippedDetails else {
            return body
        }
        return "\(body) Skipped layout files: \(skippedDetails)"
    }

    static func configReloadSkippedLayoutsBody(diagnostics: [LayoutFileDiagnostic]) -> String {
        let prefix = "Config was applied, but some layout files were skipped."
        guard !diagnostics.isEmpty else {
            return prefix
        }

        let details = skippedLayoutDiagnosticsText(diagnostics: diagnostics) ?? ""

        return "\(prefix) \(details)"
    }

    private static func skippedLayoutDiagnosticsText(diagnostics: [LayoutFileDiagnostic]) -> String? {
        guard !diagnostics.isEmpty else {
            return nil
        }

        return diagnostics.map { diagnostic in
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
    }

    static func configReloadSucceededBody() -> String {
        "Config was applied successfully."
    }

    static func layoutsSaveFailedBody(details: String?) -> String {
        var segments = [
            "Layout changes were not applied.",
            "GridMove kept running with the current configuration.",
        ]

        if let details, !details.isEmpty {
            segments.append(details)
        }

        return segments.joined(separator: " ")
    }

    static func launchAtLoginEnableFailedBody(details: String?) -> String {
        launchAtLoginFailureBody(
            prefix: "GridMove could not enable launch at login.",
            details: details
        )
    }

    static func launchAtLoginDisableFailedBody(details: String?) -> String {
        launchAtLoginFailureBody(
            prefix: "GridMove could not disable launch at login.",
            details: details
        )
    }

    private static func launchAtLoginFailureBody(prefix: String, details: String?) -> String {
        var segments = [
            prefix,
            "Check System Settings > General > Login Items and try again.",
        ]

        if let details, !details.isEmpty {
            segments.append(details)
        }

        return segments.joined(separator: " ")
    }
}
