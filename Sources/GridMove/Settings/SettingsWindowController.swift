import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: SettingsViewModel
    private let onClose: () -> Void

    init(
        configurationStore: ConfigurationStore,
        configurationProvider: @escaping () -> AppConfiguration,
        onConfigurationSaved: @escaping (AppConfiguration) -> Void,
        onClose: @escaping () -> Void = {}
    ) {
        self.onClose = onClose
        viewModel = SettingsViewModel(
            configurationStore: configurationStore,
            configurationProvider: configurationProvider,
            onConfigurationSaved: onConfigurationSaved
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = UICopy.settingsWindowTitle
        window.minSize = NSSize(width: 860, height: 620)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        window.contentViewController = NSHostingController(rootView: SettingsRootView(viewModel: viewModel))
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        viewModel.show()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func updateConfiguration(_ configuration: AppConfiguration) {
        viewModel.replaceConfiguration(configuration)
    }

    func windowWillClose(_ notification: Notification) {
        handleWindowClose()
    }

    func handleWindowClose() {
        onClose()
    }
}
