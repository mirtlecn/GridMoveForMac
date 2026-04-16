import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configurationStore: ConfigurationStore
    private let openURL: (URL) -> Bool
    private let layoutEngine = LayoutEngine()
    private lazy var windowController = WindowController(layoutEngine: layoutEngine)
    private let overlayController = OverlayController()
    private lazy var accessibilityMonitor = AccessibilityAccessMonitor(
        statusProvider: { [weak self] in
            self?.windowController.isAccessibilityTrusted(prompt: false) ?? false
        }
    )

    private lazy var dragGridController = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { [weak self] in self?.configuration ?? AppConfiguration.defaultValue },
        accessibilityTrustedProvider: { [weak self] in
            self?.accessibilityMonitor.hasAccess ?? false
        },
        onAccessibilityRevoked: { [weak self] in
            self?.forceAccessibilityReevaluation()
        }
    )

    private lazy var shortcutController = ShortcutController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        configurationProvider: { [weak self] in self?.configuration ?? AppConfiguration.defaultValue },
        accessibilityTrustedProvider: { [weak self] in
            self?.accessibilityMonitor.hasAccess ?? false
        },
        onAccessibilityRevoked: { [weak self] in
            self?.forceAccessibilityReevaluation()
        }
    )

    private(set) var configuration = AppConfiguration.defaultValue
    private var menuController: MenuBarController?
    private var onboardingController: OnboardingWindowController?
    private var accessibilityPollingTimer: Timer?

    init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) {
        self.configurationStore = configurationStore
        self.openURL = openURL
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        reloadConfigurationFromDisk()
        configureMainMenu()

        menuController = MenuBarController(
            dragGridEnabled: configuration.general.isEnabled,
            actionItems: makeMenuActionItems(configuration: configuration),
            onToggleDragGrid: { [weak self] isEnabled in
                self?.updateGlobalEnabledState(isEnabled)
            },
            onPerformAction: { [weak self] action in
                self?.performMenuAction(action)
            },
            onReloadConfiguration: { [weak self] in
                self?.reloadConfigurationFromDisk()
            },
            onCustomize: { [weak self] in
                _ = self?.openConfigurationDirectory()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )

        evaluateAccessibilityState()
        startAccessibilityPollingIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragGridController.stop()
        shortcutController.stop()
        accessibilityPollingTimer?.invalidate()
    }

    private func evaluateAccessibilityState() {
        let didChange = accessibilityMonitor.refresh()
        restartAccessibilityPolling()

        guard didChange else {
            return
        }

        if accessibilityMonitor.hasAccess {
            onboardingController?.close()
            onboardingController = nil
            dragGridController.start()
            shortcutController.start()
            applyGlobalEnabledState()
        } else {
            dragGridController.stop()
            shortcutController.stop()
            showOnboardingIfNeeded()
        }
    }

    private func forceAccessibilityReevaluation() {
        accessibilityMonitor.invalidate()
        evaluateAccessibilityState()
    }

    private func startAccessibilityPollingIfNeeded() {
        restartAccessibilityPolling()
    }

    private func restartAccessibilityPolling() {
        accessibilityPollingTimer?.invalidate()
        accessibilityPollingTimer = Timer.scheduledTimer(withTimeInterval: accessibilityMonitor.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateAccessibilityState()
            }
        }
    }

    func reloadConfigurationFromDisk() {
        do {
            applyConfiguration(try configurationStore.load())
        } catch {
            AppLogger.shared.error("Failed to load configuration: \(error.localizedDescription)")
            applyConfiguration(.defaultValue)
        }
    }

    private func updateGlobalEnabledState(_ isEnabled: Bool) {
        guard configuration.general.isEnabled != isEnabled else {
            return
        }

        configuration.general.isEnabled = isEnabled
        do {
            try configurationStore.save(configuration)
        } catch {
            AppLogger.shared.error("Failed to save configuration: \(error.localizedDescription)")
        }
        applyGlobalEnabledState()
        menuController?.updateActionItems(makeMenuActionItems(configuration: configuration), isEnabled: isEnabled)
    }

    private func applyGlobalEnabledState() {
        dragGridController.isEnabled = configuration.general.isEnabled
        shortcutController.isEnabled = configuration.general.isEnabled
        menuController?.setEnabled(configuration.general.isEnabled)
    }

    private func showOnboardingIfNeeded() {
        guard onboardingController == nil else {
            return
        }

        onboardingController = OnboardingWindowController(
            onRequestAccessibility: { [weak self] in
                _ = self?.windowController.isAccessibilityTrusted(prompt: true)
            }
        )
        onboardingController?.show()
    }

    private func makeMenuActionItems(configuration: AppConfiguration) -> [MenuBarController.ActionItem] {
        let cycleItems: [MenuBarController.ActionItem] = [
            MenuBarController.ActionItem(
                title: UICopy.applyPreviousLayout,
                action: .cyclePrevious,
                shortcut: configuration.hotkeys.firstShortcut(for: .cyclePrevious)
            ),
            MenuBarController.ActionItem(
                title: UICopy.applyNextLayout,
                action: .cycleNext,
                shortcut: configuration.hotkeys.firstShortcut(for: .cycleNext)
            ),
        ]

        let layoutItems = configuration.layouts.enumerated().map { index, layout in
            MenuBarController.ActionItem(
                title: UICopy.applyLayout(
                    UICopy.layoutMenuName(
                        name: layout.name,
                        fallbackIdentifier: "layout_\(index + 1)"
                    )
                ),
                action: .applyLayout(layoutID: layout.id),
                shortcut: configuration.hotkeys.firstShortcut(for: .applyLayout(layoutID: layout.id))
            )
        }

        return cycleItems + layoutItems
    }

    private func performMenuAction(_ action: HotkeyAction) {
        guard configuration.general.isEnabled else {
            AppLogger.debugTargeting("menu action \(action.debugDescription) -> skipped because app is disabled")
            return
        }

        guard let window = windowController.windowForLayoutAction(configuration: configuration) else {
            AppLogger.debugTargeting("menu action \(action.debugDescription) -> no target window")
            return
        }

        AppLogger.debugTargeting("menu action \(action.debugDescription) -> target \(window.debugDescription)")

        switch action {
        case let .applyLayout(layoutID):
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: nil,
                configuration: configuration
            )
        case .cycleNext:
            guard let layoutID = layoutEngine.nextLayoutID(for: window.identity, layouts: configuration.layouts) else {
                return
            }
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: nil,
                configuration: configuration
            )
        case .cyclePrevious:
            guard let layoutID = layoutEngine.previousLayoutID(for: window.identity, layouts: configuration.layouts) else {
                return
            }
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: nil,
                configuration: configuration
            )
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu(title: UICopy.applicationMenuTitle)

        let reloadItem = NSMenuItem(title: UICopy.reloadConfigMenuTitle, action: #selector(reloadConfigurationFromMenu), keyEquivalent: "")
        reloadItem.target = self
        applicationMenu.addItem(reloadItem)

        let customizeItem = NSMenuItem(title: UICopy.customizeAppMenuTitle, action: #selector(customizeFromMenu), keyEquivalent: ",")
        customizeItem.target = self
        customizeItem.keyEquivalentModifierMask = [.command]
        applicationMenu.addItem(customizeItem)
        applicationMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: UICopy.quitAppMenuTitle, action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        applicationMenu.addItem(quitItem)

        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func reloadConfigurationFromMenu() {
        reloadConfigurationFromDisk()
    }

    @objc private func customizeFromMenu() {
        _ = openConfigurationDirectory()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    @discardableResult
    func openConfigurationDirectory() -> Bool {
        openURL(configurationStore.directoryURL)
    }

    private func applyConfiguration(_ configuration: AppConfiguration) {
        self.configuration = configuration
        applyGlobalEnabledState()
        menuController?.updateActionItems(
            makeMenuActionItems(configuration: configuration),
            isEnabled: configuration.general.isEnabled
        )
    }
}

private extension HotkeyAction {
    var debugDescription: String {
        switch self {
        case let .applyLayout(layoutID):
            return "applyLayout(\(layoutID))"
        case .cycleNext:
            return "cycleNext"
        case .cyclePrevious:
            return "cyclePrevious"
        }
    }
}
