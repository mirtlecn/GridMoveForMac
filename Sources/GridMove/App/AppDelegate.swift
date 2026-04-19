import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    enum ConfigurationReloadMode {
        case launch
        case manual
    }

    private let configurationCoordinator: ConfigurationRuntimeCoordinator
    private let deferredConfigurationSaver: DeferredConfigurationSaver
    private let menuActionBuilder = MenuActionBuilder()
    private let openURL: (URL) -> Bool
    private let userNotifier: UserNotifier
    private let launchAtLoginService: any LaunchAtLoginServiceProtocol
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
            self?.handleAccessibilityStateDidUpdate()
        }
    )

    private lazy var dragGridController = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { [weak self] in self?.configuration ?? AppConfiguration.defaultValue },
        cycleActiveLayoutGroup: { [weak self] direction in
            self?.cycleLayoutGroup(direction: direction)
        },
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
    private var settingsWindowController: SettingsWindowController?
    private var settingsPrototypeState: SettingsPrototypeState?
    private var pendingDeferredConfigurationSaveTask: Task<Void, Never>?
    private var isLaunchAtLoginReconciliationPending = false

    init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) },
        currentMonitorMapProvider: @escaping () -> [String: String] = { MonitorDiscovery.currentMonitorMap() },
        launchAtLoginService: any LaunchAtLoginServiceProtocol = SMAppLaunchAtLoginService(),
        accessibilityStatusProvider: (() -> Bool)? = nil,
        accessibilityPromptRequester: (() -> Bool)? = nil,
        notifyUser: @escaping (UserNotifier.Kind, String, String) -> Void = { kind, title, body in
            UserNotifier().notify(kind: kind, title: title, body: body)
        }
    ) {
        self.configurationCoordinator = ConfigurationRuntimeCoordinator(
            configurationStore: configurationStore,
            currentMonitorMapProvider: currentMonitorMapProvider
        )
        self.deferredConfigurationSaver = DeferredConfigurationSaver(
            baseDirectoryURL: configurationStore.directoryURL
        )
        self.openURL = openURL
        self.launchAtLoginService = launchAtLoginService
        self.injectedAccessibilityStatusProvider = accessibilityStatusProvider
        self.injectedAccessibilityPromptRequester = accessibilityPromptRequester
        self.userNotifier = UserNotifier(notifyHandler: notifyUser)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        reloadConfigurationFromDisk(mode: .launch)
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
            onRequestAccessibilityAccess: { [weak self] in
                self?.requestAccessibilityAccessFromMenu()
            },
            onToggleDragGrid: { [weak self] isEnabled in
                self?.updateGlobalEnabledState(isEnabled) ?? false
            },
            onToggleMouseButtonDrag: { [weak self] isEnabled in
                self?.updateMouseButtonDragEnabled(isEnabled) ?? false
            },
            onToggleModifierLeftMouseDrag: { [weak self] isEnabled in
                self?.updateModifierLeftMouseDragEnabled(isEnabled) ?? false
            },
            onTogglePreferLayoutMode: { [weak self] isEnabled in
                self?.updatePreferLayoutMode(isEnabled) ?? false
            },
            onToggleLaunchAtLogin: { [weak self] isEnabled in
                self?.updateLaunchAtLoginEnabled(isEnabled) ?? false
            },
            onSelectLayoutGroup: { [weak self] groupName in
                self?.updateActiveLayoutGroup(groupName) ?? false
            },
            onPerformAction: { [weak self] action in
                self?.performMenuAction(action)
            },
            onOpenSettings: { [weak self] in
                self?.showSettings()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        menuController?.updateAccessibilityAccess(currentAccessibilityStatus())

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

    func requestAccessibilityAccessFromMenu() {
        accessibilityCoordinator.invalidateAndEvaluate(promptOnMissing: true)
        accessibilityCoordinator.startPollingIfNeeded()
    }

    @discardableResult
    func reloadConfigurationFromDisk(mode: ConfigurationReloadMode) -> AppConfiguration? {
        var didApplyConfiguration = false
        var appliedConfiguration: AppConfiguration?
        do {
            let result = try configurationCoordinator.loadConfiguration()
            switch mode {
            case .launch:
                applyConfiguration(result.configuration, syncOpenSettingsState: false)
                didApplyConfiguration = true
                appliedConfiguration = result.configuration
            case .manual:
                if result.source == .persistedConfiguration {
                    applyConfiguration(result.configuration, syncOpenSettingsState: false)
                    didApplyConfiguration = true
                    appliedConfiguration = result.configuration
                    if result.skippedLayoutDiagnostics.isEmpty {
                        userNotifier.notify(
                            kind: .configReloadSucceeded,
                            title: UICopy.configReloadSucceededTitle,
                            body: UICopy.configReloadSucceededBody()
                        )
                    } else {
                        userNotifier.notify(
                            kind: .configReloadSkippedLayouts,
                            title: UICopy.configReloadSkippedLayoutsTitle,
                            body: UICopy.configReloadSkippedLayoutsBody(diagnostics: result.skippedLayoutDiagnostics)
                        )
                    }
                } else {
                    userNotifier.notify(
                        kind: .configReloadFailed,
                        title: UICopy.configReloadFailedTitle,
                        body: UICopy.configReloadFailedBody(
                            diagnostic: result.diagnostic,
                            skippedLayoutDiagnostics: result.skippedLayoutDiagnostics
                        )
                    )
                }
            }
        } catch {
            AppLogger.shared.error("Failed to load configuration: \(error.localizedDescription)")
            switch mode {
            case .launch:
                applyConfiguration(.defaultValue, syncOpenSettingsState: false)
                didApplyConfiguration = true
                appliedConfiguration = .defaultValue
            case .manual:
                userNotifier.notify(
                    kind: .configReloadFailed,
                    title: UICopy.configReloadFailedTitle,
                    body: UICopy.configReloadFailedBody(diagnostic: nil)
                )
            }
        }

        if didApplyConfiguration {
            scheduleLaunchAtLoginReconciliation()
        }

        return appliedConfiguration
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
    func updateMouseButtonDragEnabled(_ isEnabled: Bool) -> Bool {
        guard configuration.dragTriggers.enableMouseButtonDrag != isEnabled else {
            return true
        }

        return updateConfiguration { configuration in
            configuration.dragTriggers.enableMouseButtonDrag = isEnabled
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
    func updateLaunchAtLoginEnabled(_ isEnabled: Bool) -> Bool {
        guard configuration.general.launchAtLogin != isEnabled else {
            return true
        }

        if isEnabled, accessibilityCoordinator.evaluate(promptOnMissing: true) == false {
            return false
        }

        if isEnabled {
            return enableLaunchAtLoginFromMenu()
        }

        return disableLaunchAtLoginFromMenu()
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

    private func cycleLayoutGroup(direction: LayoutGroupCycleDirection) -> AppConfiguration? {
        let nextGroupName: String?
        switch direction {
        case .next:
            nextGroupName = configuration.nextLayoutGroupNameInCycle()
        case .previous:
            nextGroupName = configuration.previousLayoutGroupNameInCycle()
        }

        guard let nextGroupName else {
            return nil
        }

        var updatedConfiguration = configuration
        updatedConfiguration.general.activeLayoutGroup = nextGroupName
        applyConfiguration(updatedConfiguration)
        persistConfigurationAsync(updatedConfiguration)
        return updatedConfiguration
    }

    private func persistConfigurationAsync(_ configuration: AppConfiguration) {
        // Layout-mode Shift cycling runs inside the event-tap path, so persistence must stay off that hot path.
        pendingDeferredConfigurationSaveTask = Task {
            await deferredConfigurationSaver.persist(configuration)
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

    private func handleAccessibilityStateDidUpdate() {
        synchronizeRuntimeControllers()
        menuController?.updateAccessibilityAccess(accessibilityCoordinator.hasAccess)
        processPendingLaunchAtLoginReconciliationIfNeeded()
    }

    private func scheduleLaunchAtLoginReconciliation() {
        isLaunchAtLoginReconciliationPending = true
        processPendingLaunchAtLoginReconciliationIfNeeded()
    }

    private func processPendingLaunchAtLoginReconciliationIfNeeded() {
        guard isLaunchAtLoginReconciliationPending, accessibilityCoordinator.hasAccess else {
            return
        }

        isLaunchAtLoginReconciliationPending = false
        synchronizeLaunchAtLoginWithConfiguration()
    }

    private func synchronizeLaunchAtLoginWithConfiguration() {
        if configuration.general.launchAtLogin {
            synchronizeEnabledLaunchAtLogin()
        } else {
            synchronizeDisabledLaunchAtLogin()
        }
    }

    private func synchronizeEnabledLaunchAtLogin() {
        let currentStatus = launchAtLoginService.status()
        guard currentStatus != .enabled else {
            return
        }

        do {
            let resultingStatus = try launchAtLoginService.register()
            guard resultingStatus == .enabled else {
                handleLaunchAtLoginEnableFailure(
                    details: launchAtLoginFailureDetails(for: resultingStatus, enabling: true),
                    shouldRollbackConfiguration: true
                )
                return
            }
        } catch {
            handleLaunchAtLoginEnableFailure(
                details: error.localizedDescription,
                shouldRollbackConfiguration: true
            )
        }
    }

    private func synchronizeDisabledLaunchAtLogin() {
        let currentStatus = launchAtLoginService.status()
        guard currentStatus != .disabled else {
            return
        }

        do {
            let resultingStatus = try launchAtLoginService.unregister()
            guard resultingStatus == .disabled else {
                handleLaunchAtLoginDisableFailure(
                    details: launchAtLoginFailureDetails(for: resultingStatus, enabling: false)
                )
                return
            }
        } catch {
            handleLaunchAtLoginDisableFailure(details: error.localizedDescription)
        }
    }

    private func updateLaunchAtLoginServiceState(to isEnabled: Bool) -> Bool {
        if isEnabled, accessibilityCoordinator.evaluate(promptOnMissing: true) == false {
            return false
        }

        if isEnabled {
            do {
                let resultingStatus = try launchAtLoginService.register()
                guard resultingStatus == .enabled else {
                    handleLaunchAtLoginEnableFailure(
                        details: launchAtLoginFailureDetails(for: resultingStatus, enabling: true),
                        shouldRollbackConfiguration: false
                    )
                    return false
                }
                return true
            } catch {
                handleLaunchAtLoginEnableFailure(details: error.localizedDescription, shouldRollbackConfiguration: false)
                return false
            }
        }

        do {
            let resultingStatus = try launchAtLoginService.unregister()
            guard resultingStatus == .disabled else {
                handleLaunchAtLoginDisableFailure(
                    details: launchAtLoginFailureDetails(for: resultingStatus, enabling: false)
                )
                return false
            }
            return true
        } catch {
            handleLaunchAtLoginDisableFailure(details: error.localizedDescription)
            return false
        }
    }

    private func rollbackLaunchAtLoginServiceState(to isEnabled: Bool) {
        do {
            if isEnabled {
                _ = try launchAtLoginService.register()
            } else {
                _ = try launchAtLoginService.unregister()
            }
        } catch {
            AppLogger.shared.error("Failed to roll back launch at login state: \(error.localizedDescription)")
        }
    }

    private func enableLaunchAtLoginFromMenu() -> Bool {
        do {
            let resultingStatus = try launchAtLoginService.register()
            guard resultingStatus == .enabled else {
                handleLaunchAtLoginEnableFailure(
                    details: launchAtLoginFailureDetails(for: resultingStatus, enabling: true),
                    shouldRollbackConfiguration: false
                )
                return false
            }
        } catch {
            handleLaunchAtLoginEnableFailure(details: error.localizedDescription, shouldRollbackConfiguration: false)
            return false
        }

        return updateConfiguration { configuration in
            configuration.general.launchAtLogin = true
        }
    }

    private func disableLaunchAtLoginFromMenu() -> Bool {
        do {
            let resultingStatus = try launchAtLoginService.unregister()
            guard resultingStatus == .disabled else {
                handleLaunchAtLoginDisableFailure(
                    details: launchAtLoginFailureDetails(for: resultingStatus, enabling: false)
                )
                return false
            }
        } catch {
            handleLaunchAtLoginDisableFailure(details: error.localizedDescription)
            return false
        }

        return updateConfiguration { configuration in
            configuration.general.launchAtLogin = false
        }
    }

    private func handleLaunchAtLoginEnableFailure(details: String?, shouldRollbackConfiguration: Bool) {
        if shouldRollbackConfiguration {
            _ = updateConfiguration { configuration in
                configuration.general.launchAtLogin = false
            }
        }

        userNotifier.notify(
            kind: .launchAtLoginEnableFailed,
            title: UICopy.launchAtLoginEnableFailedTitle,
            body: UICopy.launchAtLoginEnableFailedBody(details: details)
        )
    }

    private func handleLaunchAtLoginDisableFailure(details: String?) {
        userNotifier.notify(
            kind: .launchAtLoginDisableFailed,
            title: UICopy.launchAtLoginDisableFailedTitle,
            body: UICopy.launchAtLoginDisableFailedBody(details: details)
        )
    }

    private func launchAtLoginFailureDetails(for status: LaunchAtLoginStatus, enabling: Bool) -> String? {
        switch (status, enabling) {
        case (.requiresApproval, true):
            return "System approval is still required."
        case (.disabled, true):
            return "The login item stayed disabled."
        case (.enabled, false):
            return "The login item stayed enabled."
        case (.requiresApproval, false):
            return "The login item still needs system approval."
        case (.enabled, true), (.disabled, false):
            return nil
        }
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

        let settingsItem = NSMenuItem(title: UICopy.settingsMenuTitle, action: #selector(showSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        applicationMenu.addItem(settingsItem)
        applicationMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: UICopy.quitAppMenuTitle, action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        applicationMenu.addItem(quitItem)

        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }

    @objc private func showSettingsFromMenu() {
        showSettings()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    @discardableResult
    func openConfigurationDirectory() -> Bool {
        openURL(configurationCoordinator.directoryURL)
    }

    func showSettings() {
        if let settingsWindowController {
            settingsWindowController.present()
            return
        }

        let prototypeState = SettingsPrototypeState(configuration: configuration)
        let controller = SettingsWindowController(
            prototypeState: prototypeState,
            actionHandler: makeSettingsActionHandler(),
            onWindowWillClose: { [weak self] in
                self?.settingsPrototypeState?.discardLayoutsDraft()
                self?.settingsWindowController = nil
                self?.settingsPrototypeState = nil
            }
        )
        settingsPrototypeState = prototypeState
        settingsWindowController = controller
        controller.present()
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

    private func makeSettingsActionHandler() -> SettingsActionHandler {
        SettingsActionHandler(
            applyImmediateConfigurationHandler: { [weak self] candidate in
                self?.applySettingsConfiguration(candidate) ?? false
            },
            saveLayoutsConfigurationHandler: { [weak self] candidate in
                self?.saveLayoutsConfiguration(candidate) ?? false
            },
            refreshMonitorMetadataHandler: { [weak self] in
                self?.refreshMonitorMetadataFromSettings()
            },
            reloadConfigurationHandler: { [weak self] in
                self?.reloadConfigurationFromDisk(mode: .manual)
            },
            restoreDefaultConfigurationHandler: { [weak self] in
                self?.restoreDefaultConfigurationFromSettings()
            },
            openConfigurationDirectoryHandler: { [weak self] in
                self?.openConfigurationDirectory() ?? false
            }
        )
    }

    @discardableResult
    private func applySettingsConfiguration(_ candidate: AppConfiguration) -> Bool {
        saveSettingsConfigurationCandidate(candidate)
    }

    @discardableResult
    private func saveLayoutsConfiguration(_ candidate: AppConfiguration) -> Bool {
        saveSettingsConfigurationCandidate(candidate, failureNotifier: .layoutsSaveFailed)
    }

    private func refreshMonitorMetadataFromSettings() -> AppConfiguration? {
        do {
            let refreshedConfiguration = try configurationCoordinator.refreshMonitorMetadata(from: configuration)
            applyConfiguration(refreshedConfiguration, syncOpenSettingsState: false)
            return refreshedConfiguration
        } catch {
            AppLogger.shared.error("Failed to refresh monitor metadata from settings window: \(error.localizedDescription)")
            return nil
        }
    }

    private func restoreDefaultConfigurationFromSettings() -> AppConfiguration? {
        let defaultConfiguration = AppConfiguration.defaultValue
        guard saveSettingsConfigurationCandidate(defaultConfiguration) else {
            return nil
        }
        return reloadConfigurationFromDisk(mode: .manual)
    }

    @discardableResult
    private func saveSettingsConfigurationCandidate(
        _ candidate: AppConfiguration,
        failureNotifier: UserNotifier.Kind? = nil
    ) -> Bool {
        let previousConfiguration = configuration
        let didChangeLaunchAtLogin = previousConfiguration.general.launchAtLogin != candidate.general.launchAtLogin

        if didChangeLaunchAtLogin,
           updateLaunchAtLoginServiceState(to: candidate.general.launchAtLogin) == false {
            return false
        }

        do {
            try configurationCoordinator.saveConfiguration(candidate)
        } catch {
            AppLogger.shared.error("Failed to save configuration from settings window: \(error.localizedDescription)")
            if let failureNotifier {
                userNotifier.notify(
                    kind: failureNotifier,
                    title: UICopy.layoutsSaveFailedTitle,
                    body: UICopy.layoutsSaveFailedBody(details: settingsSaveFailureDetails(for: error))
                )
            }
            if didChangeLaunchAtLogin {
                rollbackLaunchAtLoginServiceState(to: previousConfiguration.general.launchAtLogin)
            }
            menuController?.updateToggleStates(makeToggleSettingsState(configuration: configuration))
            menuController?.setEnabled(configuration.general.isEnabled)
            return false
        }

        applyConfiguration(candidate, syncOpenSettingsState: false)
        return true
    }

    private func settingsSaveFailureDetails(for error: Error) -> String {
        if let configurationError = error as? ConfigurationFileError {
            switch configurationError {
            case let .invalidLayoutReference(index):
                return "Layout reference \(index) is invalid."
            case let .missingActiveLayoutGroup(groupName):
                return "Active layout group '\(groupName)' does not exist."
            case .duplicateLayoutGroupName:
                return "Layout group names must be unique."
            case let .overlappingMonitorBindings(groupName):
                return "Layout group '\(groupName)' has overlapping monitor bindings."
            case .embeddedLayoutGroupsNotSupported:
                return "Embedded layout groups are not supported."
            }
        }

        return error.localizedDescription
    }

    private func applyConfiguration(_ configuration: AppConfiguration, syncOpenSettingsState: Bool = true) {
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
        if syncOpenSettingsState {
            settingsPrototypeState?.syncExternalConfiguration(configuration)
        }
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

    var visibleMenuItemDescriptorsForTesting: [String] {
        menuController?.menuItemDescriptorsForTesting ?? []
    }

    var mainMenuItemDescriptorsForTesting: [String] {
        NSApplication.shared.mainMenu?.items
            .compactMap(\.submenu)
            .flatMap(\.items)
            .map { $0.isSeparatorItem ? "|" : $0.title } ?? []
    }

    var mainMenuShortcutDescriptorsForTesting: [String: String] {
        Dictionary(
            uniqueKeysWithValues: NSApplication.shared.mainMenu?.items
                .compactMap(\.submenu)
                .flatMap(\.items)
                .filter { !$0.isSeparatorItem }
                .map { item in
                    let modifiers = item.keyEquivalentModifierMask
                    let modifierDisplay = [
                        modifiers.contains(.control) ? "⌃" : "",
                        modifiers.contains(.option) ? "⌥" : "",
                        modifiers.contains(.shift) ? "⇧" : "",
                        modifiers.contains(.command) ? "⌘" : "",
                    ].joined()
                    return (item.title, modifierDisplay + item.keyEquivalent.uppercased())
                } ?? []
        )
    }

    var mainMenuEnabledDescriptorsForTesting: [String: Bool] {
        Dictionary(
            uniqueKeysWithValues: NSApplication.shared.mainMenu?.items
                .compactMap(\.submenu)
                .flatMap(\.items)
                .filter { !$0.isSeparatorItem }
                .map { ($0.title, $0.isEnabled) } ?? []
        )
    }

    var isSettingsWindowOpenForTesting: Bool {
        settingsWindowController?.window?.isVisible == true
    }

    var settingsTabTitlesForTesting: [String] {
        guard let tabViewController = settingsWindowController?.window?.contentViewController as? NSTabViewController else {
            return []
        }

        return tabViewController.tabViewItems.map(\.label)
    }

    var settingsVisibleStringsForTesting: [String] {
        guard let rootView = settingsWindowController?.window?.contentViewController?.view else {
            return []
        }

        return collectVisibleStrings(in: rootView)
    }

    func closeSettingsWindowForTesting() {
        settingsWindowController?.close()
    }

    @discardableResult
    func performSettingsCloseShortcutForTesting(isKeyWindow: Bool = true) -> Bool {
        settingsWindowController?.handleCommandWForTesting(isKeyWindow: isKeyWindow) ?? false
    }

    @discardableResult
    func commitSettingsEditingFromBackgroundClickForTesting(clickedInsideEditableControl: Bool) -> Bool {
        settingsWindowController?.commitEditingForTesting(clickedInsideEditableControl: clickedInsideEditableControl) ?? false
    }

    func selectSettingsTabForTesting(index: Int) {
        guard let tabViewController = settingsWindowController?.window?.contentViewController as? NSTabViewController,
              index >= 0,
              index < tabViewController.tabViewItems.count else {
            return
        }

        tabViewController.selectedTabViewItemIndex = index
    }

    var generalSettingsEnabledStateForTesting: Bool? {
        guard let tabViewController = settingsWindowController?.window?.contentViewController as? NSTabViewController,
              tabViewController.tabViewItems.indices.contains(0),
              let generalController = tabViewController.tabViewItems[0].viewController as? GeneralSettingsViewController else {
            return nil
        }

        generalController.loadViewIfNeeded()
        return generalController.isEnabledForTesting
    }

    var generalExcludedWindowTitlesForTesting: [String]? {
        guard let tabViewController = settingsWindowController?.window?.contentViewController as? NSTabViewController,
              tabViewController.tabViewItems.indices.contains(0),
              let generalController = tabViewController.tabViewItems[0].viewController as? GeneralSettingsViewController else {
            return nil
        }

        generalController.loadViewIfNeeded()
        return generalController.excludedWindowTitlesForTesting
    }

    func setGeneralEnabledFromSettingsForTesting(_ isEnabled: Bool) {
        guard let tabViewController = settingsWindowController?.window?.contentViewController as? NSTabViewController,
              tabViewController.tabViewItems.indices.contains(0),
              let generalController = tabViewController.tabViewItems[0].viewController as? GeneralSettingsViewController else {
            return
        }

        generalController.loadViewIfNeeded()
        generalController.setEnabledForTesting(isEnabled)
    }

    func setGeneralActivationDelayRawWithoutCommitForTesting(_ value: String) {
        guard let tabViewController = settingsWindowController?.window?.contentViewController as? NSTabViewController,
              tabViewController.tabViewItems.indices.contains(0),
              let generalController = tabViewController.tabViewItems[0].viewController as? GeneralSettingsViewController else {
            return
        }

        generalController.loadViewIfNeeded()
        generalController.setRawActivationDelayMillisecondsWithoutCommitForTesting(value)
    }

    func reloadSettingsFromAboutTabForTesting() {
        guard let tabViewController = settingsWindowController?.window?.contentViewController as? NSTabViewController,
              tabViewController.tabViewItems.indices.contains(4),
              let aboutController = tabViewController.tabViewItems[4].viewController as? AboutSettingsViewController else {
            return
        }

        aboutController.reloadForTesting()
    }

    func restoreSettingsFromAboutTabForTesting() {
        guard let tabViewController = settingsWindowController?.window?.contentViewController as? NSTabViewController,
              tabViewController.tabViewItems.indices.contains(4),
              let aboutController = tabViewController.tabViewItems[4].viewController as? AboutSettingsViewController else {
            return
        }

        aboutController.restoreForTesting()
    }

    var layoutsSettingsActiveGroupNameForTesting: String? {
        layoutsSettingsControllerForTesting?.activeGroupNameForTesting
    }

    var layoutsDraftConfigurationForTesting: AppConfiguration? {
        layoutsSettingsControllerForTesting?.draftConfigurationForTesting
    }

    func setLayoutsGroupNameRawWithoutCommitForTesting(_ value: String) {
        layoutsSettingsControllerForTesting?.setSelectedGroupNameRawWithoutCommitForTesting(value)
    }

    func selectLayoutsGroupForTesting(named groupName: String) {
        layoutsSettingsControllerForTesting?.selectGroupForTesting(named: groupName)
    }

    func triggerLayoutsAddActionForTesting() {
        layoutsSettingsControllerForTesting?.addActionForTesting()
    }

    func saveLayoutsFromSettingsForTesting() {
        layoutsSettingsControllerForTesting?.saveLayoutsForTesting()
    }

    func mutateLayoutsDraftForTesting(_ mutate: (inout AppConfiguration) -> Void) {
        layoutsSettingsControllerForTesting?.mutateLayoutsDraftForTesting(mutate)
    }

    func selectLayoutsLayoutForTesting(id: String) {
        layoutsSettingsControllerForTesting?.selectLayoutForTesting(id: id)
    }

    var currentLayoutsGridSizeValuesForTesting: (columns: Int, rows: Int)? {
        layoutsSettingsControllerForTesting?.currentLayoutGridSizeValuesForTesting
    }

    func updateCurrentLayoutsGridSizeForTesting(columns: Int, rows: Int) {
        layoutsSettingsControllerForTesting?.updateCurrentLayoutGridSizeForTesting(columns: columns, rows: rows)
    }

    @discardableResult
    func updateGlobalEnabledStateForTesting(_ isEnabled: Bool) -> Bool {
        updateGlobalEnabledState(isEnabled)
    }

    var settingsContentSizeForTesting: NSSize? {
        settingsWindowController?.window?.contentLayoutRect.size
    }

    var settingsMinimumSizeForTesting: NSSize? {
        settingsWindowController?.window?.minSize
    }

    var settingsUsesTextEditingFocusForTesting: Bool {
        settingsWindowController?.window?.firstResponder is NSTextView
    }

    func recordLayoutIDForTesting(_ layoutID: String, windowIdentity: String) {
        layoutEngine.recordLayoutID(layoutID, for: windowIdentity)
    }

    func nextLayoutIDForTesting(windowIdentity: String) -> String? {
        layoutEngine.nextLayoutID(for: windowIdentity, layouts: configuration.layouts)
    }

    func cycleToNextLayoutGroupForTesting() -> AppConfiguration? {
        cycleLayoutGroup(direction: .next)
    }

    func waitForDeferredConfigurationSaveForTesting() async {
        await pendingDeferredConfigurationSaveTask?.value
        await deferredConfigurationSaver.waitForPendingSaves()
    }

    private func makeLayoutGroupState(configuration: AppConfiguration) -> MenuBarController.LayoutGroupState {
        MenuBarController.LayoutGroupState(
            groupNames: configuration.layoutGroupNames(),
            activeGroupName: configuration.general.activeLayoutGroup
        )
    }

    private func makeToggleSettingsState(configuration: AppConfiguration) -> MenuBarController.ToggleSettingsState {
        MenuBarController.ToggleSettingsState(
            mouseButtonNumber: configuration.general.mouseButtonNumber,
            mouseButtonDragEnabled: configuration.dragTriggers.enableMouseButtonDrag,
            modifierLeftMouseDragEnabled: configuration.dragTriggers.enableModifierLeftMouseDrag,
            preferLayoutMode: configuration.dragTriggers.preferLayoutMode,
            launchAtLogin: configuration.general.launchAtLogin
        )
    }

    private func currentAccessibilityStatus() -> Bool {
        injectedAccessibilityStatusProvider?() ?? windowController.isAccessibilityTrusted(prompt: false)
    }

    private func requestAccessibilityPrompt() -> Bool {
        injectedAccessibilityPromptRequester?() ?? windowController.isAccessibilityTrusted(prompt: true)
    }

    private func collectVisibleStrings(in view: NSView) -> [String] {
        var strings: [String] = []

        if let textField = view as? NSTextField {
            let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                strings.append(value)
            }
        }

        if let button = view as? NSButton {
            let title = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                strings.append(title)
            }
        }

        if let segmentedControl = view as? NSSegmentedControl {
            for index in 0..<segmentedControl.segmentCount {
                if let label = segmentedControl.label(forSegment: index) {
                    let title = label.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        strings.append(title)
                    }
                }
            }
        }

        if let box = view as? NSBox, let contentView = box.contentView {
            strings.append(contentsOf: collectVisibleStrings(in: contentView))
        }

        if let scrollView = view as? NSScrollView, let documentView = scrollView.documentView {
            strings.append(contentsOf: collectVisibleStrings(in: documentView))
        }

        for subview in view.subviews {
            strings.append(contentsOf: collectVisibleStrings(in: subview))
        }

        return strings
    }

    private var layoutsSettingsControllerForTesting: LayoutsSettingsViewController? {
        guard let tabViewController = settingsWindowController?.window?.contentViewController as? NSTabViewController,
              tabViewController.tabViewItems.indices.contains(1),
              let layoutsController = tabViewController.tabViewItems[1].viewController as? LayoutsSettingsViewController else {
            return nil
        }

        layoutsController.loadViewIfNeeded()
        return layoutsController
    }
}
