import Foundation

enum ConfigurationSchemaConverter {
    static func makeConfigurationFile(from configuration: AppConfiguration) throws -> ConfigurationFile {
        let normalizedConfiguration = try normalizeConfiguration(configuration)
        return ConfigurationFile(
            general: normalizedConfiguration.general,
            appearance: AppearanceConfiguration(settings: normalizedConfiguration.appearance),
            dragTriggers: normalizedConfiguration.dragTriggers,
            hotkeys: HotkeyConfiguration(
                bindings: normalizedConfiguration.hotkeys.bindings.map { binding in
                    HotkeyBindingConfiguration(
                        isEnabled: binding.isEnabled,
                        shortcut: binding.shortcut,
                        action: HotkeyActionConfiguration(action: binding.action)
                    )
                }
            ),
            layoutGroups: normalizedConfiguration.layoutGroups.map(LayoutGroupConfiguration.init(group:)),
            monitors: normalizedConfiguration.monitors
        )
    }

    static func makeAppConfiguration(from configurationFile: ConfigurationFile) throws -> AppConfiguration {
        let generatedLayoutGroups = normalizeLayoutGroups(configurationFile.layoutGroups)
        let generatedBindings = try configurationFile.hotkeys.bindings.enumerated().map { index, binding in
            ShortcutBinding(
                id: "binding-\(index + 1)",
                isEnabled: binding.isEnabled,
                shortcut: binding.shortcut,
                action: try binding.action.makeAction()
            )
        }

        let configuration = AppConfiguration(
            general: configurationFile.general,
            appearance: try configurationFile.appearance.makeSettings(),
            dragTriggers: configurationFile.dragTriggers,
            hotkeys: HotkeySettings(bindings: generatedBindings),
            layoutGroups: generatedLayoutGroups,
            monitors: configurationFile.monitors
        )
        try ConfigurationValidator.validate(configuration)
        return configuration
    }

    private static func normalizeConfiguration(_ configuration: AppConfiguration) throws -> AppConfiguration {
        let normalizedLayoutGroups = normalizeLayoutGroups(configuration.layoutGroups.map(LayoutGroupConfiguration.init(group:)))
        let normalizedBindings = configuration.hotkeys.bindings.enumerated().map { index, binding in
            ShortcutBinding(
                id: "binding-\(index + 1)",
                isEnabled: binding.isEnabled,
                shortcut: binding.shortcut,
                action: binding.action
            )
        }

        let normalizedConfiguration = AppConfiguration(
            general: configuration.general,
            appearance: configuration.appearance,
            dragTriggers: configuration.dragTriggers,
            hotkeys: HotkeySettings(bindings: normalizedBindings),
            layoutGroups: normalizedLayoutGroups,
            monitors: configuration.monitors
        )
        try ConfigurationValidator.validate(normalizedConfiguration)
        return normalizedConfiguration
    }

    private static func normalizeLayoutGroups(_ groups: [LayoutGroupConfiguration]) -> [LayoutGroup] {
        var nextLayoutIndex = 1
        return groups.map { groupConfiguration in
            let sets = groupConfiguration.sets.map { setConfiguration in
                let layouts = setConfiguration.layouts.map { layoutConfiguration in
                    defer { nextLayoutIndex += 1 }
                    return LayoutPreset(
                        id: "layout-\(nextLayoutIndex)",
                        name: layoutConfiguration.name,
                        gridColumns: layoutConfiguration.gridColumns,
                        gridRows: layoutConfiguration.gridRows,
                        windowSelection: layoutConfiguration.windowSelection,
                        triggerRegion: layoutConfiguration.triggerRegion,
                        includeInLayoutIndex: layoutConfiguration.includeInLayoutIndex,
                        includeInMenu: layoutConfiguration.includeInMenu
                    )
                }
                return LayoutSet(monitor: setConfiguration.monitor, layouts: layouts)
            }
            return LayoutGroup(name: groupConfiguration.name, sets: sets)
        }
    }
}
