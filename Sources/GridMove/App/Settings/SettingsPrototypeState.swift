import AppKit

@MainActor
final class SettingsPrototypeState {
    private(set) var configuration: AppConfiguration
    private(set) var committedConfiguration: AppConfiguration

    init(configuration: AppConfiguration = .defaultValue) {
        self.configuration = configuration
        committedConfiguration = configuration
    }

    func currentMonitorNameMap() -> [String: String] {
        configuration.monitors
    }

    func reload(from configuration: AppConfiguration) {
        self.configuration = configuration
        committedConfiguration = configuration
        notifyDidChange()
    }

    func syncExternalConfiguration(_ configuration: AppConfiguration) {
        committedConfiguration = configuration

        var updatedDraft = self.configuration
        updatedDraft.general = configuration.general
        updatedDraft.appearance = configuration.appearance
        updatedDraft.dragTriggers = configuration.dragTriggers
        updatedDraft.hotkeys = configuration.hotkeys
        updatedDraft.monitors = configuration.monitors
        if updatedDraft.layoutGroups.contains(where: { $0.name == configuration.general.activeLayoutGroup }) {
            updatedDraft.general.activeLayoutGroup = configuration.general.activeLayoutGroup
        } else if let fallbackGroupName = updatedDraft.layoutGroups.first?.name {
            updatedDraft.general.activeLayoutGroup = fallbackGroupName
        }

        self.configuration = updatedDraft
        notifyDidChange()
    }

    @discardableResult
    func applyImmediateMutation(
        using actionHandler: any SettingsActionHandling,
        _ mutate: (inout AppConfiguration) -> Void
    ) -> Bool {
        var candidate = committedConfiguration
        mutate(&candidate)
        return applyImmediateConfiguration(candidate, using: actionHandler)
    }

    @discardableResult
    func applyImmediateConfiguration(
        _ candidate: AppConfiguration,
        using actionHandler: any SettingsActionHandling
    ) -> Bool {
        guard actionHandler.applyImmediateConfiguration(candidate) else {
            configuration = mergedDraftPreservingLayouts(from: committedConfiguration)
            notifyDidChange()
            return false
        }

        committedConfiguration = candidate
        configuration = mergedDraftPreservingLayouts(from: candidate)
        notifyDidChange()
        return true
    }

    func applyLayoutsMutation(_ mutate: (inout AppConfiguration) -> Void) {
        var updatedConfiguration = configuration
        mutate(&updatedConfiguration)
        configuration = updatedConfiguration
        notifyDidChange()
    }

    var hasLayoutsDraftChanges: Bool {
        configuration.general.activeLayoutGroup != committedConfiguration.general.activeLayoutGroup
            || configuration.layoutGroups != committedConfiguration.layoutGroups
    }

    @discardableResult
    func commitLayoutsDraft(using actionHandler: any SettingsActionHandling) -> Bool {
        let candidate = configuration
        guard actionHandler.saveLayoutsConfiguration(candidate) else {
            notifyDidChange()
            return false
        }

        committedConfiguration = candidate
        notifyDidChange()
        return true
    }

    func discardLayoutsDraft() {
        configuration.general.activeLayoutGroup = committedConfiguration.general.activeLayoutGroup
        configuration.layoutGroups = committedConfiguration.layoutGroups
        notifyDidChange()
    }

    private func notifyDidChange() {
        NotificationCenter.default.post(name: .settingsPrototypeStateDidChange, object: self)
    }

    private func mergedDraftPreservingLayouts(from immediateConfiguration: AppConfiguration) -> AppConfiguration {
        var updatedDraft = configuration
        updatedDraft.general.isEnabled = immediateConfiguration.general.isEnabled
        updatedDraft.general.launchAtLogin = immediateConfiguration.general.launchAtLogin
        updatedDraft.general.excludedBundleIDs = immediateConfiguration.general.excludedBundleIDs
        updatedDraft.general.excludedWindowTitles = immediateConfiguration.general.excludedWindowTitles
        updatedDraft.general.mouseButtonNumber = immediateConfiguration.general.mouseButtonNumber
        updatedDraft.appearance = immediateConfiguration.appearance
        updatedDraft.dragTriggers = immediateConfiguration.dragTriggers
        updatedDraft.hotkeys = immediateConfiguration.hotkeys
        updatedDraft.monitors = immediateConfiguration.monitors
        return updatedDraft
    }
}
