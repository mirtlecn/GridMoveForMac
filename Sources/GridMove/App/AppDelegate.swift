import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configurationStore = ConfigurationStore()
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
        configurationProvider: { [weak self] in self?.configuration ?? .defaultValue },
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
        configurationProvider: { [weak self] in self?.configuration ?? .defaultValue },
        accessibilityTrustedProvider: { [weak self] in
            self?.accessibilityMonitor.hasAccess ?? false
        },
        onAccessibilityRevoked: { [weak self] in
            self?.forceAccessibilityReevaluation()
        }
    )

    private var configuration = AppConfiguration.defaultValue
    private var menuController: MenuBarController?
    private var preferenceController: PreferenceWindowController?
    private var settingsController: SettingsWindowController?
    private var onboardingController: OnboardingWindowController?
    private var accessibilityPollingTimer: Timer?

    var preferenceWindowControllerForTesting: PreferenceWindowController? {
        preferenceController
    }

    var settingsWindowControllerForTesting: SettingsWindowController? {
        settingsController
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadConfigurationFromDisk()
        configureMainMenu()
        commandRelay.startListening { [weak self] command in
            MainActor.assumeIsolated {
                self?.handleRemoteCommand(command) ?? RemoteCommandReply(success: false, message: "GridMove is not available.")
            }
        }

        menuController = MenuBarController(
            dragGridEnabled: configuration.general.isEnabled,
            actionItems: makeMenuActionItems(configuration: configuration),
            onToggleDragGrid: { [weak self] isEnabled in
                self?.updateGlobalEnabledState(isEnabled)
            },
            onPerformAction: { [weak self] action in
                self?.performMenuAction(action)
            },
            onOpenPreference: { [weak self] in
                self?.showPreference()
            },
            onOpenSettings: { [weak self] in
                self?.showSettings()
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        handleApplicationReopen()
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

    private func loadConfigurationFromDisk() {
        do {
            configuration = try configurationStore.load()
        } catch {
            AppLogger.shared.error("Failed to load configuration: \(error.localizedDescription)")
            configuration = .defaultValue
        }
        menuController?.updateActionItems(makeMenuActionItems(configuration: configuration), isEnabled: configuration.general.isEnabled)
    }

    private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                configurationStore: configurationStore,
                configurationProvider: { [weak self] in self?.configuration ?? .defaultValue },
                onConfigurationSaved: { [weak self] configuration in
                    self?.configuration = configuration
                    self?.applyGlobalEnabledState()
                    self?.menuController?.updateActionItems(
                        self?.makeMenuActionItems(configuration: configuration) ?? [],
                        isEnabled: configuration.general.isEnabled
                    )
                    self?.settingsController?.updateConfiguration(configuration)
                },
                onClose: { [weak self] in
                    self?.settingsController = nil
                }
            )
        }

        settingsController?.updateConfiguration(configuration)
        settingsController?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    func showPreference() {
        if preferenceController == nil {
            preferenceController = PreferenceWindowController(
                onClose: { [weak self] in
                    self?.preferenceController = nil
                }
            )
        }

        preferenceController?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    func handleApplicationReopen() -> Bool {
        showSettings()
        return false
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
        settingsController?.updateConfiguration(configuration)
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

        let preferenceItem = NSMenuItem(title: UICopy.preferenceMenuTitle, action: #selector(openPreferenceFromMenu), keyEquivalent: "")
        preferenceItem.target = self
        applicationMenu.addItem(preferenceItem)

        let settingsItem = NSMenuItem(title: UICopy.settingsMenuTitle, action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(settingsItem)
        applicationMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: UICopy.quitAppMenuTitle, action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        applicationMenu.addItem(quitItem)

        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func openSettingsFromMenu() {
        showSettings()
    }

    @objc private func openPreferenceFromMenu() {
        showPreference()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
