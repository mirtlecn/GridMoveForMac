import AppKit

@MainActor
final class ModifierGroupSheetContentView: NSView, SettingsPrototypeSheetValidating {
    private struct ModifierOption {
        let title: String
        let modifierKey: ModifierKey
    }

    private let options: [ModifierOption] = [
        ModifierOption(title: "Control", modifierKey: .ctrl),
        ModifierOption(title: "Shift", modifierKey: .shift),
        ModifierOption(title: "Option", modifierKey: .alt),
        ModifierOption(title: "Command", modifierKey: .cmd),
    ]
    private let checkboxes: [NSButton]
    var onConfirmationStateChanged: (() -> Void)?

    override init(frame frameRect: NSRect) {
        self.checkboxes = options.map { option in
            let checkbox = makeCheckboxRow(title: option.title, state: .off)
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            return checkbox
        }
        super.init(frame: frameRect)

        let rows = makeVerticalGroup(spacing: 10)
        rows.translatesAutoresizingMaskIntoConstraints = false
        checkboxes.forEach {
            $0.target = self
            $0.action = #selector(handleCheckboxChange(_:))
            rows.addArrangedSubview($0)
        }
        addSubview(rows)

        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor),
            rows.topAnchor.constraint(equalTo: topAnchor),
            rows.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    var isConfirmationEnabled: Bool {
        !selectedModifiers.isEmpty
    }

    var selectedModifiers: [ModifierKey] {
        let orderedModifiers = zip(options, checkboxes)
            .compactMap { option, checkbox in
                checkbox.state == .on ? option.modifierKey : nil
            }

        return ModifierKey.allCases.filter { orderedModifiers.contains($0) }
    }

    var selectedModifierDisplayName: String {
        selectedModifiers.map(\.displayName).joined(separator: " + ")
    }

    @objc
    private func handleCheckboxChange(_ sender: NSButton) {
        onConfirmationStateChanged?()
    }
}

@MainActor
final class ExclusionEntrySheetContentView: NSView, SettingsPrototypeSheetValidating, NSTextFieldDelegate {
    enum Kind: Int {
        case bundleID
        case windowTitle

        var displayTitle: String {
            switch self {
            case .bundleID:
                return UICopy.settingsExcludedBundleIDsLabel
            case .windowTitle:
                return UICopy.settingsExcludedWindowTitlesLabel
            }
        }

        var placeholderValue: String {
            switch self {
            case .bundleID:
                return "com.example.App"
            case .windowTitle:
                return "Floating Panel"
            }
        }
    }

    private let kindPopupButton = NSPopUpButton()
    private let valueField = NSTextField(string: "")
    var onConfirmationStateChanged: (() -> Void)?

    init(initialKind: Kind) {
        super.init(frame: .zero)

        kindPopupButton.addItems(withTitles: [
            Kind.bundleID.displayTitle,
            Kind.windowTitle.displayTitle,
        ])
        kindPopupButton.target = self
        kindPopupButton.action = #selector(handleKindChanged(_:))
        kindPopupButton.selectItem(at: initialKind.rawValue)
        kindPopupButton.translatesAutoresizingMaskIntoConstraints = false
        kindPopupButton.widthAnchor.constraint(equalToConstant: 320).isActive = true

        valueField.placeholderString = initialKind.placeholderValue
        valueField.delegate = self
        valueField.translatesAutoresizingMaskIntoConstraints = false
        valueField.widthAnchor.constraint(equalToConstant: 320).isActive = true

        let body = makeVerticalGroup(spacing: 14)
        body.translatesAutoresizingMaskIntoConstraints = false
        body.addArrangedSubview(makeSheetStackedControlSection(label: UICopy.settingsTypeLabel, control: kindPopupButton))
        body.addArrangedSubview(makeSheetStackedControlSection(label: UICopy.settingsValueLabel, control: valueField))
        addSubview(body)

        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.topAnchor.constraint(equalTo: topAnchor),
            body.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    var selectedKind: Kind {
        Kind(rawValue: kindPopupButton.indexOfSelectedItem) ?? .bundleID
    }

    var isConfirmationEnabled: Bool {
        resolvedValue.isEmpty == false
    }

    var resolvedValue: String {
        valueField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc
    private func handleKindChanged(_ sender: NSPopUpButton) {
        valueField.placeholderString = selectedKind.placeholderValue
        onConfirmationStateChanged?()
    }

    func controlTextDidChange(_ notification: Notification) {
        onConfirmationStateChanged?()
    }
}

extension ExclusionEntrySheetContentView {
    func setValueForTesting(_ value: String) {
        valueField.stringValue = value
        onConfirmationStateChanged?()
    }
}

@MainActor
final class HotkeyAddSheetContentView: NSView, SettingsPrototypeSheetValidating, SettingsPrototypeSheetDisposable {
    private let behaviorPopupButton = NSPopUpButton()
    private let recorderView = PrototypeShortcutRecorderView()
    private let shortcutsStackView = makeVerticalGroup(spacing: 8)
    private let actions: [HotkeyPrototypeAction]
    private var shortcutsByActionID: [String: [KeyboardShortcut]]
    private(set) var editedActionIDs = Set<String>()
    var onConfirmationStateChanged: (() -> Void)?

    init(
        actions: [HotkeyPrototypeAction],
        selectedActionID: String?,
        initialShortcutsByActionID: [String: [KeyboardShortcut]] = [:]
    ) {
        self.actions = actions
        self.shortcutsByActionID = Dictionary(
            uniqueKeysWithValues: actions.map { action in
                (action.id, initialShortcutsByActionID[action.id] ?? [])
            }
        )
        super.init(frame: .zero)

        behaviorPopupButton.addItems(withTitles: actions.map(\.displayTitle))
        if let selectedActionID,
           let selectedIndex = actions.firstIndex(where: { $0.id == selectedActionID }) {
            behaviorPopupButton.selectItem(at: selectedIndex)
        }
        behaviorPopupButton.target = self
        behaviorPopupButton.action = #selector(handleBehaviorChanged(_:))
        behaviorPopupButton.translatesAutoresizingMaskIntoConstraints = false
        behaviorPopupButton.widthAnchor.constraint(equalToConstant: 320).isActive = true

        let body = makeVerticalGroup(spacing: 14)
        body.translatesAutoresizingMaskIntoConstraints = false
        body.addArrangedSubview(makeSheetStackedControlSection(label: UICopy.settingsBehaviorLabel, control: behaviorPopupButton))
        body.addArrangedSubview(makeSheetStackedControlSection(label: UICopy.settingsShortcutsLabel, control: shortcutsStackView))
        addSubview(body)

        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.topAnchor.constraint(equalTo: topAnchor),
            body.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        recorderView.onShortcutRecorded = { [weak self] shortcut in
            self?.appendShortcut(shortcut)
        }
        rebuildShortcutRows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    var selectedActionID: String {
        let selectedIndex = behaviorPopupButton.indexOfSelectedItem
        guard actions.indices.contains(selectedIndex) else {
            return actions.first?.id ?? ""
        }
        return actions[selectedIndex].id
    }

    var isConfirmationEnabled: Bool {
        true
    }

    var draftShortcutsByActionID: [String: [KeyboardShortcut]] {
        shortcutsByActionID
    }

    func prepareForDismissal() {
        recorderView.prepareForDismissal()
    }

    @objc
    private func handleBehaviorChanged(_ sender: NSPopUpButton) {
        rebuildShortcutRows()
    }

    private var visibleShortcuts: [KeyboardShortcut] {
        shortcutsByActionID[selectedActionID] ?? []
    }

    private func rebuildShortcutRows() {
        shortcutsStackView.arrangedSubviews.forEach { view in
            shortcutsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        visibleShortcuts.enumerated().forEach { index, shortcut in
            shortcutsStackView.addArrangedSubview(makeShortcutRow(shortcut: shortcut, index: index))
        }
        shortcutsStackView.addArrangedSubview(makeRecordRow())
    }

    private func makeShortcutRow(shortcut: KeyboardShortcut, index: Int) -> NSView {
        let shortcutField = NSTextField(string: shortcut.prototypeDisplayName)
        shortcutField.isEditable = false
        shortcutField.isBezeled = true
        shortcutField.drawsBackground = true
        shortcutField.backgroundColor = .controlBackgroundColor
        shortcutField.translatesAutoresizingMaskIntoConstraints = false
        shortcutField.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let deleteButton = NSButton(title: UICopy.settingsDeleteButtonTitle, target: self, action: #selector(handleDeleteShortcut(_:)))
        deleteButton.bezelStyle = .rounded
        deleteButton.tag = index

        let row = makeHorizontalGroup(spacing: 8)
        row.alignment = .centerY
        row.addArrangedSubview(shortcutField)
        row.addArrangedSubview(deleteButton)
        row.addArrangedSubview(NSView())
        return row
    }

    private func makeRecordRow() -> NSView {
        let row = makeHorizontalGroup(spacing: 8)
        row.alignment = .centerY
        row.addArrangedSubview(recorderView)
        row.addArrangedSubview(NSView())
        return row
    }

    @objc
    private func handleDeleteShortcut(_ sender: NSButton) {
        guard visibleShortcuts.indices.contains(sender.tag) else {
            return
        }

        var shortcuts = visibleShortcuts
        shortcuts.remove(at: sender.tag)
        shortcutsByActionID[selectedActionID] = shortcuts
        editedActionIDs.insert(selectedActionID)
        rebuildShortcutRows()
        onConfirmationStateChanged?()
    }

    private func appendShortcut(_ shortcut: KeyboardShortcut) {
        var shortcuts = visibleShortcuts
        if shortcuts.contains(shortcut) == false {
            shortcuts.append(shortcut)
            shortcutsByActionID[selectedActionID] = shortcuts
            editedActionIDs.insert(selectedActionID)
            rebuildShortcutRows()
            onConfirmationStateChanged?()
        }
        recorderView.resetForNextRecording()
    }
}

@MainActor
private final class PrototypeShortcutRecorderView: NSView {
    private let recordButton = NSButton(title: UICopy.settingsRecordShortcutButtonTitle, target: nil, action: nil)
    private var eventMonitor: Any?
    var onShortcutRecorded: ((KeyboardShortcut) -> Void)?
    var onShortcutChanged: (() -> Void)?
    private var isRecording = false {
        didSet {
            updateButtonTitle()
        }
    }

    private(set) var recordedShortcut: KeyboardShortcut? {
        didSet {
            updateButtonTitle()
            onShortcutChanged?()
        }
    }

    private var recordedShortcutDisplayName: String? {
        recordedShortcut?.prototypeDisplayName
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(handleRecord(_:))
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true
        updateButtonTitle()

        addSubview(recordButton)

        NSLayoutConstraint.activate([
            recordButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            recordButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            recordButton.topAnchor.constraint(equalTo: topAnchor),
            recordButton.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    @objc
    private func handleRecord(_ sender: NSButton) {
        guard !isRecording else {
            stopRecording()
            return
        }

        recordedShortcut = nil
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            guard let key = ShortcutKeyMap.keyName(for: CGKeyCode(event.keyCode)) else {
                NSSound.beep()
                return nil
            }

            let shortcut = KeyboardShortcut(
                modifiers: ModifierKey.from(event.modifierFlags),
                key: key
            )
            self.recordedShortcut = shortcut
            self.stopRecording()
            self.onShortcutRecorded?(shortcut)
            return nil
        }
    }

    private func updateButtonTitle() {
        if isRecording {
            recordButton.title = UICopy.settingsPressShortcutValue
            return
        }

        recordButton.title = recordedShortcutDisplayName ?? UICopy.settingsRecordShortcutButtonTitle
    }

    private func stopRecording() {
        isRecording = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    func prepareForDismissal() {
        stopRecording()
    }

    func resetForNextRecording() {
        guard isRecording == false else {
            return
        }
        recordedShortcut = nil
    }

    var buttonTitleForTesting: String {
        recordButton.title
    }

    var buttonControlSizeForTesting: NSControl.ControlSize {
        recordButton.controlSize
    }

    func beginRecordingForTesting() {
        recordedShortcut = nil
        isRecording = true
    }

    func applyRecordedShortcutForTesting(_ shortcut: KeyboardShortcut) {
        recordedShortcut = shortcut
        stopRecording()
    }
}

extension HotkeyAddSheetContentView {
    var visibleShortcutDisplayNamesForTesting: [String] {
        visibleShortcuts.map(\.prototypeDisplayName)
    }

    var shortcutButtonTitleForTesting: String {
        recorderView.buttonTitleForTesting
    }

    var shortcutButtonControlSizeForTesting: NSControl.ControlSize {
        recorderView.buttonControlSizeForTesting
    }

    var editedActionIDsForTesting: Set<String> {
        editedActionIDs
    }

    func beginShortcutRecordingForTesting() {
        recorderView.beginRecordingForTesting()
    }

    func applyRecordedShortcutForTesting(_ shortcut: KeyboardShortcut) {
        recorderView.applyRecordedShortcutForTesting(shortcut)
        var shortcuts = visibleShortcuts
        if shortcuts.contains(shortcut) == false {
            shortcuts.append(shortcut)
            shortcutsByActionID[selectedActionID] = shortcuts
            editedActionIDs.insert(selectedActionID)
            rebuildShortcutRows()
        }
        recorderView.resetForNextRecording()
    }

    func removeVisibleShortcutForTesting(at index: Int) {
        guard visibleShortcuts.indices.contains(index) else {
            return
        }
        var shortcuts = visibleShortcuts
        shortcuts.remove(at: index)
        shortcutsByActionID[selectedActionID] = shortcuts
        editedActionIDs.insert(selectedActionID)
        rebuildShortcutRows()
    }

    func selectActionForTesting(_ actionID: String) {
        guard let index = actions.firstIndex(where: { $0.id == actionID }) else {
            return
        }
        behaviorPopupButton.selectItem(at: index)
        rebuildShortcutRows()
    }
}
