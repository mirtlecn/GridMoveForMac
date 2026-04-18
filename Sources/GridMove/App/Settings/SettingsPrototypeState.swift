import AppKit

@MainActor
final class SettingsPrototypeState {
    // This is the shared UI draft for the prototype settings window.
    // When real model wiring starts, tabs should continue reading and writing
    // through this object first, then persist from one place.
    var configuration: AppConfiguration

    init(configuration: AppConfiguration = .defaultValue) {
        var draftConfiguration = configuration
        if draftConfiguration.general.excludedBundleIDs == ["com.apple.Spotlight"] {
            draftConfiguration.general.excludedBundleIDs.append("com.example.HiddenApp")
        }
        if draftConfiguration.general.excludedWindowTitles.isEmpty {
            draftConfiguration.general.excludedWindowTitles = ["Picture in Picture", "Quick Look"]
        }
        self.configuration = draftConfiguration
    }

    func currentMonitorNameMap() -> [String: String] {
        configuration.monitors
    }
}
