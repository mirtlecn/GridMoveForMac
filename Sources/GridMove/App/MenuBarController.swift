import AppKit

@MainActor
final class MenuBarController: NSObject {
    struct ActionItem: Equatable {
        let title: String
        let action: HotkeyAction
        let shortcut: KeyboardShortcut?
    }

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let dragGridMenuItem = NSMenuItem(title: UICopy.enableMenuTitle, action: nil, keyEquivalent: "")
    private let enableSeparatorItem = NSMenuItem.separator()
    private let actionSectionSeparatorItem = NSMenuItem.separator()
    private let reloadConfigMenuItem = NSMenuItem(title: UICopy.reloadConfigMenuTitle, action: nil, keyEquivalent: "")
    private let customizeMenuItem = NSMenuItem(title: UICopy.customizeMenuTitle, action: nil, keyEquivalent: "")
    private var actionMenuItems: [NSMenuItem] = []
    private var actionItems: [ActionItem]

    private let onToggleDragGrid: (Bool) -> Void
    private let onPerformAction: (HotkeyAction) -> Void
    private let onReloadConfiguration: () -> Void
    private let onCustomize: () -> Void
    private let onQuit: () -> Void

    init(
        dragGridEnabled: Bool,
        actionItems: [ActionItem],
        onToggleDragGrid: @escaping (Bool) -> Void,
        onPerformAction: @escaping (HotkeyAction) -> Void,
        onReloadConfiguration: @escaping () -> Void,
        onCustomize: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.actionItems = actionItems
        self.onToggleDragGrid = onToggleDragGrid
        self.onPerformAction = onPerformAction
        self.onReloadConfiguration = onReloadConfiguration
        self.onCustomize = onCustomize
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem(dragGridEnabled: dragGridEnabled)
    }

    private func configureStatusItem(dragGridEnabled: Bool) {
        statusItem.button?.title = ""
        statusItem.button?.image = MenuBarIcon.makeImage()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = UICopy.appName

        dragGridMenuItem.state = dragGridEnabled ? .on : .off
        dragGridMenuItem.target = self
        dragGridMenuItem.action = #selector(toggleDragGrid)
        menu.addItem(dragGridMenuItem)
        menu.addItem(enableSeparatorItem)

        rebuildActionItems(isEnabled: dragGridEnabled)

        actionSectionSeparatorItem.isHidden = actionItems.isEmpty
        menu.addItem(actionSectionSeparatorItem)

        reloadConfigMenuItem.target = self
        reloadConfigMenuItem.action = #selector(reloadConfiguration)
        menu.addItem(reloadConfigMenuItem)

        customizeMenuItem.target = self
        customizeMenuItem.action = #selector(customize)
        menu.addItem(customizeMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: UICopy.quitMenuTitle, action: #selector(quit), keyEquivalent: "")
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
            actionSectionSeparatorItem.isHidden = true
            return
        }

        let insertIndex = menu.items.firstIndex(of: enableSeparatorItem).map { $0 + 1 } ?? menu.numberOfItems
        var nextIndex = insertIndex

        for item in actionItems {
            let menuItem = NSMenuItem(
                title: item.title,
                action: #selector(performAction(_:)),
                keyEquivalent: item.shortcut?.menuKeyEquivalent ?? ""
            )
            menuItem.target = self
            menuItem.representedObject = item.action
            menuItem.isEnabled = isEnabled
            menuItem.keyEquivalentModifierMask = item.shortcut?.menuModifierMask ?? []
            menu.insertItem(menuItem, at: nextIndex)
            actionMenuItems.append(menuItem)
            nextIndex += 1
        }

        actionSectionSeparatorItem.isHidden = false
    }

    @objc private func reloadConfiguration() {
        onReloadConfiguration()
    }

    @objc private func customize() {
        onCustomize()
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

    var menuItemDescriptorsForTesting: [String] {
        menu.items.map { item in
            item.isSeparatorItem ? "|" : item.title
        }
    }
}
