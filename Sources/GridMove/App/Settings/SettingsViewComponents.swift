import AppKit

enum SettingsLayoutMetrics {
    static let pageSpacing: CGFloat = 20
    static let pageInsets = NSEdgeInsets(top: 24, left: 30, bottom: 24, right: 30)
    static let sectionSpacing: CGFloat = 10
    static let rowSpacing: CGFloat = 9
    static let sectionIndent: CGFloat = 12
    static let formColumnSpacing: CGFloat = 14
    static let formLabelWidth: CGFloat = 180
    static let inlineTabSpacing: CGFloat = 14
    static let inlineTabContentWidth: CGFloat = 560
    static let inlineTabPanelCornerRadius: CGFloat = 10
    static let inlineTabPanelInsets = NSEdgeInsets(top: 34, left: 26, bottom: 4, right: 26)
    static let inlineTabBridgeHorizontalInset: CGFloat = 8
    static let inlineTabBridgeVerticalInset: CGFloat = 4
}

@MainActor
func makeSettingsPageStackView() -> NSStackView {
    let stackView = makeVerticalGroup(spacing: SettingsLayoutMetrics.pageSpacing)
    stackView.edgeInsets = SettingsLayoutMetrics.pageInsets
    return stackView
}

@MainActor
func makeSettingsSection(title: String, rows: [NSView]) -> NSView {
    let stackView = makeVerticalGroup(spacing: SettingsLayoutMetrics.sectionSpacing)
    stackView.addArrangedSubview(makeSectionTitleLabel(title))

    let rowsStackView = makeVerticalGroup(spacing: SettingsLayoutMetrics.rowSpacing)
    rows.forEach { rowsStackView.addArrangedSubview($0) }
    stackView.addArrangedSubview(makeIndentedContainer(for: rowsStackView))
    return stackView
}

@MainActor
func makeCheckboxRow(title: String, state: NSControl.StateValue = .on, isEnabled: Bool = true) -> NSButton {
    let checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
    checkbox.state = state
    checkbox.isEnabled = isEnabled
    return checkbox
}

@MainActor
func makeLabeledControlRow(label: String, control: NSView) -> NSView {
    let rowView = makeHorizontalGroup(spacing: SettingsLayoutMetrics.formColumnSpacing)

    let labelField = makeFieldLabel(label)
    labelField.alignment = .right
    labelField.setContentHuggingPriority(.required, for: .horizontal)
    labelField.setContentCompressionResistancePriority(.required, for: .horizontal)
    labelField.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.formLabelWidth).isActive = true

    control.setContentHuggingPriority(.defaultLow, for: .horizontal)
    control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    rowView.addArrangedSubview(labelField)
    rowView.addArrangedSubview(control)
    rowView.addArrangedSubview(NSView())
    return rowView
}

@MainActor
func makeInlineTabContent(rows: [NSView], width: CGFloat = SettingsLayoutMetrics.inlineTabContentWidth) -> NSView {
    let stackView = makeVerticalGroup(spacing: SettingsLayoutMetrics.rowSpacing)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.widthAnchor.constraint(equalToConstant: width).isActive = true
    rows.forEach { stackView.addArrangedSubview($0) }
    return stackView
}

@MainActor
func makeLabeledViewGrid(rows: [(String, NSView)]) -> NSView {
    let gridRows = rows.map { label, view in
        [makeFieldLabel(label), view]
    }
    let gridView = NSGridView(views: gridRows)
    gridView.columnSpacing = 16
    gridView.rowSpacing = 12
    gridView.xPlacement = .leading
    gridView.yPlacement = .center
    gridView.column(at: 0).width = 160
    return makeIndentedContainer(for: gridView)
}

@MainActor
func makeMouseButtonControl() -> SettingsIntegerStepperControl {
    SettingsIntegerStepperControl(
        value: GeneralSettings.defaultMouseButtonNumber,
        minValue: GeneralSettings.defaultMouseButtonNumber,
        maxValue: nil
    )
}

@MainActor
final class SettingsIntegerFormatter: NumberFormatter, @unchecked Sendable {
    override init() {
        super.init()
        numberStyle = .none
        allowsFloats = false
        generatesDecimalNumbers = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func isPartialStringValid(
        _ partialString: String,
        newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        guard partialString.isEmpty == false else {
            return true
        }

        return partialString.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains)
    }
}

@MainActor
final class SettingsIntegerStepperControl: NSView, NSTextFieldDelegate {
    var onValueChanged: ((Int) -> Void)?

    private let textField = NSTextField(string: "")
    private let stepper = NSStepper()
    private let minValue: Int
    private let maxValue: Int?

    init(value: Int, minValue: Int = 0, maxValue: Int? = 99, textFieldWidth: CGFloat = 56) {
        self.minValue = minValue
        self.maxValue = maxValue
        super.init(frame: .zero)

        let formatter = SettingsIntegerFormatter()
        formatter.minimum = NSNumber(value: minValue)
        if let maxValue {
            formatter.maximum = NSNumber(value: maxValue)
        }

        textField.controlSize = .small
        textField.alignment = .right
        textField.formatter = formatter
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: textFieldWidth).isActive = true

        stepper.controlSize = .small
        stepper.minValue = Double(minValue)
        stepper.maxValue = Double(maxValue ?? Int.max)
        stepper.increment = 1
        stepper.target = self
        stepper.action = #selector(handleStepperChanged(_:))

        let stackView = makeHorizontalGroup(spacing: 6)
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(textField)
        stackView.addArrangedSubview(stepper)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        setValue(value)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    var value: Int {
        stepper.integerValue
    }

    func setValue(_ value: Int) {
        let boundedValue = boundedValue(for: value)
        textField.stringValue = String(boundedValue)
        stepper.integerValue = boundedValue
    }

    @objc
    private func handleStepperChanged(_ sender: NSStepper) {
        let boundedValue = boundedValue(for: sender.integerValue)
        setValue(boundedValue)
        onValueChanged?(boundedValue)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        let boundedValue = boundedValue(for: Int(textField.stringValue) ?? minValue)
        setValue(boundedValue)
        onValueChanged?(boundedValue)
    }

    private func boundedValue(for value: Int) -> Int {
        if let maxValue {
            return max(minValue, min(maxValue, value))
        }
        return max(minValue, value)
    }
}

extension SettingsIntegerStepperControl {
    func setRawValueForTesting(_ value: String) {
        textField.stringValue = value
    }

    func commitTextEditingForTesting() {
        controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification))
    }
}

@MainActor
func makeNumericStepperControl(
    value: Int,
    unit: String,
    minValue: Int = 0,
    maxValue: Int? = 99,
    textFieldWidth: CGFloat = 56
) -> NSView {
    let stackView = makeHorizontalGroup(spacing: 8)
    stackView.alignment = .centerY
    stackView.addArrangedSubview(
        SettingsIntegerStepperControl(
            value: value,
            minValue: minValue,
            maxValue: maxValue,
            textFieldWidth: textFieldWidth
        )
    )
    stackView.addArrangedSubview(makeFieldLabel(unit))
    return stackView
}

@MainActor
func makeCenteredContainer(for view: NSView) -> NSView {
    let containerView = NSView()
    view.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(view)

    NSLayoutConstraint.activate([
        view.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
        view.topAnchor.constraint(equalTo: containerView.topAnchor),
        view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        view.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor),
        containerView.trailingAnchor.constraint(greaterThanOrEqualTo: view.trailingAnchor),
    ])

    return containerView
}

@MainActor
func makeFullWidthContainer(for view: NSView) -> NSView {
    let containerView = NSView()
    view.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(view)

    NSLayoutConstraint.activate([
        view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        view.topAnchor.constraint(equalTo: containerView.topAnchor),
        view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])

    return containerView
}

@MainActor
func makeSettingsTableView() -> NSTableView {
    let tableView = NSTableView()
    tableView.headerView = nil
    tableView.intercellSpacing = NSSize(width: 0, height: 0)
    tableView.rowHeight = 24
    tableView.usesAlternatingRowBackgroundColors = false
    tableView.selectionHighlightStyle = .regular
    tableView.focusRingType = .none
    return tableView
}

@MainActor
func makeSettingsTableScrollView(tableView: NSTableView, width: CGFloat? = nil, height: CGFloat? = nil) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.borderType = .bezelBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.documentView = tableView
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    if let width {
        scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: width).isActive = true
    }

    if let height {
        scrollView.heightAnchor.constraint(equalToConstant: height).isActive = true
    }

    return scrollView
}

@MainActor
func makeSettingsTableCellView(identifier: NSUserInterfaceItemIdentifier, text: String) -> NSTableCellView {
    let cellView = NSTableCellView()
    cellView.identifier = identifier

    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 13)
    label.lineBreakMode = .byTruncatingTail
    label.translatesAutoresizingMaskIntoConstraints = false

    cellView.addSubview(label)
    cellView.textField = label

    NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
        label.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
        label.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
    ])

    return cellView
}

@MainActor
func makeIndentedContainer(for view: NSView) -> NSView {
    let stackView = makeHorizontalGroup(spacing: 0)
    let spacer = NSView()
    spacer.widthAnchor.constraint(equalToConstant: SettingsLayoutMetrics.sectionIndent).isActive = true
    stackView.addArrangedSubview(spacer)
    stackView.addArrangedSubview(view)
    stackView.addArrangedSubview(NSView())
    return stackView
}

@MainActor
func makeSectionTitleLabel(_ stringValue: String) -> NSTextField {
    let label = NSTextField(labelWithString: stringValue)
    label.font = .systemFont(ofSize: 12, weight: .semibold)
    return label
}

@MainActor
func makeFieldLabel(_ stringValue: String) -> NSTextField {
    let label = NSTextField(labelWithString: stringValue)
    label.font = .systemFont(ofSize: 13)
    label.textColor = .secondaryLabelColor
    return label
}

@MainActor
func makeValueLabel(_ stringValue: String) -> NSTextField {
    let label = NSTextField(labelWithString: stringValue)
    label.font = .systemFont(ofSize: 13)
    label.lineBreakMode = .byWordWrapping
    label.maximumNumberOfLines = 0
    return label
}

@MainActor
func makeSecondaryLabel(_ stringValue: String) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: stringValue)
    label.font = .systemFont(ofSize: 13)
    label.textColor = .secondaryLabelColor
    return label
}

@MainActor
func makeVerticalGroup(spacing: CGFloat) -> NSStackView {
    let stackView = NSStackView()
    stackView.orientation = .vertical
    stackView.alignment = .leading
    stackView.spacing = spacing
    return stackView
}

@MainActor
func makeHorizontalGroup(spacing: CGFloat) -> NSStackView {
    let stackView = NSStackView()
    stackView.orientation = .horizontal
    stackView.alignment = .top
    stackView.spacing = spacing
    return stackView
}

@MainActor
func makeSettingsPageContainerView(contentView: NSView) -> NSView {
    let containerView = NSView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(contentView)

    NSLayoutConstraint.activate([
        contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        contentView.topAnchor.constraint(equalTo: containerView.topAnchor),
        contentView.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor),
    ])

    return containerView
}
