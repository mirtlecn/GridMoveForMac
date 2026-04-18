import AppKit

@MainActor
final class SettingsPrototypeSheetController: NSViewController {
    private let sheetTitle: String
    private let message: String?
    private let bodyView: NSView
    private let confirmButtonTitle: String
    private let onConfirm: () -> Void

    init(
        title: String,
        message: String? = nil,
        bodyView: NSView,
        confirmButtonTitle: String,
        onConfirm: @escaping () -> Void
    ) {
        self.sheetTitle = title
        self.message = message
        self.bodyView = bodyView
        self.confirmButtonTitle = confirmButtonTitle
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 420, height: 240)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let contentStackView = makeSettingsPageStackView()
        contentStackView.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        contentStackView.spacing = 16
        contentStackView.addArrangedSubview(makeSectionTitleLabel(sheetTitle))

        if let message, !message.isEmpty {
            contentStackView.addArrangedSubview(makeSecondaryLabel(message))
        }

        contentStackView.addArrangedSubview(bodyView)
        contentStackView.addArrangedSubview(makeSheetButtonsRow())
        view = makeSettingsPageContainerView(contentView: contentStackView)
    }

    @objc
    private func handleCancel(_ sender: NSButton) {
        dismiss(self)
    }

    @objc
    private func handleConfirm(_ sender: NSButton) {
        onConfirm()
        dismiss(self)
    }

    private func makeSheetButtonsRow() -> NSView {
        let cancelButton = NSButton(title: UICopy.settingsCancelButtonTitle, target: self, action: #selector(handleCancel(_:)))
        cancelButton.bezelStyle = .rounded

        let confirmButton = NSButton(title: confirmButtonTitle, target: self, action: #selector(handleConfirm(_:)))
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"

        let row = makeHorizontalGroup(spacing: 8)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(cancelButton)
        row.addArrangedSubview(confirmButton)
        return row
    }
}

@MainActor
final class ModifierGroupSheetContentView: NSView {
    private struct ModifierOption {
        let title: String
        let value: String
    }

    private let options: [ModifierOption] = [
        ModifierOption(title: "Control", value: "Ctrl"),
        ModifierOption(title: "Shift", value: "Shift"),
        ModifierOption(title: "Option", value: "Option"),
        ModifierOption(title: "Command", value: "Cmd"),
    ]
    private let checkboxes: [NSButton]

    override init(frame frameRect: NSRect) {
        self.checkboxes = options.map { option in
            let checkbox = makeCheckboxRow(title: option.title, state: .off)
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            return checkbox
        }
        super.init(frame: frameRect)

        let rows = makeVerticalGroup(spacing: 10)
        rows.translatesAutoresizingMaskIntoConstraints = false
        checkboxes.forEach { rows.addArrangedSubview($0) }
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

    var selectedModifierDisplayName: String {
        let selectedValues = zip(options, checkboxes)
            .compactMap { option, checkbox in
                checkbox.state == .on ? option.value : nil
            }

        return selectedValues.isEmpty ? "Ctrl + Option" : selectedValues.joined(separator: " + ")
    }
}

@MainActor
final class ExclusionEntrySheetContentView: NSView {
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
        valueField.translatesAutoresizingMaskIntoConstraints = false
        valueField.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let body = makeVerticalGroup(spacing: 10)
        body.translatesAutoresizingMaskIntoConstraints = false
        body.addArrangedSubview(makeLabeledControlRow(label: UICopy.settingsTypeLabel, control: kindPopupButton))
        body.addArrangedSubview(makeLabeledControlRow(label: UICopy.settingsValueLabel, control: valueField))
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

    var resolvedValue: String {
        let trimmedValue = valueField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? selectedKind.placeholderValue : trimmedValue
    }

    @objc
    private func handleKindChanged(_ sender: NSPopUpButton) {
        valueField.placeholderString = selectedKind.placeholderValue
    }
}

@MainActor
final class HotkeyAddSheetContentView: NSView {
    private let behaviorPopupButton = NSPopUpButton()
    private let recorderView = PrototypeShortcutRecorderView()
    private let actions: [HotkeyPrototypeAction]

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
        body.addArrangedSubview(makeLabeledControlRow(label: UICopy.settingsBehaviorLabel, control: behaviorPopupButton))
        body.addArrangedSubview(makeLabeledControlRow(label: UICopy.settingsShortcutLabel, control: recorderView))
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

    var selectedActionID: String {
        let selectedIndex = behaviorPopupButton.indexOfSelectedItem
        guard actions.indices.contains(selectedIndex) else {
            return actions.first?.id ?? ""
        }
        return actions[selectedIndex].id
    }

    var recordedShortcutDisplayName: String {
        recorderView.recordedShortcutDisplayName
    }
}

@MainActor
private final class PrototypeShortcutRecorderView: NSView {
    private let textField = NSTextField(string: "")
    private let recordButton = NSButton(title: UICopy.settingsRecordShortcutButtonTitle, target: nil, action: nil)
    private var eventMonitor: Any?
    private var isRecording = false {
        didSet {
            recordButton.title = isRecording
                ? UICopy.settingsRecordingShortcutButtonTitle
                : UICopy.settingsRecordShortcutButtonTitle
            if isRecording {
                textField.stringValue = UICopy.settingsPressShortcutValue
            } else {
                textField.stringValue = recordedShortcutDisplayName
            }
        }
    }

    private(set) var recordedShortcutDisplayName = "⌃⌘K" {
        didSet {
            if !isRecording {
                textField.stringValue = recordedShortcutDisplayName
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        textField.isEditable = false
        textField.isBezeled = true
        textField.controlSize = .small
        textField.placeholderString = UICopy.settingsPressShortcutValue
        textField.stringValue = recordedShortcutDisplayName
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: 130).isActive = true

        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(handleRecord(_:))

        let row = makeHorizontalGroup(spacing: 8)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.alignment = .centerY
        row.addArrangedSubview(textField)
        row.addArrangedSubview(recordButton)
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
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

        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            self.recordedShortcutDisplayName = KeyboardShortcut(
                modifiers: ModifierKey.from(event.modifierFlags),
                key: event.charactersIgnoringModifiers ?? ""
            ).prototypeDisplayName
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
