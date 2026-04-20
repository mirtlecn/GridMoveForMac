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
    private var closeShortcutMonitor: Any?
    private var editingCommitMonitor: Any?

    init(
        prototypeState: SettingsPrototypeState,
        actionHandler: any SettingsActionHandling,
        onWindowWillClose: @escaping () -> Void = {}
    ) {
        self.onWindowWillClose = onWindowWillClose

        let tabViewController = SettingsTabViewController(
            prototypeState: prototypeState,
            actionHandler: actionHandler
        )
        tabViewController.loadViewIfNeeded()
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
        installCloseShortcutMonitor()
        installEditingCommitMonitor()
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
        clearEditingFocus(in: window)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        removeCloseShortcutMonitor()
        removeEditingCommitMonitor()
        onWindowWillClose()
    }

    func handleCommandWForTesting(isKeyWindow: Bool = true) -> Bool {
        guard let window else {
            return false
        }

        guard shouldHandleCloseShortcut(isVisible: window.isVisible, isKeyWindow: isKeyWindow) else {
            return false
        }

        window.performClose(nil)
        return true
    }

    func commitEditingForTesting(clickedInsideEditableControl: Bool) -> Bool {
        guard let window,
              window.firstResponder is NSTextView,
              shouldCommitEditing(clickedInsideEditableControl: clickedInsideEditableControl) else {
            return false
        }

        clearEditingFocus(in: window)
        return true
    }

    var currentWindowMetricsForTesting: SettingsWindowMetrics {
        guard let tabViewController = window?.contentViewController as? SettingsTabViewController else {
            return SettingsWindowMetrics(
                preferredContentSize: .zero,
                minimumContentSize: .zero
            )
        }

        return tabViewController.currentWindowMetrics
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

    private func clearEditingFocus(in window: NSWindow) {
        window.endEditing(for: nil)
        _ = window.makeFirstResponder(nil)
    }

    private var shouldHandleCloseShortcut: Bool {
        guard let window else {
            return false
        }

        return shouldHandleCloseShortcut(isVisible: window.isVisible, isKeyWindow: window.isKeyWindow)
    }

    private func installCloseShortcutMonitor() {
        closeShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            return self.handleCloseShortcutEvent(event)
        }
    }

    private func removeCloseShortcutMonitor() {
        guard let closeShortcutMonitor else {
            return
        }

        NSEvent.removeMonitor(closeShortcutMonitor)
        self.closeShortcutMonitor = nil
    }

    private func installEditingCommitMonitor() {
        editingCommitMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else {
                return event
            }

            self.commitEditingIfNeeded(for: event)
            return event
        }
    }

    private func removeEditingCommitMonitor() {
        guard let editingCommitMonitor else {
            return
        }

        NSEvent.removeMonitor(editingCommitMonitor)
        self.editingCommitMonitor = nil
    }

    private func handleCloseShortcutEvent(_ event: NSEvent) -> NSEvent? {
        guard event.type == .keyDown,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
              event.charactersIgnoringModifiers?.lowercased() == "w",
              shouldHandleCloseShortcut else {
            return event
        }

        window?.performClose(nil)
        return nil
    }

    private func shouldHandleCloseShortcut(isVisible: Bool, isKeyWindow: Bool) -> Bool {
        isVisible && isKeyWindow
    }

    private func commitEditingIfNeeded(for event: NSEvent) {
        guard let window,
              window.isVisible,
              window.firstResponder is NSTextView,
              shouldCommitEditing(for: event, in: window) else {
            return
        }

        clearEditingFocus(in: window)
    }

    private func shouldCommitEditing(for event: NSEvent, in window: NSWindow) -> Bool {
        guard let contentView = window.contentView else {
            return false
        }

        let locationInContentView = contentView.convert(event.locationInWindow, from: nil)
        guard let clickedView = contentView.hitTest(locationInContentView) else {
            return true
        }

        return shouldCommitEditing(clickedInsideEditableControl: clickedView.isDescendant(ofEditableControlIn: window))
    }

    private func shouldCommitEditing(clickedInsideEditableControl: Bool) -> Bool {
        clickedInsideEditableControl == false
    }
}

private extension NSView {
    func isDescendant(ofEditableControlIn window: NSWindow) -> Bool {
        if let textField = self as? NSTextField, textField.isEditable {
            return true
        }

        if let textView = self as? NSTextView,
           textView == window.firstResponder || textView.isFieldEditor {
            return true
        }

        return superview?.isDescendant(ofEditableControlIn: window) ?? false
    }
}

@MainActor
final class SettingsTabViewController: NSTabViewController {
    var onSelectedMetricsChanged: ((SettingsWindowMetrics) -> Void)?
    private let prototypeState: SettingsPrototypeState
    private let actionHandler: any SettingsActionHandling

    init(prototypeState: SettingsPrototypeState, actionHandler: any SettingsActionHandling) {
        self.prototypeState = prototypeState
        self.actionHandler = actionHandler
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

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
            viewController: GeneralSettingsViewController(
                prototypeState: prototypeState,
                actionHandler: actionHandler
            ),
            title: UICopy.settingsGeneralTabTitle,
            systemImageName: "gearshape"
        )
        addSettingsTab(
            viewController: LayoutsSettingsViewController(
                prototypeState: prototypeState,
                actionHandler: actionHandler
            ),
            title: UICopy.settingsLayoutsTabTitle,
            systemImageName: "rectangle.3.group"
        )
        addSettingsTab(
            viewController: AppearanceSettingsViewController(
                prototypeState: prototypeState,
                actionHandler: actionHandler
            ),
            title: UICopy.settingsAppearanceTabTitle,
            systemImageName: "paintbrush"
        )
        addSettingsTab(
            viewController: HotkeysSettingsViewController(
                prototypeState: prototypeState,
                actionHandler: actionHandler
            ),
            title: UICopy.settingsHotkeysTabTitle,
            systemImageName: "keyboard"
        )
        addSettingsTab(
            viewController: AboutSettingsViewController(
                prototypeState: prototypeState,
                actionHandler: actionHandler
            ),
            title: UICopy.settingsAboutTabTitle,
            systemImageName: "info.circle"
        )
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        onSelectedMetricsChanged?(currentWindowMetrics)
        clearAutomaticEditingFocus()
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        onSelectedMetricsChanged?(metrics(for: tabViewItem?.viewController))
        clearAutomaticEditingFocus()
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

    private func clearAutomaticEditingFocus() {
        guard let window = view.window else {
            return
        }

        window.endEditing(for: nil)
        _ = window.makeFirstResponder(nil)
    }
}

extension GeneralSettingsViewController: SettingsWindowSizing {
    var settingsWindowMetrics: SettingsWindowMetrics {
        SettingsWindowMetrics(
            preferredContentSize: NSSize(width: 700, height: 640),
            minimumContentSize: NSSize(width: 680, height: 640)
        )
    }
}

extension LayoutsSettingsViewController: SettingsWindowSizing {
    var settingsWindowMetrics: SettingsWindowMetrics {
        SettingsWindowMetrics(
            preferredContentSize: NSSize(width: 700, height: 640),
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
            preferredContentSize: NSSize(width: 700, height: 260),
            minimumContentSize: NSSize(width: 680, height: 260)
        )
    }
}
