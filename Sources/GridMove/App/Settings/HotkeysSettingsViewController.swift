import AppKit

@MainActor
final class HotkeysSettingsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let prototypeState: SettingsPrototypeState
    private let slotTableView = makeSettingsTableView()
    private let addButton = NSButton(title: UICopy.settingsHotkeysAddButtonTitle, target: nil, action: nil)
    private let clearButton = NSButton(title: UICopy.settingsClearButtonTitle, target: nil, action: nil)
    private var selectedSlotIndex = 0

    init(prototypeState: SettingsPrototypeState) {
        self.prototypeState = prototypeState
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

        slotTableView.reloadData()
        selectSlot(at: 0)
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
        let sheetContentView = HotkeyAddSheetContentView(
            actions: slots.map(\.actionDescriptor),
            selectedActionID: selectedSlot.actionDescriptor.id
        )
        let sheetController = SettingsPrototypeSheetController(
            title: UICopy.settingsAddHotkeySheetTitle,
            message: UICopy.settingsAddHotkeySheetMessage,
            bodyView: sheetContentView,
            confirmButtonTitle: UICopy.settingsAddButtonTitle
        ) { [weak self] in
            guard let shortcut = sheetContentView.recordedShortcut else {
                return
            }
            self?.applyAddedShortcut(
                actionID: sheetContentView.selectedActionID,
                shortcut: shortcut
            )
        }
        presentAsSheet(sheetController)
    }

    @objc
    private func handleClearShortcuts(_ sender: NSButton) {
        guard slots.indices.contains(selectedSlotIndex) else {
            return
        }

        let selectedAction = slots[selectedSlotIndex].action
        prototypeState.configuration.hotkeys.bindings.removeAll { $0.action == selectedAction }
        slotTableView.reloadData()
        selectSlot(at: selectedSlotIndex)
    }

    private func applyAddedShortcut(actionID: String, shortcut: KeyboardShortcut) {
        guard let slot = slots.first(where: { $0.actionDescriptor.id == actionID }),
              let index = slots.firstIndex(where: { $0.actionDescriptor.id == actionID }) else {
            return
        }

        // TODO: When real model wiring starts, replace this direct append with a
        // proper binding editor flow that preserves ordering, enabled state, and
        // conflict diagnostics across the shared settings draft.
        prototypeState.configuration.hotkeys.bindings.append(
            ShortcutBinding(shortcut: shortcut, action: slot.action)
        )
        slotTableView.reloadData()
        selectSlot(at: index)
    }
}

struct HotkeyPrototypeAction {
    let id: String
    let displayTitle: String
    let action: HotkeyAction
}

private struct HotkeyPrototypeSlot {
    let title: String
    let currentTarget: String
    let action: HotkeyAction
    var bindings: [String]

    var bindingSummary: String {
        bindings.isEmpty ? UICopy.settingsNoShortcutsValue : bindings.joined(separator: ", ")
    }

    var actionDescriptor: HotkeyPrototypeAction {
        HotkeyPrototypeAction(
            id: action.prototypeIdentifier,
            displayTitle: "\(title) - \(currentTarget)",
            action: action
        )
    }

    static func makePrototypeSlots(configuration: AppConfiguration = .defaultValue) -> [HotkeyPrototypeSlot] {
        let indexedLayouts = configuration.layouts.filter(\.includeInLayoutIndex)
        let globalSlots: [(title: String, target: String, action: HotkeyAction)] = [
            (UICopy.applyPreviousLayout, UICopy.settingsHotkeysPreviousTargetValue, .cyclePrevious),
            (UICopy.applyNextLayout, UICopy.settingsHotkeysNextTargetValue, .cycleNext),
        ]

        let layoutSlots: [(title: String, target: String, action: HotkeyAction)] = indexedLayouts
            .enumerated()
            .map { index, layout in
                (
                    UICopy.settingsLayoutSlotTitle(index + 1),
                    layout.name,
                    .applyLayoutByIndex(layout: index + 1)
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
