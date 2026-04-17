import AppKit

@MainActor
final class PreferenceTabViewController: NSTabViewController {
    let generalController = PreferenceGeneralViewController()

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        configureTabs()
    }

    convenience init() {
        self.init(nibName: nil, bundle: nil)
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
        case .layouts, .appearance, .hotkeys, .about:
            viewController = PreferencePlaceholderViewController(
                title: tab.title,
                message: UICopy.preferencePlaceholderMessage
            )
        }

        viewController.title = tab.title
        return viewController
    }
}

@MainActor
final class PreferenceWindowController: NSWindowController, NSWindowDelegate {
    private let tabController = PreferenceTabViewController()
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose

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

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        handleWindowClose()
    }

    func handleWindowClose() {
        onClose()
    }
}
