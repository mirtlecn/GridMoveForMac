import AppKit

struct SettingsWindowMetrics {
    let preferredContentSize: NSSize
    let minimumContentSize: NSSize
}

@MainActor
protocol SettingsWindowSizing {
    var settingsWindowMetrics: SettingsWindowMetrics { get }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let onWindowWillClose: () -> Void

    init(onWindowWillClose: @escaping () -> Void = {}) {
        self.onWindowWillClose = onWindowWillClose

        let tabViewController = SettingsTabViewController()
        let initialMetrics = tabViewController.currentWindowMetrics
        let window = NSWindow(contentViewController: tabViewController)
        window.title = UICopy.settingsWindowTitle
        window.styleMask.insert(.titled)
        window.styleMask.insert(.closable)
        window.styleMask.insert(.miniaturizable)
        window.styleMask.insert(.resizable)
        window.setContentSize(initialMetrics.preferredContentSize)
        window.minSize = initialMetrics.minimumContentSize
        window.center()

        super.init(window: window)

        window.delegate = self
        tabViewController.onSelectedMetricsChanged = { [weak self] metrics in
            self?.applyWindowMetrics(metrics, animated: true)
        }
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        guard let window else {
            return
        }

        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onWindowWillClose()
    }

    private func applyWindowMetrics(_ metrics: SettingsWindowMetrics, animated: Bool) {
        guard let window else {
            return
        }

        window.minSize = metrics.minimumContentSize

        let targetContentSize = NSSize(
            width: max(metrics.minimumContentSize.width, metrics.preferredContentSize.width),
            height: max(metrics.minimumContentSize.height, metrics.preferredContentSize.height)
        )
        let targetFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetContentSize))
        let frameOrigin = NSPoint(
            x: window.frame.origin.x,
            y: window.frame.maxY - targetFrame.height
        )

        window.setFrame(
            NSRect(origin: frameOrigin, size: targetFrame.size),
            display: true,
            animate: animated
        )
    }
}

@MainActor
final class SettingsTabViewController: NSTabViewController {
    var onSelectedMetricsChanged: ((SettingsWindowMetrics) -> Void)?

    var currentWindowMetrics: SettingsWindowMetrics {
        let selectedViewController: NSViewController? = tabViewItems.indices.contains(selectedTabViewItemIndex)
            ? tabViewItems[selectedTabViewItemIndex].viewController
            : tabViewItems.first?.viewController
        return metrics(for: selectedViewController)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabStyle = .toolbar
        transitionOptions = []

        addSettingsTab(
            viewController: GeneralSettingsViewController(),
            title: UICopy.settingsGeneralTabTitle,
            systemImageName: "gearshape"
        )
        addSettingsTab(
            viewController: LayoutsSettingsViewController(),
            title: UICopy.settingsLayoutsTabTitle,
            systemImageName: "rectangle.3.group"
        )
        addSettingsTab(
            viewController: AppearanceSettingsViewController(),
            title: UICopy.settingsAppearanceTabTitle,
            systemImageName: "paintbrush"
        )
        addSettingsTab(
            viewController: HotkeysSettingsViewController(),
            title: UICopy.settingsHotkeysTabTitle,
            systemImageName: "keyboard"
        )
        addSettingsTab(
            viewController: AboutSettingsViewController(),
            title: UICopy.settingsAboutTabTitle,
            systemImageName: "info.circle"
        )
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        onSelectedMetricsChanged?(currentWindowMetrics)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        onSelectedMetricsChanged?(metrics(for: tabViewItem?.viewController))
    }

    private func addSettingsTab(viewController: NSViewController, title: String, systemImageName: String) {
        addChild(viewController)
        tabViewItems.last?.label = title
        tabViewItems.last?.image = NSImage(
            systemSymbolName: systemImageName,
            accessibilityDescription: title
        )
    }

    private func metrics(for viewController: NSViewController?) -> SettingsWindowMetrics {
        (viewController as? SettingsWindowSizing)?.settingsWindowMetrics
            ?? SettingsWindowMetrics(
                preferredContentSize: NSSize(width: 700, height: 560),
                minimumContentSize: NSSize(width: 680, height: 540)
            )
    }
}

extension GeneralSettingsViewController: SettingsWindowSizing {
    var settingsWindowMetrics: SettingsWindowMetrics {
        SettingsWindowMetrics(
            preferredContentSize: NSSize(width: 700, height: 540),
            minimumContentSize: NSSize(width: 680, height: 540)
        )
    }
}

extension LayoutsSettingsViewController: SettingsWindowSizing {
    var settingsWindowMetrics: SettingsWindowMetrics {
        SettingsWindowMetrics(
            preferredContentSize: NSSize(width: 780, height: 640),
            minimumContentSize: NSSize(width: 680, height: 640)
        )
    }
}

extension AppearanceSettingsViewController: SettingsWindowSizing {
    var settingsWindowMetrics: SettingsWindowMetrics {
        SettingsWindowMetrics(
            preferredContentSize: NSSize(width: 700, height: 500),
            minimumContentSize: NSSize(width: 680, height: 500)
        )
    }
}

extension HotkeysSettingsViewController: SettingsWindowSizing {
    var settingsWindowMetrics: SettingsWindowMetrics {
        SettingsWindowMetrics(
            preferredContentSize: NSSize(width: 700, height: 400),
            minimumContentSize: NSSize(width: 680, height: 400)
        )
    }
}

extension AboutSettingsViewController: SettingsWindowSizing {
    var settingsWindowMetrics: SettingsWindowMetrics {
        SettingsWindowMetrics(
            preferredContentSize: NSSize(width: 700, height: 180),
            minimumContentSize: NSSize(width: 680, height: 180)
        )
    }
}
