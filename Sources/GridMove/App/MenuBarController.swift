import AppKit

@MainActor
final class MenuBarController: NSObject {
    struct ActionItem: Equatable {
        let title: String
        let action: HotkeyAction
        let shortcut: KeyboardShortcut?
    }

    struct ToggleSettingsState: Equatable {
        let middleMouseDragEnabled: Bool
        let modifierLeftMouseDragEnabled: Bool
        let preferLayoutMode: Bool
    }

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let dragGridMenuItem = NSMenuItem(title: UICopy.enableMenuTitle, action: nil, keyEquivalent: "")
    private let enableSeparatorItem = NSMenuItem.separator()
    private let middleMouseDragMenuItem = NSMenuItem(title: UICopy.middleMouseDragMenuTitle, action: nil, keyEquivalent: "")
    private let modifierLeftMouseDragMenuItem = NSMenuItem(title: UICopy.modifierLeftMouseDragMenuTitle, action: nil, keyEquivalent: "")
    private let preferLayoutModeMenuItem = NSMenuItem(title: UICopy.preferLayoutModeMenuTitle, action: nil, keyEquivalent: "")
    private let settingsSectionSeparatorItem = NSMenuItem.separator()
    private let actionSectionSeparatorItem = NSMenuItem.separator()
    private let reloadConfigMenuItem = NSMenuItem(title: UICopy.reloadConfigMenuTitle, action: nil, keyEquivalent: "")
    private let customizeMenuItem = NSMenuItem(title: UICopy.customizeMenuTitle, action: nil, keyEquivalent: "")
    private var actionMenuItems: [NSMenuItem] = []
    private var actionItems: [ActionItem]

    private let onToggleDragGrid: (Bool) -> Void
    private let onToggleMiddleMouseDrag: (Bool) -> Void
    private let onToggleModifierLeftMouseDrag: (Bool) -> Void
    private let onTogglePreferLayoutMode: (Bool) -> Void
    private let onPerformAction: (HotkeyAction) -> Void
    private let onReloadConfiguration: () -> Void
    private let onCustomize: () -> Void
    private let onQuit: () -> Void

    init(
        dragGridEnabled: Bool,
        toggleSettings: ToggleSettingsState,
        actionItems: [ActionItem],
        onToggleDragGrid: @escaping (Bool) -> Void,
        onToggleMiddleMouseDrag: @escaping (Bool) -> Void,
        onToggleModifierLeftMouseDrag: @escaping (Bool) -> Void,
        onTogglePreferLayoutMode: @escaping (Bool) -> Void,
        onPerformAction: @escaping (HotkeyAction) -> Void,
        onReloadConfiguration: @escaping () -> Void,
        onCustomize: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.actionItems = actionItems
        self.onToggleDragGrid = onToggleDragGrid
        self.onToggleMiddleMouseDrag = onToggleMiddleMouseDrag
        self.onToggleModifierLeftMouseDrag = onToggleModifierLeftMouseDrag
        self.onTogglePreferLayoutMode = onTogglePreferLayoutMode
        self.onPerformAction = onPerformAction
        self.onReloadConfiguration = onReloadConfiguration
        self.onCustomize = onCustomize
        self.onQuit = onQuit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem(dragGridEnabled: dragGridEnabled, toggleSettings: toggleSettings)
    }

    private func configureStatusItem(dragGridEnabled: Bool, toggleSettings: ToggleSettingsState) {
        statusItem.button?.title = ""
        statusItem.button?.image = MenuBarIcon.makeImage()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = UICopy.appName

        dragGridMenuItem.state = dragGridEnabled ? .on : .off
        dragGridMenuItem.target = self
        dragGridMenuItem.action = #selector(toggleDragGrid)
        menu.addItem(dragGridMenuItem)
        menu.addItem(enableSeparatorItem)

        configureToggleMenuItems(toggleSettings)
        menu.addItem(settingsSectionSeparatorItem)

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

    private func configureToggleMenuItems(_ toggleSettings: ToggleSettingsState) {
        middleMouseDragMenuItem.target = self
        middleMouseDragMenuItem.action = #selector(toggleMiddleMouseDrag)
        modifierLeftMouseDragMenuItem.target = self
        modifierLeftMouseDragMenuItem.action = #selector(toggleModifierLeftMouseDrag)
        preferLayoutModeMenuItem.target = self
        preferLayoutModeMenuItem.action = #selector(togglePreferLayoutMode)

        updateToggleStates(toggleSettings)

        menu.addItem(middleMouseDragMenuItem)
        menu.addItem(modifierLeftMouseDragMenuItem)
        menu.addItem(preferLayoutModeMenuItem)
    }

    func setEnabled(_ isEnabled: Bool) {
        dragGridMenuItem.state = isEnabled ? .on : .off
        actionMenuItems.forEach { $0.isEnabled = isEnabled }
    }

    func updateToggleStates(_ toggleSettings: ToggleSettingsState) {
        middleMouseDragMenuItem.state = toggleSettings.middleMouseDragEnabled ? .on : .off
        modifierLeftMouseDragMenuItem.state = toggleSettings.modifierLeftMouseDragEnabled ? .on : .off
        preferLayoutModeMenuItem.state = toggleSettings.preferLayoutMode ? .on : .off
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

        let insertIndex = menu.items.firstIndex(of: settingsSectionSeparatorItem).map { $0 + 1 } ?? menu.numberOfItems
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

    @objc private func toggleMiddleMouseDrag() {
        let nextState: NSControl.StateValue = middleMouseDragMenuItem.state == .on ? .off : .on
        middleMouseDragMenuItem.state = nextState
        onToggleMiddleMouseDrag(nextState == .on)
    }

    @objc private func toggleModifierLeftMouseDrag() {
        let nextState: NSControl.StateValue = modifierLeftMouseDragMenuItem.state == .on ? .off : .on
        modifierLeftMouseDragMenuItem.state = nextState
        onToggleModifierLeftMouseDrag(nextState == .on)
    }

    @objc private func togglePreferLayoutMode() {
        let nextState: NSControl.StateValue = preferLayoutModeMenuItem.state == .on ? .off : .on
        preferLayoutModeMenuItem.state = nextState
        onTogglePreferLayoutMode(nextState == .on)
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

    var toggleStateDescriptorsForTesting: [String: Bool] {
        [
            UICopy.middleMouseDragMenuTitle: middleMouseDragMenuItem.state == .on,
            UICopy.modifierLeftMouseDragMenuTitle: modifierLeftMouseDragMenuItem.state == .on,
            UICopy.preferLayoutModeMenuTitle: preferLayoutModeMenuItem.state == .on,
        ]
    }
}
