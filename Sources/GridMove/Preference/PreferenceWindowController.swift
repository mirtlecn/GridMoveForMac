import AppKit

@MainActor
final class PreferenceTabViewController: NSTabViewController {
    private let viewModel: PreferenceViewModel
    let generalController: PreferenceGeneralViewController
    let hotkeysController: PreferenceHotkeysViewController
    let aboutController = PreferenceAboutViewController()

    init(viewModel: PreferenceViewModel) {
        self.viewModel = viewModel
        generalController = PreferenceGeneralViewController(viewModel: viewModel)
        hotkeysController = PreferenceHotkeysViewController(viewModel: viewModel)
        super.init(nibName: nil, bundle: nil)
        configureTabs()
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        fatalError("init(nibName:bundle:) has not been implemented")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var tabTitlesForTesting: [String] {
        tabViewItems.map(\.label)
    }

    private func configureTabs() {
        tabStyle = .toolbar
        transitionOptions = .allowUserInteraction

        for tab in PreferenceTab.allCases {
            let viewController = makeViewController(for: tab)
            addChild(viewController)
            if let item = tabViewItems.last {
                item.label = tab.title
                item.image = NSImage(
                    systemSymbolName: tab.symbolName,
                    accessibilityDescription: tab.title
                )
            }
        }
    }

    private func makeViewController(for tab: PreferenceTab) -> NSViewController {
        let viewController: NSViewController
        switch tab {
        case .general:
            viewController = generalController
        case .hotkeys:
            viewController = hotkeysController
        case .about:
            viewController = aboutController
        case .layouts, .appearance:
            viewController = PreferencePlaceholderViewController(
                title: tab.title,
                message: UICopy.preferencePlaceholderMessage
            )
        }

        viewController.title = tab.title
        return viewController
    }

    func updateConfiguration(_ configuration: AppConfiguration) {
        viewModel.replaceConfiguration(configuration)
        generalController.reloadFromViewModel()
        hotkeysController.reloadFromViewModel()
    }
}

@MainActor
final class PreferenceWindowController: NSWindowController, NSWindowDelegate {
    private let viewModel: PreferenceViewModel
    private let tabController: PreferenceTabViewController
    private let onClose: () -> Void

    init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        configurationProvider: @escaping () -> AppConfiguration = { AppConfiguration.defaultValue },
        onConfigurationSaved: @escaping (AppConfiguration) -> Void = { _ in },
        onClose: @escaping () -> Void = {}
    ) {
        self.onClose = onClose
        viewModel = PreferenceViewModel(
            configurationStore: configurationStore,
            configurationProvider: configurationProvider,
            onConfigurationSaved: onConfigurationSaved
        )
        tabController = PreferenceTabViewController(viewModel: viewModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = UICopy.preferenceWindowTitle
        window.minSize = NSSize(width: 760, height: 560)
        window.titlebarAppearsTransparent = true
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
            window.titlebarSeparatorStyle = .line
        }
        window.contentViewController = tabController

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var tabTitlesForTesting: [String] {
        tabController.tabTitlesForTesting
    }

    var generalSectionTitlesForTesting: [String] {
        tabController.generalController.sectionTitlesForTesting
    }

    var hotkeyRowCountForTesting: Int {
        tabController.hotkeysController.rowCountForTesting
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func updateConfiguration(_ configuration: AppConfiguration) {
        tabController.updateConfiguration(configuration)
    }

    func windowWillClose(_ notification: Notification) {
        handleWindowClose()
    }

    func handleWindowClose() {
        onClose()
    }
}
