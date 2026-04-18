import AppKit

private enum SettingsLayoutMetrics {
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

struct SettingsInlineTab {
    let title: String
    let contentView: NSView
}

@MainActor
private final class SettingsInlineTabPanelView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateLayerAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerAppearance()
    }

    private func updateLayerAppearance() {
        material = .underWindowBackground
        blendingMode = .withinWindow
        state = .followsWindowActiveState
        layer?.cornerRadius = SettingsLayoutMetrics.inlineTabPanelCornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = 0
    }
}

@MainActor
private final class SettingsInlineTabBridgeView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateLayerAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateLayerAppearance()
    }

    private func updateLayerAppearance() {
        material = .underWindowBackground
        blendingMode = .withinWindow
        state = .followsWindowActiveState
        layer?.cornerRadius = SettingsLayoutMetrics.inlineTabPanelCornerRadius
        layer?.masksToBounds = true
    }
}

@MainActor
final class SettingsInlineTabsView: NSView {
    private let segmentedControl: NSSegmentedControl
    private let contentStackView = makeVerticalGroup(spacing: 0)
    private let contentBackgroundView = SettingsInlineTabPanelView()
    private let segmentedBridgeView = SettingsInlineTabBridgeView()
    private let tabViews: [NSView]
    var onSelectionChanged: ((Int) -> Void)?

    init(tabs: [SettingsInlineTab], selectedIndex: Int = 0) {
        self.tabViews = tabs.map(\.contentView)
        self.segmentedControl = NSSegmentedControl(
            labels: tabs.map(\.title),
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )
        super.init(frame: .zero)

        segmentedControl.segmentStyle = .rounded
        segmentedControl.selectedSegment = max(0, min(selectedIndex, tabs.count - 1))
        segmentedControl.target = self
        segmentedControl.action = #selector(handleSegmentChange(_:))
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false

        segmentedBridgeView.translatesAutoresizingMaskIntoConstraints = false
        contentBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentBackgroundView.addSubview(contentStackView)
        addSubview(contentBackgroundView)
        addSubview(segmentedBridgeView)
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            contentBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentBackgroundView.topAnchor.constraint(equalTo: segmentedControl.centerYAnchor),
            contentBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            segmentedBridgeView.leadingAnchor.constraint(equalTo: segmentedControl.leadingAnchor, constant: -SettingsLayoutMetrics.inlineTabBridgeHorizontalInset),
            segmentedBridgeView.trailingAnchor.constraint(equalTo: segmentedControl.trailingAnchor, constant: SettingsLayoutMetrics.inlineTabBridgeHorizontalInset),
            segmentedBridgeView.topAnchor.constraint(equalTo: segmentedControl.topAnchor, constant: -SettingsLayoutMetrics.inlineTabBridgeVerticalInset),
            segmentedBridgeView.bottomAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: SettingsLayoutMetrics.inlineTabBridgeVerticalInset),
            segmentedControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            segmentedControl.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: contentBackgroundView.leadingAnchor, constant: SettingsLayoutMetrics.inlineTabPanelInsets.left),
            contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentBackgroundView.trailingAnchor, constant: -SettingsLayoutMetrics.inlineTabPanelInsets.right),
            contentStackView.topAnchor.constraint(equalTo: contentBackgroundView.topAnchor, constant: SettingsLayoutMetrics.inlineTabPanelInsets.top),
            contentStackView.bottomAnchor.constraint(equalTo: contentBackgroundView.bottomAnchor, constant: -SettingsLayoutMetrics.inlineTabPanelInsets.bottom),
        ])

        for (index, tabView) in tabViews.enumerated() {
            tabView.isHidden = index != segmentedControl.selectedSegment
            contentStackView.addArrangedSubview(tabView)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    @objc
    private func handleSegmentChange(_ sender: NSSegmentedControl) {
        for (index, tabView) in tabViews.enumerated() {
            tabView.isHidden = index != sender.selectedSegment
        }
        onSelectionChanged?(sender.selectedSegment)
    }
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
func makeLabeledValueGrid(rows: [(String, String)]) -> NSView {
    let gridRows = rows.map { label, value in
        [makeFieldLabel(label), makeValueLabel(value)]
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
func makeMouseButtonPopup() -> NSPopUpButton {
    let popupButton = NSPopUpButton()
    popupButton.addItems(withTitles: ["3", "4", "5"])
    popupButton.selectItem(withTitle: "3")
    return popupButton
}

@MainActor
func makePlainListControl(items: [String]) -> NSView {
    let textView = NSTextView()
    textView.isEditable = false
    textView.isSelectable = false
    textView.drawsBackground = true
    textView.backgroundColor = .textBackgroundColor
    textView.font = .systemFont(ofSize: 13)
    textView.textColor = .labelColor
    textView.string = items.joined(separator: "\n")
    textView.textContainerInset = NSSize(width: 4, height: 6)

    let scrollView = NSScrollView()
    scrollView.borderType = .bezelBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.documentView = textView
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.widthAnchor.constraint(equalToConstant: 340).isActive = true
    scrollView.heightAnchor.constraint(equalToConstant: 78).isActive = true

    let stackView = makeVerticalGroup(spacing: 8)
    stackView.addArrangedSubview(scrollView)
    stackView.addArrangedSubview(
        makeBottomTrailingButtonRow(buttonTitles: [
            UICopy.settingsAddButtonTitle,
            UICopy.settingsRemoveButtonTitle,
        ])
    )

    return stackView
}

@MainActor
func makeBottomTrailingButtonRow(buttonTitles: [String]) -> NSView {
    let stackView = makeHorizontalGroup(spacing: 8)
    stackView.addArrangedSubview(NSView())

    for title in buttonTitles {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        stackView.addArrangedSubview(button)
    }

    return stackView
}

@MainActor
func makeNumericStepperControl(value: Int, minValue: Int = 0, maxValue: Int = 99, textFieldWidth: CGFloat = 56) -> NSView {
    let formatter = NumberFormatter()
    formatter.numberStyle = .none
    formatter.minimum = NSNumber(value: minValue)
    formatter.maximum = NSNumber(value: maxValue)

    let textField = NSTextField(string: String(value))
    textField.controlSize = .small
    textField.alignment = .right
    textField.formatter = formatter
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.widthAnchor.constraint(equalToConstant: textFieldWidth).isActive = true

    let stepper = NSStepper()
    stepper.controlSize = .small
    stepper.minValue = Double(minValue)
    stepper.maxValue = Double(maxValue)
    stepper.increment = 1
    stepper.integerValue = value

    let stackView = makeHorizontalGroup(spacing: 6)
    stackView.alignment = .centerY
    stackView.addArrangedSubview(textField)
    stackView.addArrangedSubview(stepper)
    return stackView
}

@MainActor
func makeNumericStepperControl(
    value: Int,
    unit: String,
    minValue: Int = 0,
    maxValue: Int = 99,
    textFieldWidth: CGFloat = 56
) -> NSView {
    let stackView = makeHorizontalGroup(spacing: 8)
    stackView.alignment = .centerY
    stackView.addArrangedSubview(
        makeNumericStepperControl(
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

@MainActor
final class SelectableListControlView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    var items: [String] {
        didSet {
            let previousSelectedIndex = selectedIndex
            tableView.reloadData()
            syncSelectionAfterReload(oldSelectedIndex: previousSelectedIndex)
        }
    }

    var onAdd: (() -> Void)?
    var onRemove: ((Int) -> Void)?
    var onSelectionChanged: ((Int?) -> Void)?

    private let tableView = makeSettingsTableView()
    private let scrollView: NSScrollView
    private let addButton: NSButton
    private let removeButton: NSButton
    private var selectedIndex: Int?

    init(
        items: [String],
        addButtonTitle: String = UICopy.settingsAddButtonTitle,
        removeButtonTitle: String = UICopy.settingsRemoveButtonTitle,
        width: CGFloat = 340,
        height: CGFloat = 78,
        showsButtons: Bool = true
    ) {
        self.items = items
        self.scrollView = makeSettingsTableScrollView(tableView: tableView, width: width, height: height)
        self.addButton = NSButton(title: addButtonTitle, target: nil, action: nil)
        self.removeButton = NSButton(title: removeButtonTitle, target: nil, action: nil)
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        let valueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
        valueColumn.width = width
        valueColumn.minWidth = width
        valueColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(valueColumn)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil

        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(handleAdd(_:))

        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(handleRemove(_:))

        let rootStackView = makeVerticalGroup(spacing: 8)
        rootStackView.translatesAutoresizingMaskIntoConstraints = false
        rootStackView.addArrangedSubview(scrollView)
        if showsButtons {
            rootStackView.addArrangedSubview(makeListButtonsRow())
        }
        addSubview(rootStackView)

        NSLayoutConstraint.activate([
            rootStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStackView.topAnchor.constraint(equalTo: topAnchor),
            rootStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateButtons()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func selectItem(at index: Int?) {
        selectedIndex = index
        if let index, items.indices.contains(index) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else {
            tableView.deselectAll(nil)
        }
        updateButtons()
    }

    func appendItem(_ value: String) {
        items.append(value)
        selectItem(at: items.count - 1)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        makeSettingsTableCellView(
            identifier: NSUserInterfaceItemIdentifier("SelectableListCell"),
            text: items[row]
        )
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        selectedIndex = row >= 0 ? row : nil
        updateButtons()
        onSelectionChanged?(selectedIndex)
    }

    @objc
    private func handleAdd(_ sender: NSButton) {
        onAdd?()
    }

    @objc
    private func handleRemove(_ sender: NSButton) {
        guard let selectedIndex else {
            return
        }
        onRemove?(selectedIndex)
    }

    private func makeListButtonsRow() -> NSView {
        let row = makeHorizontalGroup(spacing: 8)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(addButton)
        row.addArrangedSubview(removeButton)
        return row
    }

    private func syncSelectionAfterReload(oldSelectedIndex: Int?) {
        guard let oldSelectedIndex else {
            selectItem(at: nil)
            return
        }

        let clampedIndex = min(oldSelectedIndex, max(0, items.count - 1))
        if items.isEmpty {
            selectItem(at: nil)
        } else {
            selectItem(at: clampedIndex)
        }
    }

    private func updateButtons() {
        removeButton.isEnabled = selectedIndex != nil
    }
}
