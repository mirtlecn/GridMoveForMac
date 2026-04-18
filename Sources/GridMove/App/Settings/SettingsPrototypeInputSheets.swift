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

        valueField.placeholderString = initialKind.placeholderValue
        valueField.controlSize = .small
        valueField.delegate = self
        valueField.translatesAutoresizingMaskIntoConstraints = false
        valueField.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let body = makeVerticalGroup(spacing: 10)
        body.translatesAutoresizingMaskIntoConstraints = false
        body.addArrangedSubview(makeSheetLabeledControlRow(label: UICopy.settingsTypeLabel, control: kindPopupButton))
        body.addArrangedSubview(makeSheetLabeledControlRow(label: UICopy.settingsValueLabel, control: valueField))
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
    private let actions: [HotkeyPrototypeAction]
    var onConfirmationStateChanged: (() -> Void)?

    init(actions: [HotkeyPrototypeAction], selectedActionID: String?) {
        self.actions = actions
        super.init(frame: .zero)

        behaviorPopupButton.addItems(withTitles: actions.map(\.displayTitle))
        if let selectedActionID,
           let selectedIndex = actions.firstIndex(where: { $0.id == selectedActionID }) {
            behaviorPopupButton.selectItem(at: selectedIndex)
        }

        let body = makeVerticalGroup(spacing: 10)
        body.translatesAutoresizingMaskIntoConstraints = false
        body.addArrangedSubview(makeSheetLabeledControlRow(label: UICopy.settingsBehaviorLabel, control: behaviorPopupButton))
        body.addArrangedSubview(makeSheetLabeledControlRow(label: UICopy.settingsShortcutLabel, control: recorderView))
        addSubview(body)

        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.topAnchor.constraint(equalTo: topAnchor),
            body.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        recorderView.onShortcutChanged = { [weak self] in
            self?.onConfirmationStateChanged?()
        }
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
        recordedShortcut != nil
    }

    var recordedShortcut: KeyboardShortcut? {
        recorderView.recordedShortcut
    }

    func prepareForDismissal() {
        recorderView.prepareForDismissal()
    }
}

@MainActor
private final class PrototypeShortcutRecorderView: NSView {
    private let recordButton = NSButton(title: UICopy.settingsRecordShortcutButtonTitle, target: nil, action: nil)
    private var eventMonitor: Any?
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

            self.recordedShortcut = KeyboardShortcut(
                modifiers: ModifierKey.from(event.modifierFlags),
                key: key
            )
            self.stopRecording()
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
    var shortcutButtonTitleForTesting: String {
        recorderView.buttonTitleForTesting
    }

    var shortcutButtonControlSizeForTesting: NSControl.ControlSize {
        recorderView.buttonControlSizeForTesting
    }

    func beginShortcutRecordingForTesting() {
        recorderView.beginRecordingForTesting()
    }

    func applyRecordedShortcutForTesting(_ shortcut: KeyboardShortcut) {
        recorderView.applyRecordedShortcutForTesting(shortcut)
    }
}
