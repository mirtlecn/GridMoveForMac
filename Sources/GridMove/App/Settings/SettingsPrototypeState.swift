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

    @discardableResult
    func applyImmediateMutation(
        using actionHandler: any SettingsActionHandling,
        _ mutate: (inout AppConfiguration) -> Void
    ) -> Bool {
        var candidate = configuration
        mutate(&candidate)
        return applyImmediateConfiguration(candidate, using: actionHandler)
    }

    @discardableResult
    func applyImmediateConfiguration(
        _ candidate: AppConfiguration,
        using actionHandler: any SettingsActionHandling
    ) -> Bool {
        guard actionHandler.applyImmediateConfiguration(candidate) else {
            configuration = committedConfiguration
            notifyDidChange()
            return false
        }

        configuration = candidate
        committedConfiguration = candidate
        notifyDidChange()
        return true
    }

    func updateDraftFromLayoutsPrototype(_ configuration: AppConfiguration) {
        self.configuration = configuration
        notifyDidChange()
    }

    private func notifyDidChange() {
        NotificationCenter.default.post(name: .settingsPrototypeStateDidChange, object: self)
    }
}
