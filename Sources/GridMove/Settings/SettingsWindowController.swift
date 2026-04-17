import AppKit
import Combine

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate {
    private let viewModel: SettingsViewModel
    private let onClose: () -> Void
    private let rootViewController: SettingsRootViewController
    private var selectedSectionObservation: AnyCancellable?

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
        rootViewController = SettingsRootViewController()

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
        window.toolbarStyle = .preference
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        window.contentViewController = rootViewController
        super.init(window: window)
        window.toolbar = makeToolbar()
        window.delegate = self
        selectedSectionObservation = viewModel.$selectedSection.sink { [weak self] section in
            self?.window?.toolbar?.selectedItemIdentifier = Self.toolbarIdentifier(for: section)
            self?.rootViewController.showSection(section)
        }
        rootViewController.showSection(viewModel.selectedSection)
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

    private func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "GridMove.Settings.Toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.selectedItemIdentifier = Self.toolbarIdentifier(for: viewModel.selectedSection)
        return toolbar
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsViewModel.Section.allCases.map(Self.toolbarIdentifier(for:))
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let section = Self.section(for: itemIdentifier) else {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = section.title
        item.paletteLabel = section.title
        item.toolTip = section.title
        item.image = NSImage(systemSymbolName: section.systemImage, accessibilityDescription: section.title)
        item.target = self
        item.action = #selector(selectSectionFromToolbar(_:))
        return item
    }

    @objc private func selectSectionFromToolbar(_ sender: NSToolbarItem) {
        guard let section = Self.section(for: sender.itemIdentifier) else {
            return
        }
        viewModel.selectedSection = section
    }

    private static func toolbarIdentifier(for section: SettingsViewModel.Section) -> NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("GridMove.Settings.\(section.rawValue)")
    }

    private static func section(for identifier: NSToolbarItem.Identifier) -> SettingsViewModel.Section? {
        SettingsViewModel.Section.allCases.first { toolbarIdentifier(for: $0) == identifier }
    }
}
