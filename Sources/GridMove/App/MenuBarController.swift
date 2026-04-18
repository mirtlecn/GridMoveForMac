import AppKit

@MainActor
final class MenuBarController: NSObject {
    struct ActionItem: Equatable {
        let title: String
        let action: HotkeyAction
        let shortcut: KeyboardShortcut?
    }

    struct LayoutGroupState: Equatable {
        let groupNames: [String]
        let activeGroupName: String
    }

    struct ToggleSettingsState: Equatable {
        let mouseButtonNumber: Int
        let mouseButtonDragEnabled: Bool
        let modifierLeftMouseDragEnabled: Bool
        let preferLayoutMode: Bool
        let launchAtLogin: Bool
    }

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let requestAccessibilityAccessMenuItem = NSMenuItem(title: UICopy.requestAccessibilityAccessMenuTitle, action: nil, keyEquivalent: "")
    private let dragGridMenuItem = NSMenuItem(title: UICopy.enableMenuTitle, action: nil, keyEquivalent: "")
    private let enableSeparatorItem = NSMenuItem.separator()
    private let mouseButtonDragMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let modifierLeftMouseDragMenuItem = NSMenuItem(title: UICopy.modifierLeftMouseDragMenuTitle, action: nil, keyEquivalent: "")
    private let preferLayoutModeMenuItem = NSMenuItem(title: UICopy.preferLayoutModeMenuTitle, action: nil, keyEquivalent: "")
    private let layoutGroupSectionSeparatorItem = NSMenuItem.separator()
    private let layoutGroupMenuItem = NSMenuItem(title: UICopy.layoutGroupMenuTitle, action: nil, keyEquivalent: "")
    private let layoutGroupSubmenu = NSMenu()
    private let settingsSectionSeparatorItem = NSMenuItem.separator()
    private let actionSectionSeparatorItem = NSMenuItem.separator()
    private let settingsMenuItem = NSMenuItem(title: UICopy.settingsMenuTitle, action: nil, keyEquivalent: ",")
    private let launchAtLoginMenuItem = NSMenuItem(title: UICopy.launchAtLoginMenuTitle, action: nil, keyEquivalent: "")
    private let quitSectionSeparatorItem = NSMenuItem.separator()
    private let quitMenuItem = NSMenuItem(title: UICopy.quitMenuTitle, action: nil, keyEquivalent: "q")
    private var actionMenuItems: [NSMenuItem] = []
    private var actionItems: [ActionItem]
    private var layoutGroupState: LayoutGroupState
    private var hasAccessibilityAccess = true

    private let onRequestAccessibilityAccess: () -> Void
    private let onToggleDragGrid: (Bool) -> Bool
    private let onToggleMouseButtonDrag: (Bool) -> Bool
    private let onToggleModifierLeftMouseDrag: (Bool) -> Bool
    private let onTogglePreferLayoutMode: (Bool) -> Bool
    private let onToggleLaunchAtLogin: (Bool) -> Bool
    private let onSelectLayoutGroup: (String) -> Bool
    private let onPerformAction: (HotkeyAction) -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    init(
        dragGridEnabled: Bool,
        toggleSettings: ToggleSettingsState,
        layoutGroupState: LayoutGroupState,
        actionItems: [ActionItem],
        onRequestAccessibilityAccess: @escaping () -> Void,
        onToggleDragGrid: @escaping (Bool) -> Bool,
        onToggleMouseButtonDrag: @escaping (Bool) -> Bool,
        onToggleModifierLeftMouseDrag: @escaping (Bool) -> Bool,
        onTogglePreferLayoutMode: @escaping (Bool) -> Bool,
        onToggleLaunchAtLogin: @escaping (Bool) -> Bool,
        onSelectLayoutGroup: @escaping (String) -> Bool,
        onPerformAction: @escaping (HotkeyAction) -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.actionItems = actionItems
        self.layoutGroupState = layoutGroupState
        self.onRequestAccessibilityAccess = onRequestAccessibilityAccess
        self.onToggleDragGrid = onToggleDragGrid
        self.onToggleMouseButtonDrag = onToggleMouseButtonDrag
        self.onToggleModifierLeftMouseDrag = onToggleModifierLeftMouseDrag
        self.onTogglePreferLayoutMode = onTogglePreferLayoutMode
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        self.onSelectLayoutGroup = onSelectLayoutGroup
        self.onPerformAction = onPerformAction
        self.onOpenSettings = onOpenSettings
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

        requestAccessibilityAccessMenuItem.target = self
        requestAccessibilityAccessMenuItem.action = #selector(requestAccessibilityAccess)
        menu.addItem(requestAccessibilityAccessMenuItem)

        dragGridMenuItem.state = dragGridEnabled ? .on : .off
        dragGridMenuItem.target = self
        dragGridMenuItem.action = #selector(toggleDragGrid)
        menu.addItem(dragGridMenuItem)
        menu.addItem(enableSeparatorItem)

        configureToggleMenuItems(toggleSettings)
        configureLayoutGroupMenu()
        menu.addItem(settingsSectionSeparatorItem)

        rebuildActionItems(isEnabled: dragGridEnabled)

        actionSectionSeparatorItem.isHidden = actionItems.isEmpty
        menu.addItem(actionSectionSeparatorItem)

        settingsMenuItem.target = self
        settingsMenuItem.action = #selector(openSettings)
        settingsMenuItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsMenuItem)

        launchAtLoginMenuItem.target = self
        launchAtLoginMenuItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(quitSectionSeparatorItem)

        quitMenuItem.target = self
        quitMenuItem.action = #selector(quit)
        quitMenuItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
        updateAccessibilityAccess(hasAccessibilityAccess)
    }

    @objc private func toggleDragGrid() {
        let nextState: NSControl.StateValue = dragGridMenuItem.state == .on ? .off : .on
        if onToggleDragGrid(nextState == .on) {
            dragGridMenuItem.state = nextState
        }
    }

    private func configureToggleMenuItems(_ toggleSettings: ToggleSettingsState) {
        mouseButtonDragMenuItem.target = self
        mouseButtonDragMenuItem.action = #selector(toggleMouseButtonDrag)
        modifierLeftMouseDragMenuItem.target = self
        modifierLeftMouseDragMenuItem.action = #selector(toggleModifierLeftMouseDrag)
        preferLayoutModeMenuItem.target = self
        preferLayoutModeMenuItem.action = #selector(togglePreferLayoutMode)

        updateToggleStates(toggleSettings)

        menu.addItem(mouseButtonDragMenuItem)
        menu.addItem(modifierLeftMouseDragMenuItem)
        menu.addItem(preferLayoutModeMenuItem)
    }

    private func configureLayoutGroupMenu() {
        menu.addItem(layoutGroupSectionSeparatorItem)
        layoutGroupMenuItem.submenu = layoutGroupSubmenu
        menu.addItem(layoutGroupMenuItem)
        rebuildLayoutGroupItems()
    }

    func setEnabled(_ isEnabled: Bool) {
        dragGridMenuItem.state = isEnabled ? .on : .off
        actionMenuItems.forEach { $0.isEnabled = isEnabled }
        layoutGroupSubmenu.items.forEach { $0.isEnabled = isEnabled }
    }

    func updateAccessibilityAccess(_ hasAccessibilityAccess: Bool) {
        self.hasAccessibilityAccess = hasAccessibilityAccess

        requestAccessibilityAccessMenuItem.isHidden = hasAccessibilityAccess
        dragGridMenuItem.isHidden = !hasAccessibilityAccess
        enableSeparatorItem.isHidden = !hasAccessibilityAccess
        mouseButtonDragMenuItem.isHidden = !hasAccessibilityAccess
        modifierLeftMouseDragMenuItem.isHidden = !hasAccessibilityAccess
        preferLayoutModeMenuItem.isHidden = !hasAccessibilityAccess
        layoutGroupSectionSeparatorItem.isHidden = !hasAccessibilityAccess
        layoutGroupMenuItem.isHidden = !hasAccessibilityAccess
        settingsSectionSeparatorItem.isHidden = !hasAccessibilityAccess
        actionSectionSeparatorItem.isHidden = !hasAccessibilityAccess || actionItems.isEmpty
        settingsMenuItem.isHidden = !hasAccessibilityAccess
        launchAtLoginMenuItem.isHidden = !hasAccessibilityAccess
        quitSectionSeparatorItem.isHidden = !hasAccessibilityAccess
        quitMenuItem.isHidden = !hasAccessibilityAccess
        actionMenuItems.forEach { $0.isHidden = !hasAccessibilityAccess }
    }

    func updateToggleStates(_ toggleSettings: ToggleSettingsState) {
        mouseButtonDragMenuItem.title = UICopy.mouseButtonDragMenuTitle(
            mouseButtonNumber: toggleSettings.mouseButtonNumber
        )
        mouseButtonDragMenuItem.state = toggleSettings.mouseButtonDragEnabled ? .on : .off
        modifierLeftMouseDragMenuItem.state = toggleSettings.modifierLeftMouseDragEnabled ? .on : .off
        preferLayoutModeMenuItem.state = toggleSettings.preferLayoutMode ? .on : .off
        launchAtLoginMenuItem.state = toggleSettings.launchAtLogin ? .on : .off
    }

    func updateActionItems(_ actionItems: [ActionItem], isEnabled: Bool) {
        self.actionItems = actionItems
        rebuildActionItems(isEnabled: isEnabled)
    }

    func updateLayoutGroupState(_ layoutGroupState: LayoutGroupState, isEnabled: Bool) {
        self.layoutGroupState = layoutGroupState
        rebuildLayoutGroupItems()
        layoutGroupSubmenu.items.forEach { $0.isEnabled = isEnabled }
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
            menuItem.isHidden = !hasAccessibilityAccess
            actionMenuItems.append(menuItem)
            nextIndex += 1
        }

        actionSectionSeparatorItem.isHidden = !hasAccessibilityAccess
    }

    private func rebuildLayoutGroupItems() {
        layoutGroupSubmenu.removeAllItems()

        for groupName in layoutGroupState.groupNames {
            let item = NSMenuItem(title: groupName, action: #selector(selectLayoutGroup(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = groupName
            item.state = groupName == layoutGroupState.activeGroupName ? .on : .off
            layoutGroupSubmenu.addItem(item)
        }
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func requestAccessibilityAccess() {
        onRequestAccessibilityAccess()
    }

    @objc private func toggleMouseButtonDrag() {
        let nextState: NSControl.StateValue = mouseButtonDragMenuItem.state == .on ? .off : .on
        if onToggleMouseButtonDrag(nextState == .on) {
            mouseButtonDragMenuItem.state = nextState
        }
    }

    @objc private func toggleModifierLeftMouseDrag() {
        let nextState: NSControl.StateValue = modifierLeftMouseDragMenuItem.state == .on ? .off : .on
        if onToggleModifierLeftMouseDrag(nextState == .on) {
            modifierLeftMouseDragMenuItem.state = nextState
        }
    }

    @objc private func togglePreferLayoutMode() {
        let nextState: NSControl.StateValue = preferLayoutModeMenuItem.state == .on ? .off : .on
        if onTogglePreferLayoutMode(nextState == .on) {
            preferLayoutModeMenuItem.state = nextState
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let nextState: NSControl.StateValue = launchAtLoginMenuItem.state == .on ? .off : .on
        if onToggleLaunchAtLogin(nextState == .on) {
            launchAtLoginMenuItem.state = nextState
        }
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? HotkeyAction else {
            return
        }
        onPerformAction(action)
    }

    @objc private func selectLayoutGroup(_ sender: NSMenuItem) {
        guard let groupName = sender.representedObject as? String else {
            return
        }

        if onSelectLayoutGroup(groupName) {
            layoutGroupState = LayoutGroupState(groupNames: layoutGroupState.groupNames, activeGroupName: groupName)
            rebuildLayoutGroupItems()
        }
    }

    @objc private func quit() {
        onQuit()
    }

    var menuItemDescriptorsForTesting: [String] {
        menu.items.filter { !$0.isHidden }.map { item in
            item.isSeparatorItem ? "|" : item.title
        }
    }

    var toggleStateDescriptorsForTesting: [String: Bool] {
        [
            mouseButtonDragMenuItem.title: mouseButtonDragMenuItem.state == .on,
            UICopy.modifierLeftMouseDragMenuTitle: modifierLeftMouseDragMenuItem.state == .on,
            UICopy.preferLayoutModeMenuTitle: preferLayoutModeMenuItem.state == .on,
            UICopy.launchAtLoginMenuTitle: launchAtLoginMenuItem.state == .on,
        ]
    }

    var layoutGroupDescriptorsForTesting: [String: Bool] {
        Dictionary(uniqueKeysWithValues: layoutGroupSubmenu.items.map { ($0.title, $0.state == .on) })
    }

    var shortcutDescriptorsForTesting: [String: String] {
        [
            settingsMenuItem.title: shortcutDescriptor(for: settingsMenuItem),
            quitMenuItem.title: shortcutDescriptor(for: quitMenuItem),
        ]
    }

    private func shortcutDescriptor(for item: NSMenuItem) -> String {
        let modifiers = item.keyEquivalentModifierMask
        let modifierDisplay = [
            modifiers.contains(.control) ? "⌃" : "",
            modifiers.contains(.option) ? "⌥" : "",
            modifiers.contains(.shift) ? "⇧" : "",
            modifiers.contains(.command) ? "⌘" : "",
        ].joined()
        return modifierDisplay + item.keyEquivalent.uppercased()
    }
}
