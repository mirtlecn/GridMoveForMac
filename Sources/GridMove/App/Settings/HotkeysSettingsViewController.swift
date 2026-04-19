import AppKit

@MainActor
final class HotkeysSettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let prototypeState: SettingsPrototypeState
    private let actionHandler: any SettingsActionHandling
    private let slotTableView = makeSettingsTableView()
    private let addButton = NSButton(title: UICopy.settingsHotkeysAddButtonTitle, target: nil, action: nil)
    private let clearButton = NSButton(title: UICopy.settingsClearButtonTitle, target: nil, action: nil)
    private var selectedSlotIndex = 0

    init(prototypeState: SettingsPrototypeState, actionHandler: any SettingsActionHandling) {
        self.prototypeState = prototypeState
        self.actionHandler = actionHandler
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        configureSlotTableView()

        let contentStackView = makeSettingsPageStackView()
        contentStackView.addArrangedSubview(
            makeSettingsTableScrollView(tableView: slotTableView, height: 500)
        )
        contentStackView.addArrangedSubview(makeShortcutButtonsRow())

        view = makeSettingsPageContainerView(contentView: contentStackView)
        title = UICopy.settingsHotkeysTabTitle

        observePrototypeState()
        reloadSlots(preservingSelection: 0)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        slots.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let slot = slots[row]
        let text: String

        switch tableColumn?.identifier.rawValue {
        case "slot":
            text = slot.title
        case "target":
            text = slot.currentTarget
        case "shortcuts":
            text = slot.bindingSummary
        default:
            text = slot.title
        }

        return makeSettingsTableCellView(
            identifier: NSUserInterfaceItemIdentifier("HotkeySlotCell"),
            text: text
        )
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView,
              tableView == slotTableView else {
            return
        }

        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < slots.count else {
            return
        }

        selectSlot(at: selectedRow)
    }

    private var selectedSlot: HotkeyPrototypeSlot {
        slots[selectedSlotIndex]
    }

    private var slots: [HotkeyPrototypeSlot] {
        HotkeyPrototypeSlot.makePrototypeSlots(configuration: prototypeState.configuration)
    }

    private func configureSlotTableView() {
        let slotColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("slot"))
        slotColumn.title = UICopy.settingsSlotLabel
        slotColumn.width = 160

        let targetColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("target"))
        targetColumn.title = UICopy.settingsCurrentTargetLabel
        targetColumn.width = 230

        let shortcutsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("shortcuts"))
        shortcutsColumn.title = UICopy.settingsBindingsLabel
        shortcutsColumn.resizingMask = .autoresizingMask
        shortcutsColumn.width = 260

        slotTableView.headerView = NSTableHeaderView()
        slotTableView.addTableColumn(slotColumn)
        slotTableView.addTableColumn(targetColumn)
        slotTableView.addTableColumn(shortcutsColumn)
        slotTableView.dataSource = self
        slotTableView.delegate = self
        slotTableView.target = self
        slotTableView.doubleAction = #selector(handleSlotDoubleClick(_:))
    }

    private func makeShortcutButtonsRow() -> NSView {
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(handleAddShortcut(_:))

        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(handleClearShortcuts(_:))

        let row = makeHorizontalGroup(spacing: 8)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(addButton)
        row.addArrangedSubview(clearButton)
        return row
    }

    private func observePrototypeState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePrototypeStateDidChange(_:)),
            name: .settingsPrototypeStateDidChange,
            object: prototypeState
        )
    }

    private func reloadSlots(preservingSelection selectionIndex: Int) {
        slotTableView.reloadData()
        let boundedSelection = max(0, min(selectionIndex, max(0, slots.count - 1)))
        selectSlot(at: boundedSelection)
    }

    @objc
    private func handlePrototypeStateDidChange(_ notification: Notification) {
        reloadSlots(preservingSelection: selectedSlotIndex)
    }

    private func selectSlot(at index: Int) {
        guard slots.indices.contains(index) else {
            return
        }

        selectedSlotIndex = index
        if slotTableView.selectedRow != index {
            slotTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }

        clearButton.isEnabled = !selectedSlot.bindings.isEmpty
    }

    @objc
    private func handleAddShortcut(_ sender: NSButton) {
        presentAddShortcutSheet()
    }

    @objc
    private func handleSlotDoubleClick(_ sender: Any?) {
        let clickedRow = slotTableView.clickedRow
        if slots.indices.contains(clickedRow) {
            selectSlot(at: clickedRow)
        }

        presentAddShortcutSheet()
    }

    private func presentAddShortcutSheet() {
        let sheetContentView = HotkeyAddSheetContentView(
            actions: slots.map(\.actionDescriptor),
            selectedActionID: selectedSlot.actionDescriptor.id,
            initialShortcutsByActionID: shortcutsByActionID()
        )
        let sheetController = SettingsPrototypeSheetController(
            title: UICopy.settingsHotkeySheetTitle,
            message: UICopy.settingsHotkeySheetMessage,
            bodyView: sheetContentView,
            confirmButtonTitle: UICopy.settingsSaveButtonTitle
        ) { [weak self] in
            self?.applyShortcutEditorChanges(from: sheetContentView)
        }
        presentAsSheet(sheetController)
    }

    @objc
    private func handleClearShortcuts(_ sender: NSButton) {
        guard slots.indices.contains(selectedSlotIndex) else {
            return
        }

        let selectedAction = slots[selectedSlotIndex].action
        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.hotkeys.bindings.removeAll { $0.action == selectedAction }
        }
    }

    func applyAddedShortcut(actionID: String, shortcut: KeyboardShortcut) {
        guard let slot = slots.first(where: { $0.actionDescriptor.id == actionID }),
              let index = slots.firstIndex(where: { $0.actionDescriptor.id == actionID }) else {
            return
        }

        if prototypeState.applyImmediateMutation(using: actionHandler, { configuration in
            configuration.hotkeys.bindings.append(
                ShortcutBinding(shortcut: shortcut, action: slot.action)
            )
        }) {
            reloadSlots(preservingSelection: index)
        }
    }

    private func shortcutsByActionID() -> [String: [KeyboardShortcut]] {
        Dictionary(
            uniqueKeysWithValues: slots.map { slot in
                let shortcuts: [KeyboardShortcut] = prototypeState.configuration.hotkeys.bindings.compactMap { binding in
                    guard binding.isEnabled,
                          binding.action == slot.action,
                          let shortcut = binding.shortcut else {
                        return nil
                    }
                    return shortcut
                }
                return (slot.actionDescriptor.id, shortcuts)
            }
        )
    }

    private func applyShortcutEditorChanges(from sheetContentView: HotkeyAddSheetContentView) {
        let editedActionIDs = sheetContentView.editedActionIDs
        guard editedActionIDs.isEmpty == false else {
            return
        }

        let actionsByID = Dictionary(uniqueKeysWithValues: slots.map { ($0.actionDescriptor.id, $0.action) })
        let selectedActionID = sheetContentView.selectedActionID
        if prototypeState.applyImmediateMutation(using: actionHandler, { configuration in
            configuration.hotkeys.bindings.removeAll { binding in
                let actionID = binding.action.prototypeIdentifier
                guard editedActionIDs.contains(actionID) else {
                    return false
                }
                return binding.isEnabled && binding.shortcut != nil
            }

            for actionID in editedActionIDs {
                guard let action = actionsByID[actionID] else {
                    continue
                }

                let shortcuts = sheetContentView.draftShortcutsByActionID[actionID] ?? []
                configuration.hotkeys.bindings.append(
                    contentsOf: shortcuts.map { shortcut in
                        ShortcutBinding(shortcut: shortcut, action: action)
                    }
                )
            }
        }) {
            if let selectedIndex = slots.firstIndex(where: { $0.actionDescriptor.id == selectedActionID }) {
                reloadSlots(preservingSelection: selectedIndex)
            } else {
                reloadSlots(preservingSelection: selectedSlotIndex)
            }
        }
    }

    var supportsDoubleClickAddShortcutForTesting: Bool {
        slotTableView.target === self && slotTableView.doubleAction == #selector(handleSlotDoubleClick(_:))
    }

    func applyShortcutEditorChangesForTesting(_ sheetContentView: HotkeyAddSheetContentView) {
        applyShortcutEditorChanges(from: sheetContentView)
    }
}

struct HotkeyPrototypeAction {
    let id: String
    let displayTitle: String
    let action: HotkeyAction
}

struct HotkeyPrototypeSlot {
    let title: String
    let currentTarget: String
    let action: HotkeyAction
    var bindings: [String]

    var bindingSummary: String {
        bindings.joined(separator: ", ")
    }

    var actionDescriptor: HotkeyPrototypeAction {
        HotkeyPrototypeAction(
            id: action.prototypeIdentifier,
            displayTitle: currentTarget.isEmpty ? title : "\(title): \(currentTarget)",
            action: action
        )
    }

    static func makePrototypeSlots(configuration: AppConfiguration = .defaultValue) -> [HotkeyPrototypeSlot] {
        let activeIndexedLayouts = LayoutGroupResolver.indexedActiveEntries(in: configuration).map(\.layout)
        let maximumIndexedLayoutCount = configuration.layoutGroups
            .map { group in
                LayoutGroupResolver.flattenedEntries(in: group)
                    .filter { $0.layout.includeInLayoutIndex }
                    .count
            }
            .max() ?? 0
        let globalSlots: [(title: String, target: String, action: HotkeyAction)] = [
            (UICopy.applyPreviousLayout, UICopy.settingsHotkeysPreviousTargetValue, .cyclePrevious),
            (UICopy.applyNextLayout, UICopy.settingsHotkeysNextTargetValue, .cycleNext),
        ]

        let layoutIndices = maximumIndexedLayoutCount > 0 ? Array(1...maximumIndexedLayoutCount) : []
        let layoutSlots: [(title: String, target: String, action: HotkeyAction)] = layoutIndices
            .map { layoutIndex in
                let targetName = activeIndexedLayouts[safe: layoutIndex - 1]
                    .map {
                        UICopy.layoutMenuName(
                            name: $0.name,
                            fallbackIdentifier: UICopy.settingsApplyLayoutSlotTitle(layoutIndex)
                        )
                    }
                    ?? ""

                return (
                    UICopy.settingsApplyLayoutSlotTitle(layoutIndex),
                    targetName,
                    HotkeyAction.applyLayoutByIndex(layout: layoutIndex)
                )
            }

        return (globalSlots + layoutSlots).map { slot in
            let bindings: [String] = configuration.hotkeys.bindings.compactMap { binding in
                guard binding.isEnabled, binding.action == slot.action, let shortcut = binding.shortcut else {
                    return nil
                }

                return shortcut.prototypeDisplayName
            }

            return HotkeyPrototypeSlot(
                title: slot.title,
                currentTarget: slot.target,
                action: slot.action,
                bindings: bindings
            )
        }
    }
}

extension HotkeyAction {
    var prototypeIdentifier: String {
        switch self {
        case let .applyLayoutByIndex(layout):
            return "applyLayoutByIndex:\(layout)"
        case let .applyLayoutByName(name):
            return "applyLayoutByName:\(name)"
        case let .applyLayoutByID(layoutID):
            return "applyLayoutByID:\(layoutID)"
        case .cycleNext:
            return "cycleNext"
        case .cyclePrevious:
            return "cyclePrevious"
        }
    }
}

extension KeyboardShortcut {
    var prototypeDisplayName: String {
        prototypeModifierSymbols + prototypeKeyDisplayName
    }

    private var prototypeModifierSymbols: String {
        let displayOrder: [ModifierKey] = [.ctrl, .alt, .shift, .cmd]
        return displayOrder
            .filter { modifiers.contains($0) }
            .map(\.symbol)
            .joined()
    }

    var prototypeKeyDisplayName: String {
        switch key.lowercased() {
        case "return", "enter":
            return "↩"
        case "escape", "esc":
            return "⎋"
        case "delete":
            return "⌫"
        case "tab":
            return "⇥"
        case "space":
            return "Space"
        default:
            return key.uppercased()
        }
    }
}

extension ModifierKey {
    var symbol: String {
        switch self {
        case .ctrl:
            return "⌃"
        case .cmd:
            return "⌘"
        case .shift:
            return "⇧"
        case .alt:
            return "⌥"
        }
    }

    static func from(_ flags: NSEvent.ModifierFlags) -> [ModifierKey] {
        var result: [ModifierKey] = []
        if flags.contains(.control) { result.append(.ctrl) }
        if flags.contains(.option) { result.append(.alt) }
        if flags.contains(.shift) { result.append(.shift) }
        if flags.contains(.command) { result.append(.cmd) }
        return result
    }
}

extension HotkeysSettingsViewController {
    func selectSlotForTesting(_ index: Int) {
        selectSlot(at: index)
    }

    func clearSelectedSlotForTesting() {
        handleClearShortcuts(clearButton)
    }

    var bindingsForSelectedSlotForTesting: [String] {
        selectedSlot.bindings
    }
}
