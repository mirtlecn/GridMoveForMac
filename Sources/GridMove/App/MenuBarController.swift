import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let dragGridMenuItem = NSMenuItem(title: "Enable", action: nil, keyEquivalent: "")

    private let onToggleDragGrid: (Bool) -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    init(
        dragGridEnabled: Bool,
        onToggleDragGrid: @escaping (Bool) -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onToggleDragGrid = onToggleDragGrid
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem(dragGridEnabled: dragGridEnabled)
    }

    private func configureStatusItem(dragGridEnabled: Bool) {
        statusItem.button?.title = ""
        statusItem.button?.image = MenuBarIcon.makeImage()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "GridMove"

        let menu = NSMenu()

        dragGridMenuItem.state = dragGridEnabled ? .on : .off
        dragGridMenuItem.target = self
        dragGridMenuItem.action = #selector(toggleDragGrid)
        menu.addItem(dragGridMenuItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleDragGrid() {
        let nextState: NSControl.StateValue = dragGridMenuItem.state == .on ? .off : .on
        dragGridMenuItem.state = nextState
        onToggleDragGrid(nextState == .on)
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        onQuit()
    }
}
