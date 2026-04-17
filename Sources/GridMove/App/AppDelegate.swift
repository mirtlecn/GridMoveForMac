import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configurationCoordinator: ConfigurationRuntimeCoordinator
    private let menuActionBuilder = MenuActionBuilder()
    private let openURL: (URL) -> Bool
    private let userNotifier: UserNotifier
    private let injectedAccessibilityStatusProvider: (() -> Bool)?
    private let injectedAccessibilityPromptRequester: (() -> Bool)?
    private let layoutEngine = LayoutEngine()
    private lazy var windowController = WindowController(layoutEngine: layoutEngine)
    private lazy var actionExecutor = LayoutActionExecutor(
        layoutEngine: layoutEngine,
        windowController: windowController,
        configurationProvider: { [weak self] in self?.configuration ?? .defaultValue },
        accessibilityAccessValidator: { [weak self] in
            self?.accessibilityCoordinator.evaluate(promptOnMissing: true) ?? false
        }
    )
    private let commandRelay = DistributedCommandRelay()
    private let overlayController = OverlayController()
    private lazy var accessibilityCoordinator = AccessibilityRuntimeCoordinator(
        statusProvider: { [weak self] in
            self?.currentAccessibilityStatus() ?? false
        },
        promptRequester: { [weak self] in
            self?.requestAccessibilityPrompt() ?? false
        },
        onStateDidUpdate: { [weak self] in
            self?.synchronizeRuntimeControllers()
        }
    )

    private lazy var dragGridController = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { [weak self] in self?.configuration ?? AppConfiguration.defaultValue },
        accessibilityTrustedProvider: { [weak self] in
            self?.accessibilityCoordinator.hasAccess ?? false
        },
        accessibilityAccessValidator: { [weak self] in
            self?.accessibilityCoordinator.evaluate(promptOnMissing: true) ?? false
        },
        onAccessibilityRevoked: { [weak self] in
            self?.accessibilityCoordinator.invalidateAndEvaluate(promptOnMissing: true)
        }
    )

    private lazy var shortcutController = ShortcutController(
        actionExecutor: actionExecutor,
        configurationProvider: { [weak self] in self?.configuration ?? AppConfiguration.defaultValue },
        accessibilityTrustedProvider: { [weak self] in
            self?.accessibilityCoordinator.hasAccess ?? false
        },
        onAccessibilityRevoked: { [weak self] in
            self?.accessibilityCoordinator.invalidateAndEvaluate(promptOnMissing: true)
        }
    )

    private(set) var configuration = AppConfiguration.defaultValue
    private var menuController: MenuBarController?

    init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) },
        currentMonitorMapProvider: @escaping () -> [String: String] = { MonitorDiscovery.currentMonitorMap() },
        accessibilityStatusProvider: (() -> Bool)? = nil,
        accessibilityPromptRequester: (() -> Bool)? = nil,
        notifyUser: @escaping (String, String) -> Void = { title, body in
            UserNotifier().notify(title: title, body: body)
        }
    ) {
        self.configurationCoordinator = ConfigurationRuntimeCoordinator(
            configurationStore: configurationStore,
            currentMonitorMapProvider: currentMonitorMapProvider
        )
        self.openURL = openURL
        self.injectedAccessibilityStatusProvider = accessibilityStatusProvider
        self.injectedAccessibilityPromptRequester = accessibilityPromptRequester
        self.userNotifier = UserNotifier(notifyHandler: notifyUser)
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

        _ = accessibilityCoordinator.evaluate(promptOnMissing: true)
        accessibilityCoordinator.startPollingIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragGridController.stop()
        shortcutController.stop()
        accessibilityCoordinator.stop()
        commandRelay.stopListening()
    }

    func evaluateAccessibilityState() {
        _ = accessibilityCoordinator.evaluate(promptOnMissing: true)
    }

    func reloadConfigurationFromDisk(notifyOnFallback: Bool = false) {
        do {
            let result = try configurationCoordinator.loadConfiguration()
            applyConfiguration(result.configuration)
            if result.didFallBackToDefault && notifyOnFallback {
                userNotifier.notify(
                    title: UICopy.configReloadFailedTitle,
                    body: UICopy.configReloadFailedBody
                )
            }
        } catch {
            AppLogger.shared.error("Failed to load configuration: \(error.localizedDescription)")
            applyConfiguration(.defaultValue)
            if notifyOnFallback {
                userNotifier.notify(
                    title: UICopy.configReloadFailedTitle,
                    body: UICopy.configReloadFailedBody
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
        let shouldListenForGlobalInput = accessibilityCoordinator.hasAccess && configuration.general.isEnabled
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
        menuActionBuilder.buildActionItems(configuration: configuration)
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
        openURL(configurationCoordinator.directoryURL)
    }

    @discardableResult
    private func updateConfiguration(_ mutate: (inout AppConfiguration) -> Void) -> Bool {
        do {
            let candidateConfiguration = try configurationCoordinator.saveUpdatedConfiguration(
                from: configuration,
                mutate: mutate
            )
            applyConfiguration(candidateConfiguration)
            return true
        } catch {
            AppLogger.shared.error("Failed to save configuration: \(error.localizedDescription)")
            menuController?.updateToggleStates(makeToggleSettingsState(configuration: configuration))
            menuController?.setEnabled(configuration.general.isEnabled)
            return false
        }
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
        accessibilityCoordinator.hasAccess && configuration.general.isEnabled
    }

    var isAccessibilityPollingActiveForTesting: Bool {
        accessibilityCoordinator.isPollingActive
    }

    var accessibilityPollingIntervalForTesting: TimeInterval? {
        accessibilityCoordinator.pollingInterval
    }

    func menuActionItemsForTesting() -> [MenuBarController.ActionItem] {
        makeMenuActionItems(configuration: configuration)
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

    private func currentAccessibilityStatus() -> Bool {
        injectedAccessibilityStatusProvider?() ?? windowController.isAccessibilityTrusted(prompt: false)
    }

    private func requestAccessibilityPrompt() -> Bool {
        injectedAccessibilityPromptRequester?() ?? windowController.isAccessibilityTrusted(prompt: true)
    }
}
