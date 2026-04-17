import AppKit
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configurationStore: ConfigurationStore
    private let openURL: (URL) -> Bool
    private let notifyUser: (String, String) -> Void
    private let layoutEngine = LayoutEngine()
    private lazy var windowController = WindowController(layoutEngine: layoutEngine)
    private lazy var actionExecutor = LayoutActionExecutor(
        layoutEngine: layoutEngine,
        windowController: windowController,
        configurationProvider: { [weak self] in self?.configuration ?? .defaultValue }
    )
    private let commandRelay = DistributedCommandRelay()
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
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) },
        notifyUser: @escaping (String, String) -> Void = { title, body in
            AppDelegate.postSystemNotification(title: title, body: body)
        }
    ) {
        self.configurationStore = configurationStore
        self.openURL = openURL
        self.notifyUser = notifyUser
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        reloadConfigurationFromDisk(notifyOnFallback: false)
        configureMainMenu()
        commandRelay.startListening { [weak self] command in
            MainActor.assumeIsolated {
                self?.handleRemoteCommand(command) ?? RemoteCommandReply(success: false, message: "GridMove is not available.")
            }
        }

        menuController = MenuBarController(
            dragGridEnabled: configuration.general.isEnabled,
            toggleSettings: makeToggleSettingsState(configuration: configuration),
            actionItems: makeMenuActionItems(configuration: configuration),
            onToggleDragGrid: { [weak self] isEnabled in
                self?.updateGlobalEnabledState(isEnabled)
            },
            onToggleMiddleMouseDrag: { [weak self] isEnabled in
                self?.updateMiddleMouseDragEnabled(isEnabled)
            },
            onToggleModifierLeftMouseDrag: { [weak self] isEnabled in
                self?.updateModifierLeftMouseDragEnabled(isEnabled)
            },
            onTogglePreferLayoutMode: { [weak self] isEnabled in
                self?.updatePreferLayoutMode(isEnabled)
            },
            onPerformAction: { [weak self] action in
                self?.performMenuAction(action)
            },
            onReloadConfiguration: { [weak self] in
                self?.reloadConfigurationFromDisk(notifyOnFallback: true)
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
        commandRelay.stopListening()
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

    func reloadConfigurationFromDisk(notifyOnFallback: Bool = false) {
        do {
            let result = try configurationStore.loadWithStatus()
            applyConfiguration(result.configuration)
            if result.didFallBackToDefault && notifyOnFallback {
                notifyUser(
                    UICopy.configReloadFailedTitle,
                    UICopy.configReloadFailedBody
                )
            }
        } catch {
            AppLogger.shared.error("Failed to load configuration: \(error.localizedDescription)")
            applyConfiguration(.defaultValue)
            if notifyOnFallback {
                notifyUser(
                    UICopy.configReloadFailedTitle,
                    UICopy.configReloadFailedBody
                )
            }
        }
    }

    private func updateGlobalEnabledState(_ isEnabled: Bool) {
        guard configuration.general.isEnabled != isEnabled else {
            return
        }

        updateConfiguration { configuration in
            configuration.general.isEnabled = isEnabled
        }
    }

    func updateMiddleMouseDragEnabled(_ isEnabled: Bool) {
        guard configuration.dragTriggers.enableMiddleMouseDrag != isEnabled else {
            return
        }

        updateConfiguration { configuration in
            configuration.dragTriggers.enableMiddleMouseDrag = isEnabled
        }
    }

    func updateModifierLeftMouseDragEnabled(_ isEnabled: Bool) {
        guard configuration.dragTriggers.enableModifierLeftMouseDrag != isEnabled else {
            return
        }

        updateConfiguration { configuration in
            configuration.dragTriggers.enableModifierLeftMouseDrag = isEnabled
        }
    }

    func updatePreferLayoutMode(_ isEnabled: Bool) {
        guard configuration.dragTriggers.preferLayoutMode != isEnabled else {
            return
        }

        updateConfiguration { configuration in
            configuration.dragTriggers.preferLayoutMode = isEnabled
        }
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
        _ = actionExecutor.execute(hotkeyAction: action)
    }

    private func handleRemoteCommand(_ command: RemoteCommand) -> RemoteCommandReply {
        let result = actionExecutor.execute(commandAction: command.action, targetWindowID: command.targetWindowID)
        switch result {
        case .success:
            return RemoteCommandReply(success: true, message: nil)
        case let .failure(message):
            return RemoteCommandReply(success: false, message: message)
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu(title: UICopy.applicationMenuTitle)

        let reloadItem = NSMenuItem(title: UICopy.reloadConfigMenuTitle, action: #selector(reloadConfigurationFromMenu), keyEquivalent: "")
        reloadItem.target = self
        applicationMenu.addItem(reloadItem)

        let customizeItem = NSMenuItem(title: UICopy.customizeMenuTitle, action: #selector(customizeFromMenu), keyEquivalent: ",")
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
        reloadConfigurationFromDisk(notifyOnFallback: true)
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

    private func updateConfiguration(_ mutate: (inout AppConfiguration) -> Void) {
        mutate(&configuration)

        do {
            try configurationStore.save(configuration)
        } catch {
            AppLogger.shared.error("Failed to save configuration: \(error.localizedDescription)")
        }

        applyConfiguration(configuration)
    }

    private func applyConfiguration(_ configuration: AppConfiguration) {
        self.configuration = configuration
        applyGlobalEnabledState()
        menuController?.updateActionItems(
            makeMenuActionItems(configuration: configuration),
            isEnabled: configuration.general.isEnabled
        )
        menuController?.updateToggleStates(makeToggleSettingsState(configuration: configuration))
    }

    private func makeToggleSettingsState(configuration: AppConfiguration) -> MenuBarController.ToggleSettingsState {
        MenuBarController.ToggleSettingsState(
            middleMouseDragEnabled: configuration.dragTriggers.enableMiddleMouseDrag,
            modifierLeftMouseDragEnabled: configuration.dragTriggers.enableModifierLeftMouseDrag,
            preferLayoutMode: configuration.dragTriggers.preferLayoutMode
        )
    }

    nonisolated private static func postSystemNotification(title: String, body: String) {
        if Bundle.main.bundleURL.pathExtension == "app", Bundle.main.bundleIdentifier != nil {
            postUserNotificationCenterNotification(title: title, body: body)
            return
        }

        postAppleScriptNotification(title: title, body: body)
    }

    nonisolated private static func postUserNotificationCenterNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                AppLogger.shared.error("Failed to request notification authorization: \(error.localizedDescription, privacy: .public)")
                return
            }

            guard granted else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "gridmove-config-reload-failed",
                content: content,
                trigger: nil
            )
            center.add(request) { error in
                if let error {
                    AppLogger.shared.error("Failed to post notification: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    nonisolated private static func postAppleScriptNotification(title: String, body: String) {
        let scriptSource = """
        display notification "\(escapeAppleScript(body))" with title "\(escapeAppleScript(title))"
        """

        var error: NSDictionary?
        NSAppleScript(source: scriptSource)?.executeAndReturnError(&error)
        if let error {
            AppLogger.shared.error("Failed to post AppleScript notification: \(error.description, privacy: .public)")
        }
    }

    nonisolated private static func escapeAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
