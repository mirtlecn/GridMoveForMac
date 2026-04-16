import AppKit

@MainActor
final class MenuBarController: NSObject {
    struct ActionItem: Equatable {
        let title: String
        let action: HotkeyAction
        let shortcut: KeyboardShortcut?

        var displayTitle: String {
            guard let shortcut else {
                return title
            }
            return "\(title) (\(shortcut.symbolDisplayString))"
        }
    }

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let dragGridMenuItem = NSMenuItem(title: "Enable", action: nil, keyEquivalent: "")
    private var actionMenuItems: [NSMenuItem] = []
    private var actionItems: [ActionItem]

    private let onToggleDragGrid: (Bool) -> Void
    private let onPerformAction: (HotkeyAction) -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    init(
        dragGridEnabled: Bool,
        actionItems: [ActionItem],
        onToggleDragGrid: @escaping (Bool) -> Void,
        onPerformAction: @escaping (HotkeyAction) -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.actionItems = actionItems
        self.onToggleDragGrid = onToggleDragGrid
        self.onPerformAction = onPerformAction
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

        dragGridMenuItem.state = dragGridEnabled ? .on : .off
        dragGridMenuItem.target = self
        dragGridMenuItem.action = #selector(toggleDragGrid)
        menu.addItem(dragGridMenuItem)

        rebuildActionItems(isEnabled: dragGridEnabled)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(.separator())
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

    func setEnabled(_ isEnabled: Bool) {
        dragGridMenuItem.state = isEnabled ? .on : .off
        actionMenuItems.forEach { $0.isEnabled = isEnabled }
    }

    func updateActionItems(_ actionItems: [ActionItem], isEnabled: Bool) {
        self.actionItems = actionItems
        rebuildActionItems(isEnabled: isEnabled)
    }

    private func rebuildActionItems(isEnabled: Bool) {
        actionMenuItems.forEach { menu.removeItem($0) }
        actionMenuItems.removeAll()

        guard !actionItems.isEmpty else {
            return
        }

        let insertIndex = menu.items.firstIndex(of: dragGridMenuItem).map { $0 + 1 } ?? menu.numberOfItems
        var nextIndex = insertIndex

        for item in actionItems {
            let menuItem = NSMenuItem(title: item.displayTitle, action: #selector(performAction(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item.action
            menuItem.isEnabled = isEnabled
            menu.insertItem(menuItem, at: nextIndex)
            actionMenuItems.append(menuItem)
            nextIndex += 1
        }

        let separator = NSMenuItem.separator()
        separator.isEnabled = false
        menu.insertItem(separator, at: nextIndex)
        actionMenuItems.append(separator)
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? HotkeyAction else {
            return
        }
        onPerformAction(action)
    }

    @objc private func quit() {
        onQuit()
    }
}
