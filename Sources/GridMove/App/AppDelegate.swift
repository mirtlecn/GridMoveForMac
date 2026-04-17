import AppKit
import Foundation
@preconcurrency import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configurationStore: ConfigurationStore
    private let openURL: (URL) -> Bool
    private let notifyUser: (String, String) -> Void
    private let injectedAccessibilityStatusProvider: (() -> Bool)?
    private let injectedAccessibilityPromptRequester: (() -> Bool)?
    private let layoutEngine = LayoutEngine()
    private lazy var windowController = WindowController(layoutEngine: layoutEngine)
    private lazy var actionExecutor = LayoutActionExecutor(
        layoutEngine: layoutEngine,
        windowController: windowController,
        configurationProvider: { [weak self] in self?.configuration ?? .defaultValue },
        accessibilityAccessValidator: { [weak self] in
            self?.validateAccessibilityAccessForAction() ?? false
        }
    )
    private let commandRelay = DistributedCommandRelay()
    private let overlayController = OverlayController()
    private lazy var accessibilityMonitor = AccessibilityAccessMonitor(
        statusProvider: { [weak self] in
            self?.currentAccessibilityStatus() ?? false
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
        accessibilityAccessValidator: { [weak self] in
            self?.validateAccessibilityAccessForAction() ?? false
        },
        onAccessibilityRevoked: { [weak self] in
            self?.forceAccessibilityReevaluation()
        }
    )

    private lazy var shortcutController = ShortcutController(
        actionExecutor: actionExecutor,
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
    private var accessibilityPollingTimer: Timer?
    private var currentAccessibilityPollingInterval: TimeInterval?

    init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) },
        accessibilityStatusProvider: (() -> Bool)? = nil,
        accessibilityPromptRequester: (() -> Bool)? = nil,
        notifyUser: @escaping (String, String) -> Void = { title, body in
            AppDelegate.postSystemNotification(title: title, body: body)
        }
    ) {
        self.configurationStore = configurationStore
        self.openURL = openURL
        self.injectedAccessibilityStatusProvider = accessibilityStatusProvider
        self.injectedAccessibilityPromptRequester = accessibilityPromptRequester
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
            layoutGroupState: makeLayoutGroupState(configuration: configuration),
            actionItems: makeMenuActionItems(configuration: configuration),
            onToggleDragGrid: { [weak self] isEnabled in
                self?.updateGlobalEnabledState(isEnabled) ?? false
            },
            onToggleMiddleMouseDrag: { [weak self] isEnabled in
                self?.updateMiddleMouseDragEnabled(isEnabled) ?? false
            },
            onToggleModifierLeftMouseDrag: { [weak self] isEnabled in
                self?.updateModifierLeftMouseDragEnabled(isEnabled) ?? false
            },
            onTogglePreferLayoutMode: { [weak self] isEnabled in
                self?.updatePreferLayoutMode(isEnabled) ?? false
            },
            onSelectLayoutGroup: { [weak self] groupName in
                self?.updateActiveLayoutGroup(groupName) ?? false
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
        currentAccessibilityPollingInterval = nil
        commandRelay.stopListening()
    }

    func evaluateAccessibilityState() {
        _ = refreshAccessibilityState(promptOnMissing: true)
    }

    private func forceAccessibilityReevaluation() {
        accessibilityMonitor.invalidate()
        evaluateAccessibilityState()
    }

    private func startAccessibilityPollingIfNeeded() {
        synchronizeAccessibilityPolling()
    }

    private func synchronizeAccessibilityPolling() {
        guard let nextPollingInterval = accessibilityMonitor.pollingInterval else {
            accessibilityPollingTimer?.invalidate()
            accessibilityPollingTimer = nil
            currentAccessibilityPollingInterval = nil
            return
        }

        guard accessibilityPollingTimer == nil || currentAccessibilityPollingInterval != nextPollingInterval else {
            return
        }

        accessibilityPollingTimer?.invalidate()
        accessibilityPollingTimer = Timer.scheduledTimer(withTimeInterval: nextPollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateAccessibilityState()
            }
        }
        currentAccessibilityPollingInterval = nextPollingInterval
    }

    @discardableResult
    private func refreshAccessibilityState(promptOnMissing: Bool) -> Bool {
        let currentAccess = currentAccessibilityStatus()
        let didChange = accessibilityMonitor.refresh(currentAccess: currentAccess)
        synchronizeAccessibilityPolling()
        synchronizeRuntimeControllers()

        if promptOnMissing && didChange && !currentAccess {
            _ = requestAccessibilityPrompt()
        }

        return currentAccess
    }

    func reloadConfigurationFromDisk(notifyOnFallback: Bool = false) {
        do {
            let result = try configurationStore.loadWithStatus()
            var configuration = result.configuration
            synchronizeMonitorMetadata(configuration: &configuration)
            applyConfiguration(configuration)
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

    @discardableResult
    private func updateGlobalEnabledState(_ isEnabled: Bool) -> Bool {
        guard configuration.general.isEnabled != isEnabled else {
            return true
        }

        return updateConfiguration { configuration in
            configuration.general.isEnabled = isEnabled
        }
    }

    @discardableResult
    func updateMiddleMouseDragEnabled(_ isEnabled: Bool) -> Bool {
        guard configuration.dragTriggers.enableMiddleMouseDrag != isEnabled else {
            return true
        }

        return updateConfiguration { configuration in
            configuration.dragTriggers.enableMiddleMouseDrag = isEnabled
        }
    }

    @discardableResult
    func updateModifierLeftMouseDragEnabled(_ isEnabled: Bool) -> Bool {
        guard configuration.dragTriggers.enableModifierLeftMouseDrag != isEnabled else {
            return true
        }

        return updateConfiguration { configuration in
            configuration.dragTriggers.enableModifierLeftMouseDrag = isEnabled
        }
    }

    @discardableResult
    func updatePreferLayoutMode(_ isEnabled: Bool) -> Bool {
        guard configuration.dragTriggers.preferLayoutMode != isEnabled else {
            return true
        }

        return updateConfiguration { configuration in
            configuration.dragTriggers.preferLayoutMode = isEnabled
        }
    }

    @discardableResult
    func updateActiveLayoutGroup(_ groupName: String) -> Bool {
        guard configuration.general.activeLayoutGroup != groupName else {
            return true
        }

        guard configuration.layoutGroups.contains(where: { $0.name == groupName }) else {
            return false
        }

        return updateConfiguration { configuration in
            configuration.general.activeLayoutGroup = groupName
        }
    }

    private func synchronizeRuntimeControllers() {
        let shouldListenForGlobalInput = accessibilityMonitor.hasAccess && configuration.general.isEnabled
        if shouldListenForGlobalInput {
            dragGridController.start()
            shortcutController.start()
        } else {
            dragGridController.stop()
            shortcutController.stop()
        }

        dragGridController.isEnabled = configuration.general.isEnabled
        shortcutController.isEnabled = configuration.general.isEnabled
        menuController?.setEnabled(configuration.general.isEnabled)
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

        let layoutItems = LayoutGroupResolver.flattenedActiveEntries(in: configuration).enumerated().map { index, entry in
            MenuBarController.ActionItem(
                title: UICopy.applyLayout(
                    UICopy.layoutMenuName(
                        name: entry.layout.name,
                        fallbackIdentifier: "layout_\(index + 1)"
                    )
                ),
                action: .applyLayoutByName(name: entry.layout.name),
                shortcut: nil
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
        NSApplication.shared.mainMenu = mainMenu
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

    @discardableResult
    private func updateConfiguration(_ mutate: (inout AppConfiguration) -> Void) -> Bool {
        var candidateConfiguration = configuration
        mutate(&candidateConfiguration)
        synchronizeMonitorMetadata(configuration: &candidateConfiguration)

        do {
            try configurationStore.save(candidateConfiguration)
        } catch {
            AppLogger.shared.error("Failed to save configuration: \(error.localizedDescription)")
            menuController?.updateToggleStates(makeToggleSettingsState(configuration: configuration))
            menuController?.setEnabled(configuration.general.isEnabled)
            return false
        }

        applyConfiguration(candidateConfiguration)
        return true
    }

    private func applyConfiguration(_ configuration: AppConfiguration) {
        if self.configuration.layoutGroups != configuration.layoutGroups
            || self.configuration.general.activeLayoutGroup != configuration.general.activeLayoutGroup {
            layoutEngine.resetRecordedLayoutIDs()
        }
        self.configuration = configuration
        synchronizeRuntimeControllers()
        menuController?.updateActionItems(
            makeMenuActionItems(configuration: configuration),
            isEnabled: configuration.general.isEnabled
        )
        menuController?.updateLayoutGroupState(
            makeLayoutGroupState(configuration: configuration),
            isEnabled: configuration.general.isEnabled
        )
        menuController?.updateToggleStates(makeToggleSettingsState(configuration: configuration))
    }

    var isDragInputMonitoringActiveForTesting: Bool {
        dragGridController.eventTap != nil
    }

    var isShortcutInputMonitoringActiveForTesting: Bool {
        shortcutController.isMonitoringInputForTesting
    }

    var shouldMonitorGlobalInputForTesting: Bool {
        accessibilityMonitor.hasAccess && configuration.general.isEnabled
    }

    var isAccessibilityPollingActiveForTesting: Bool {
        accessibilityPollingTimer != nil
    }

    var accessibilityPollingIntervalForTesting: TimeInterval? {
        currentAccessibilityPollingInterval
    }

    func recordLayoutIDForTesting(_ layoutID: String, windowIdentity: String) {
        layoutEngine.recordLayoutID(layoutID, for: windowIdentity)
    }

    func nextLayoutIDForTesting(windowIdentity: String) -> String? {
        layoutEngine.nextLayoutID(for: windowIdentity, layouts: configuration.layouts)
    }

    private func makeLayoutGroupState(configuration: AppConfiguration) -> MenuBarController.LayoutGroupState {
        MenuBarController.LayoutGroupState(
            groupNames: configuration.layoutGroupNames(),
            activeGroupName: configuration.general.activeLayoutGroup
        )
    }

    private func makeToggleSettingsState(configuration: AppConfiguration) -> MenuBarController.ToggleSettingsState {
        MenuBarController.ToggleSettingsState(
            middleMouseDragEnabled: configuration.dragTriggers.enableMiddleMouseDrag,
            modifierLeftMouseDragEnabled: configuration.dragTriggers.enableModifierLeftMouseDrag,
            preferLayoutMode: configuration.dragTriggers.preferLayoutMode
        )
    }

    private func synchronizeMonitorMetadata(configuration: inout AppConfiguration) {
        let monitorMap = MonitorDiscovery.currentMonitorMap()
        configuration.monitors = monitorMap
    }

    private func currentAccessibilityStatus() -> Bool {
        injectedAccessibilityStatusProvider?() ?? windowController.isAccessibilityTrusted(prompt: false)
    }

    private func requestAccessibilityPrompt() -> Bool {
        injectedAccessibilityPromptRequester?() ?? windowController.isAccessibilityTrusted(prompt: true)
    }

    private func validateAccessibilityAccessForAction() -> Bool {
        refreshAccessibilityState(promptOnMissing: true)
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
