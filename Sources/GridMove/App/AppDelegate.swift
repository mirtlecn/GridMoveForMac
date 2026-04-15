import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configurationStore = ConfigurationStore()
    private let layoutEngine = LayoutEngine()
    private lazy var windowController = WindowController(layoutEngine: layoutEngine)
    private let overlayController = OverlayController()

    private lazy var dragGridController = DragGridController(
        layoutEngine: layoutEngine,
        windowController: windowController,
        overlayController: overlayController,
        configurationProvider: { [weak self] in self?.configuration ?? .defaultValue },
        accessibilityTrustedProvider: { [weak self] in
            self?.windowController.isAccessibilityTrusted(prompt: false) ?? false
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
            self?.windowController.isAccessibilityTrusted(prompt: false) ?? false
        },
        onAccessibilityRevoked: { [weak self] in
            self?.forceAccessibilityReevaluation()
        }
    )

    private var configuration = AppConfiguration.defaultValue
    private var menuController: MenuBarController?
    private var settingsController: SettingsWindowController?
    private var onboardingController: OnboardingWindowController?
    private var accessibilityPollingTimer: Timer?
    private var hasAccessibilityAccess: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadConfigurationFromDisk()
        configureMainMenu()

        menuController = MenuBarController(
            dragGridEnabled: true,
            onToggleDragGrid: { [weak self] isEnabled in
                self?.dragGridController.isEnabled = isEnabled
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
    }

    private func evaluateAccessibilityState() {
        let isTrusted = windowController.isAccessibilityTrusted(prompt: false)
        guard hasAccessibilityAccess != isTrusted else {
            return
        }

        hasAccessibilityAccess = isTrusted
        if isTrusted {
            onboardingController?.close()
            onboardingController = nil
            dragGridController.start()
            shortcutController.start()
        } else {
            dragGridController.stop()
            shortcutController.stop()
            showOnboardingIfNeeded()
        }
    }

    private func forceAccessibilityReevaluation() {
        hasAccessibilityAccess = nil
        evaluateAccessibilityState()
    }

    private func startAccessibilityPollingIfNeeded() {
        accessibilityPollingTimer?.invalidate()
        accessibilityPollingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
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
    }

    private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                configurationStore: configurationStore,
                configurationProvider: { [weak self] in self?.configuration ?? .defaultValue },
                onConfigurationSaved: { [weak self] configuration in
                    self?.configuration = configuration
                }
            )
        }

        settingsController?.show()
        NSApp.activate(ignoringOtherApps: true)
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

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Application")

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        applicationMenu.addItem(settingsItem)
        applicationMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit GridMove", action: #selector(quitApplication), keyEquivalent: "q")
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

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
