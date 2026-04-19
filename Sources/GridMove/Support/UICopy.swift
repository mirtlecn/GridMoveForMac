import Foundation

enum UICopy {
    static let appName = "GridMove"

    static var applicationMenuTitle: String { localized("applicationMenuTitle", default: "Application") }
    static var settingsMenuTitle: String { localized("settingsMenuTitle", default: "Settings...") }
    static var settingsWindowTitle: String { localized("settingsWindowTitle", default: "Settings") }
    static var settingsGeneralTabTitle: String { localized("settingsGeneralTabTitle", default: "General") }
    static var settingsLayoutsTabTitle: String { localized("settingsLayoutsTabTitle", default: "Layouts") }
    static var settingsAppearanceTabTitle: String { localized("settingsAppearanceTabTitle", default: "Appearance") }
    static var settingsHotkeysTabTitle: String { localized("settingsHotkeysTabTitle", default: "Hotkeys") }
    static var settingsAboutTabTitle: String { localized("settingsAboutTabTitle", default: "About") }
    static var settingsLayoutInlineTabTitle: String { localized("settingsLayoutInlineTabTitle", default: "Layout") }
    static var settingsWindowAreaInlineTabTitle: String { localized("settingsWindowAreaInlineTabTitle", default: "Window area") }
    static var settingsTriggerAreaInlineTabTitle: String { localized("settingsTriggerAreaInlineTabTitle", default: "Trigger area") }
    static var settingsDragBehaviorSectionTitle: String { localized("settingsDragBehaviorSectionTitle", default: "Drag behavior") }
    static var settingsExclusionsSectionTitle: String { localized("settingsExclusionsSectionTitle", default: "Exclusions") }
    static var settingsWindowAreaSectionTitle: String { localized("settingsWindowAreaSectionTitle", default: "Window area") }
    static var settingsTriggerAreaSectionTitle: String { localized("settingsTriggerAreaSectionTitle", default: "Trigger area") }
    static var settingsModifierGroupsLabel: String { localized("settingsModifierGroupsLabel", default: "Modifier groups") }
    static var settingsMouseButtonNumberLabel: String { localized("settingsMouseButtonNumberLabel", default: "Mouse button number") }
    static var settingsExcludedBundleIDsLabel: String { localized("settingsExcludedBundleIDsLabel", default: "Excluded bundle IDs") }
    static var settingsExcludedWindowTitlesLabel: String { localized("settingsExcludedWindowTitlesLabel", default: "Excluded window titles") }
    static var settingsHighlightWindowAreaTitle: String { localized("settingsHighlightWindowAreaTitle", default: "Highlight window area") }
    static var settingsHighlightTriggerAreaTitle: String { localized("settingsHighlightTriggerAreaTitle", default: "Highlight trigger area") }
    static var settingsFillOpacityLabel: String { localized("settingsFillOpacityLabel", default: "Fill opacity") }
    static var settingsStrokeWidthLabel: String { localized("settingsStrokeWidthLabel", default: "Stroke width") }
    static var settingsStrokeColorLabel: String { localized("settingsStrokeColorLabel", default: "Stroke color") }
    static var settingsWindowGapLabel: String { localized("settingsWindowGapLabel", default: "Window gap") }
    static var settingsTriggerGapLabel: String { localized("settingsTriggerGapLabel", default: "Trigger gap") }
    static var settingsNameLabel: String { localized("settingsNameLabel", default: "Name") }
    static var settingsGridSizeLabel: String { localized("settingsGridSizeLabel", default: "Grid size") }
    static var settingsGridColumnsLabel: String { localized("settingsGridColumnsLabel", default: "Grid columns") }
    static var settingsGridRowsLabel: String { localized("settingsGridRowsLabel", default: "Grid rows") }
    static var settingsTriggerAreaLabel: String { localized("settingsTriggerAreaLabel", default: "Trigger area") }
    static var settingsApplyToLabel: String { localized("settingsApplyToLabel", default: "Apply to") }
    static var settingsIncludeInMenuLabel: String { localized("settingsIncludeInMenuLabel", default: "Include in menu") }
    static var settingsIncludeInLayoutIndexLabel: String { localized("settingsIncludeInLayoutIndexLabel", default: "Include in layout index") }
    static var settingsIncludeInGroupCycleLabel: String { localized("settingsIncludeInGroupCycleLabel", default: "Include in group cycle") }
    static var settingsIncludeInGroupCycleDescription: String {
        localized(
            "settingsIncludeInGroupCycleDescription",
            default: "Enabled groups can be cycled in layout mode with the mouse wheel or the Shift key."
        )
    }
    static var settingsActiveGroupLabel: String { localized("settingsActiveGroupLabel", default: "Active group") }
    static var settingsMonitorLabel: String { localized("settingsMonitorLabel", default: "Monitor") }
    static var settingsLayoutsCountLabel: String { localized("settingsLayoutsCountLabel", default: "Layouts") }
    static var settingsLayoutIndexLabel: String { localized("settingsLayoutIndexLabel", default: "Layout index") }
    static var settingsWindowLayoutTabTitle: String { localized("settingsWindowLayoutTabTitle", default: "Window layout") }
    static var settingsTriggerRegionsTabTitle: String { localized("settingsTriggerRegionsTabTitle", default: "Trigger regions") }
    static var settingsAllDisplaysValue: String { localized("settingsAllDisplaysValue", default: "All displays") }
    static var settingsMainDisplayValue: String { localized("settingsMainDisplayValue", default: "Main display") }
    static var settingsNoTriggerRegionValue: String { localized("settingsNoTriggerRegionValue", default: "No trigger region") }
    static var settingsNotIncludedValue: String { localized("settingsNotIncludedValue", default: "Not included") }
    static var settingsScreenGridValue: String { localized("settingsScreenGridValue", default: "Screen") }
    static var settingsMenuBarTriggerValue: String { localized("settingsMenuBarTriggerValue", default: "Menu bar") }
    static var settingsNoneValue: String { localized("settingsNoneValue", default: "None") }
    static var settingsAllValue: String { localized("settingsAllValue", default: "All") }
    static var settingsCurrentValue: String { localized("settingsCurrentValue", default: "Current") }
    static var settingsAllMonitorsValue: String { localized("settingsAllMonitorsValue", default: "All monitor") }
    static var settingsMainMonitorValue: String { localized("settingsMainMonitorValue", default: "Main monitor") }
    static var settingsCustomMonitorsValue: String { localized("settingsCustomMonitorsValue", default: "Custom monitors") }
    static var settingsStartLabel: String { localized("settingsStartLabel", default: "Start") }
    static var settingsXPositionLabel: String { localized("settingsXPositionLabel", default: "X position") }
    static var settingsYPositionLabel: String { localized("settingsYPositionLabel", default: "Y position") }
    static var settingsWidthLabel: String { localized("settingsWidthLabel", default: "Width") }
    static var settingsHeightLabel: String { localized("settingsHeightLabel", default: "Height") }
    static var settingsAddButtonTitle: String { localized("settingsAddButtonTitle", default: "Add") }
    static var settingsAddEllipsisButtonTitle: String { localized("settingsAddEllipsisButtonTitle", default: "Add...") }
    static var settingsAddGroupButtonTitle: String { localized("settingsAddGroupButtonTitle", default: "Add group") }
    static var settingsAddDisplaySetButtonTitle: String { localized("settingsAddDisplaySetButtonTitle", default: "Add monitor set") }
    static var settingsAddLayoutButtonTitle: String { localized("settingsAddLayoutButtonTitle", default: "Add layout") }
    static var settingsHotkeysAddButtonTitle: String { localized("settingsHotkeysAddButtonTitle", default: "Add...") }
    static var settingsClearButtonTitle: String { localized("settingsClearButtonTitle", default: "Clear") }
    static var settingsRemoveButtonTitle: String { localized("settingsRemoveButtonTitle", default: "Remove") }
    static var settingsDeleteButtonTitle: String { localized("settingsDeleteButtonTitle", default: "Delete") }
    static var settingsSaveButtonTitle: String { localized("settingsSaveButtonTitle", default: "Save") }
    static var settingsCancelButtonTitle: String { localized("settingsCancelButtonTitle", default: "Cancel") }
    static var settingsSlotLabel: String { localized("settingsSlotLabel", default: "Slot") }
    static var settingsCurrentTargetLabel: String { localized("settingsCurrentTargetLabel", default: "Current target") }
    static var settingsBindingsLabel: String { localized("settingsBindingsLabel", default: "Bindings") }
    static var settingsNoShortcutsValue: String { localized("settingsNoShortcutsValue", default: "No shortcuts") }
    static var settingsHotkeysPreviousTargetValue: String {
        localized("settingsHotkeysPreviousTargetValue", default: "Previous item in current cycle")
    }
    static var settingsHotkeysNextTargetValue: String {
        localized("settingsHotkeysNextTargetValue", default: "Next item in current cycle")
    }
    static var settingsVersionLabel: String { localized("settingsVersionLabel", default: "Version") }
    static var settingsAuthorLabel: String { localized("settingsAuthorLabel", default: "Author") }
    static var settingsLinkLabel: String { localized("settingsLinkLabel", default: "Link") }
    static var settingsConfigFolderLabel: String { localized("settingsConfigFolderLabel", default: "Config folder") }
    static var settingsOpenButtonTitle: String { localized("settingsOpenButtonTitle", default: "Open") }
    static var settingsAdvancedSectionTitle: String { localized("settingsAdvancedSectionTitle", default: "Advanced") }
    static var settingsRestoreSettingsButtonTitle: String { localized("settingsRestoreSettingsButtonTitle", default: "Restore settings") }
    static var settingsRemoveDraftConfirmationMessage: String {
        localized(
            "settingsRemoveDraftConfirmationMessage",
            default: "This change stays in draft mode until you click Save."
        )
    }
    static var settingsRestoreSettingsConfirmationMessage: String {
        localized(
            "settingsRestoreSettingsConfirmationMessage",
            default: "This restores all settings to the built-in defaults."
        )
    }
    static var settingsProtectedGroupTooltip: String {
        localized("settingsProtectedGroupTooltip", default: "Can not remove a protected group")
    }
    static var settingsTypeLabel: String { localized("settingsTypeLabel", default: "Type") }
    static var settingsValueLabel: String { localized("settingsValueLabel", default: "Value") }
    static var settingsAddModifierGroupSheetTitle: String {
        localized("settingsAddModifierGroupSheetTitle", default: "Add modifier group")
    }
    static var settingsAddModifierGroupSheetMessage: String {
        localized("settingsAddModifierGroupSheetMessage", default: "Choose one or more modifier keys for this trigger group.")
    }
    static var settingsAddExclusionSheetTitle: String {
        localized("settingsAddExclusionSheetTitle", default: "Add exclusion")
    }
    static var settingsAddExclusionSheetMessage: String {
        localized("settingsAddExclusionSheetMessage", default: "Choose what to exclude, then enter the value.")
    }
    static var settingsHotkeySheetTitle: String { localized("settingsHotkeySheetTitle", default: "Hotkey") }
    static var settingsHotkeySheetMessage: String { localized("settingsHotkeySheetMessage", default: "Add or remove a hotkey") }
    static var settingsBehaviorLabel: String { localized("settingsBehaviorLabel", default: "Behavior") }
    static var settingsShortcutsLabel: String { localized("settingsShortcutsLabel", default: "Shortcuts") }
    static var settingsRecordShortcutButtonTitle: String { localized("settingsRecordShortcutButtonTitle", default: "Record") }
    static var settingsPressShortcutValue: String { localized("settingsPressShortcutValue", default: "Press shortcut") }
    static var settingsStatusLabel: String { localized("settingsStatusLabel", default: "Status") }
    static var settingsStatusValue: String { localized("settingsStatusValue", default: "Prototype only") }
    static var settingsSurfaceLabel: String { localized("settingsSurfaceLabel", default: "Current surface") }
    static var settingsSurfaceValue: String { localized("settingsSurfaceValue", default: "Menu bar app with Settings preview") }
    static var settingsPrototypePlaceholderTitle: String {
        localized("settingsPrototypePlaceholderTitle", default: "No controls in this prototype yet.")
    }
    static var enableMenuTitle: String { localized("enableMenuTitle", default: "Enable") }
    static var enableMenuDescription: String {
        localized("enableMenuDescription", default: "Global switch for mouse, hotkey, and CLI actions.")
    }
    static var requestAccessibilityAccessMenuTitle: String {
        localized("requestAccessibilityAccessMenuTitle", default: "Get accessibility access")
    }
    static var modifierLeftMouseDragMenuTitle: String {
        localized("modifierLeftMouseDragMenuTitle", default: "Modifier + left mouse drag")
    }
    static var preferLayoutModeMenuTitle: String { localized("preferLayoutModeMenuTitle", default: "Prefer layout mode") }
    static var preferLayoutModeEnabledDescription: String {
        localized(
            "preferLayoutModeEnabledDescription",
            default: "Start in layout mode by default. Right-click or press Option to switch to free move."
        )
    }
    static var preferLayoutModeDisabledDescription: String {
        localized(
            "preferLayoutModeDisabledDescription",
            default: "Start in free move by default. Right-click or press Option to switch to layout mode."
        )
    }
    static var layoutGroupMenuTitle: String { localized("layoutGroupMenuTitle", default: "Layout group") }
    static var reloadConfigMenuTitle: String { localized("reloadConfigMenuTitle", default: "Reload") }
    static var launchAtLoginMenuTitle: String { localized("launchAtLoginMenuTitle", default: "Launch at login") }
    static var configReloadSucceededTitle: String {
        localized("configReloadSucceededTitle", default: "GridMove config reloaded")
    }
    static var configReloadFailedTitle: String {
        localized("configReloadFailedTitle", default: "GridMove config reload failed")
    }
    static var configReloadSkippedLayoutsTitle: String {
        localized("configReloadSkippedLayoutsTitle", default: "GridMove skipped invalid layout files")
    }
    static var layoutsSaveFailedTitle: String {
        localized("layoutsSaveFailedTitle", default: "GridMove could not save layouts")
    }
    static var launchAtLoginEnableFailedTitle: String {
        localized("launchAtLoginEnableFailedTitle", default: "Unable to enable launch at login")
    }
    static var launchAtLoginDisableFailedTitle: String {
        localized("launchAtLoginDisableFailedTitle", default: "Unable to disable launch at login")
    }
    static var quitMenuTitle: String { localized("quitMenuTitle", default: "Quit") }
    static var quitAppMenuTitle: String { localized("quitAppMenuTitle", default: "Quit GridMove") }
    static var applyNextLayout: String { localized("applyNextLayout", default: "Apply next layout") }
    static var applyPreviousLayout: String { localized("applyPreviousLayout", default: "Apply previous layout") }
    static var unknownLayout: String { localized("unknownLayout", default: "Unknown layout") }

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
        formatted("applyLayoutFormat", default: "Apply %@", name)
    }

    static func settingsApplyLayoutSlotTitle(_ index: Int) -> String {
        formatted("settingsApplyLayoutSlotTitleFormat", default: "Apply layout %@", String(index))
    }

    static func settingsUntitledLayoutTitle(_ index: Int) -> String {
        formatted("settingsUntitledLayoutTitleFormat", default: "Layout №%@", String(index))
    }

    static func mouseButtonDragMenuTitle(mouseButtonNumber: Int) -> String {
        if mouseButtonNumber == 3 {
            return localized("mouseButtonDragMiddleTitle", default: "Middle mouse drag")
        }
        return formatted("mouseButtonDragButtonTitleFormat", default: "Mouse button %@ drag", String(mouseButtonNumber))
    }

    static func layoutMenuName(name: String, fallbackIdentifier: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? fallbackIdentifier : trimmedName
    }

    static func configReloadFailedBody(
        diagnostic: ConfigurationLoadDiagnostic?,
        skippedLayoutDiagnostics: [LayoutFileDiagnostic] = []
    ) -> String {
        let prefix = localized(
            "configReloadFailedPrefix",
            default: "Config was not applied. GridMove kept running with the current configuration."
        )
        let skippedDetails = skippedLayoutDiagnosticsText(diagnostics: skippedLayoutDiagnostics)

        guard let diagnostic else {
            guard let skippedDetails else {
                return prefix
            }
            return formatted("configReloadFailedSkippedFormat", default: "%@ Skipped layout files: %@", prefix, skippedDetails)
        }

        if let line = diagnostic.line, let column = diagnostic.column {
            let body = formatted(
                "configReloadFailedLineColumnFormat",
                default: "%@ The error is at line %@, column %@: %@",
                prefix,
                String(line),
                String(column),
                diagnostic.message
            )
            guard let skippedDetails else {
                return body
            }
            return formatted("configReloadFailedSkippedFormat", default: "%@ Skipped layout files: %@", body, skippedDetails)
        }

        if let codingPath = diagnostic.codingPathDescription {
            let body = formatted(
                "configReloadFailedCodingPathFormat",
                default: "%@ The error is in %@: %@",
                prefix,
                codingPath,
                diagnostic.message
            )
            guard let skippedDetails else {
                return body
            }
            return formatted("configReloadFailedSkippedFormat", default: "%@ Skipped layout files: %@", body, skippedDetails)
        }

        let body = formatted(
            "configReloadFailedMessageFormat",
            default: "%@ %@",
            prefix,
            diagnostic.message
        )
        guard let skippedDetails else {
            return body
        }
        return formatted("configReloadFailedSkippedFormat", default: "%@ Skipped layout files: %@", body, skippedDetails)
    }

    static func configReloadSkippedLayoutsBody(diagnostics: [LayoutFileDiagnostic]) -> String {
        let prefix = localized(
            "configReloadSkippedLayoutsPrefix",
            default: "Config was applied, but some layout files were skipped."
        )
        guard !diagnostics.isEmpty else {
            return prefix
        }

        let details = skippedLayoutDiagnosticsText(diagnostics: diagnostics) ?? ""
        return formatted("configReloadSkippedLayoutsFormat", default: "%@ %@", prefix, details)
    }

    private static func skippedLayoutDiagnosticsText(diagnostics: [LayoutFileDiagnostic]) -> String? {
        guard !diagnostics.isEmpty else {
            return nil
        }

        return diagnostics.map { diagnostic in
            let fileName = diagnostic.fileURL.lastPathComponent
            if let line = diagnostic.line, let column = diagnostic.column {
                return formatted(
                    "skippedLayoutDiagnosticsLineColumnFormat",
                    default: "%@ (line %@, column %@): %@",
                    fileName,
                    String(line),
                    String(column),
                    diagnostic.message
                )
            }
            if let codingPath = diagnostic.codingPathDescription {
                return formatted(
                    "skippedLayoutDiagnosticsCodingPathFormat",
                    default: "%@ (%@): %@",
                    fileName,
                    codingPath,
                    diagnostic.message
                )
            }
            return formatted(
                "skippedLayoutDiagnosticsMessageFormat",
                default: "%@: %@",
                fileName,
                diagnostic.message
            )
        }
        .joined(separator: " ")
    }

    static func configReloadSucceededBody() -> String {
        localized("configReloadSucceededBody", default: "Config was applied successfully.")
    }

    static func layoutsSaveFailedBody(details: String?) -> String {
        var segments = [
            localized("layoutsSaveFailedBodyLineOne", default: "Layout changes were not applied."),
            localized("layoutsSaveFailedBodyLineTwo", default: "GridMove kept running with the current configuration."),
        ]

        if let details, !details.isEmpty {
            segments.append(details)
        }

        return segments.joined(separator: " ")
    }

    static func launchAtLoginEnableFailedBody(details: String?) -> String {
        launchAtLoginFailureBody(
            prefix: localized(
                "launchAtLoginEnableFailedPrefix",
                default: "GridMove could not enable launch at login."
            ),
            details: details
        )
    }

    static func launchAtLoginDisableFailedBody(details: String?) -> String {
        launchAtLoginFailureBody(
            prefix: localized(
                "launchAtLoginDisableFailedPrefix",
                default: "GridMove could not disable launch at login."
            ),
            details: details
        )
    }

    private static func launchAtLoginFailureBody(prefix: String, details: String?) -> String {
        var segments = [
            prefix,
            localized(
                "launchAtLoginFailureCheckSettings",
                default: "Check System Settings > General > Login Items and try again."
            ),
        ]

        if let details, !details.isEmpty {
            segments.append(details)
        }

        return segments.joined(separator: " ")
    }

    static func localizedStringForTesting(key: String, defaultValue: String, preferredLanguages: [String]) -> String {
        localized(key, default: defaultValue, preferredLanguages: preferredLanguages)
    }

    static var supportedLocalizationsForTesting: [String] {
        Array(Set(Bundle.main.localizations + Bundle.module.localizations)).sorted()
    }

    private static let tableName = "Localizable"

    private static func localized(_ key: String, default defaultValue: String, preferredLanguages: [String]? = nil) -> String {
        let bundles = [Bundle.main, Bundle.module]

        for bundle in bundles {
            if let preferredLanguages {
                if let localizedValue = localizedInBundle(
                    bundle,
                    key: key,
                    preferredLanguages: preferredLanguages
                ) {
                    return localizedValue
                }
                continue
            }

            let localizedValue = bundle.localizedString(forKey: key, value: nil, table: tableName)
            if localizedValue != key {
                return localizedValue
            }
        }

        return defaultValue
    }

    private static func localizedInBundle(_ bundle: Bundle, key: String, preferredLanguages: [String]) -> String? {
        let preferredLocalizations = Bundle.preferredLocalizations(
            from: bundle.localizations.filter { $0 != "Base" },
            forPreferences: preferredLanguages
        )

        for localization in preferredLocalizations {
            guard let path = bundle.path(forResource: localization, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else {
                continue
            }

            let localizedValue = localizedBundle.localizedString(forKey: key, value: nil, table: tableName)
            if localizedValue != key {
                return localizedValue
            }
        }

        return nil
    }

    private static func formatted(_ key: String, default defaultValue: String, _ arguments: CVarArg...) -> String {
        let format = localized(key, default: defaultValue)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
