import AppKit

@MainActor
final class GeneralSettingsMockViewController: NSViewController {
    private let modifierGroupsController = SingleColumnMockTableController(
        items: ["Option", "Shift + Option"],
        selectedRow: 0
    )
    private let excludedWindowsController = TwoColumnMockTableController(
        items: [
            ("com.apple.finder", UICopy.bundleIDTitle),
            ("Picture in Picture", UICopy.windowTitle),
        ],
        selectedRow: 0
    )

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let contentStack = NSStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 22

        documentView.addSubview(contentStack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 34),
            contentStack.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            contentStack.widthAnchor.constraint(equalToConstant: 760),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -32),

            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        contentStack.addArrangedSubview(makePrimaryControlsGrid())
        contentStack.addArrangedSubview(makeStandaloneCheckboxes())
        contentStack.addArrangedSubview(makeSearchCheckboxes())
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        selectInitialRowsIfNeeded()
    }

    private func selectInitialRowsIfNeeded() {
        modifierGroupsController.selectInitialRowIfNeeded()
        excludedWindowsController.selectInitialRowIfNeeded()
    }

    private func makePrimaryControlsGrid() -> NSGridView {
        let enableSwitch = NSSwitch()
        enableSwitch.state = .on

        let middleMouseSwitch = NSSwitch()
        middleMouseSwitch.state = .on

        let modifierSwitch = NSSwitch()
        modifierSwitch.state = .on

        let modifierPopup = NSPopUpButton()
        modifierPopup.addItems(withTitles: modifierGroupsController.items)
        modifierPopup.selectItem(at: 0)
        modifierPopup.frame.size.width = 260

        let excludedTypePopup = NSPopUpButton()
        excludedTypePopup.addItems(withTitles: [UICopy.bundleIDTitle, UICopy.windowTitle])
        excludedTypePopup.selectItem(at: 0)
        excludedTypePopup.frame.size.width = 260

        let controlsGrid = NSGridView(views: [
            [makeLabel(UICopy.enableTitle), enableSwitch],
            [makeLabel(UICopy.middleMouseTitle), middleMouseSwitch],
            [makeLabel(UICopy.modifierLeftMouseTitle), modifierSwitch],
            [makeLabel("Modifier groups"), modifierPopup],
            [makeLabel("Excluded match type"), excludedTypePopup],
        ])

        controlsGrid.translatesAutoresizingMaskIntoConstraints = false
        controlsGrid.rowSpacing = 16
        controlsGrid.columnSpacing = 18
        controlsGrid.xPlacement = .leading
        controlsGrid.yPlacement = .center
        controlsGrid.column(at: 0).xPlacement = .trailing
        controlsGrid.column(at: 1).xPlacement = .leading
        controlsGrid.column(at: 0).width = 210
        controlsGrid.column(at: 1).width = 360

        let modifierSection = makeTableSection(
            title: "Modifier groups",
            tableView: modifierGroupsController.tableContainer,
            buttons: [makeButton(UICopy.add), makeButton(UICopy.delete)]
        )

        let excludedSection = makeTableSection(
            title: UICopy.excludedWindowsSectionTitle,
            tableView: excludedWindowsController.tableContainer,
            buttons: [makeButton(UICopy.add), makeButton(UICopy.delete)]
        )

        let stack = NSStackView(views: [controlsGrid, modifierSection, excludedSection])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return NSGridView(views: [[stack]])
    }

    private func makeStandaloneCheckboxes() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12

        stack.addArrangedSubview(makeCheckbox(title: "Enable drag triggers"))
        stack.addArrangedSubview(makeCheckbox(title: "Keep cycling shortcuts available"))
        stack.addArrangedSubview(makeCheckbox(title: "Show trigger previews while dragging"))
        stack.addArrangedSubview(makeCheckbox(title: "Ignore fullscreen windows", state: .on))
        return stack
    }

    private func makeSearchCheckboxes() -> NSStackView {
        let titleLabel = NSTextField(labelWithString: "Exclude matches by:")
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(makeCheckbox(title: UICopy.bundleIDTitle, state: .on))
        stack.addArrangedSubview(makeCheckbox(title: UICopy.windowTitle, state: .on))
        return stack
    }

    private func makeTableSection(title: String, tableView: NSView, buttons: [NSButton]) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        let buttonRow = NSStackView(views: buttons)
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let stack = NSStackView(views: [titleLabel, tableView, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        return stack
    }

    private func makeLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title + ":")
        label.alignment = .right
        label.font = .systemFont(ofSize: 14)
        return label
    }

    private func makeCheckbox(title: String, state: NSControl.StateValue = .off) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        checkbox.state = state
        checkbox.font = .systemFont(ofSize: 14)
        return checkbox
    }

    private func makeButton(_ title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        return button
    }
}

@MainActor
private final class SingleColumnMockTableController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let items: [String]
    let selectedRow: Int
    let tableView: NSTableView
    let tableContainer: NSScrollView

    init(items: [String], selectedRow: Int) {
        self.items = items
        self.selectedRow = selectedRow

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowSizeStyle = .medium
        tableView.selectionHighlightStyle = .regular

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
        column.width = 280
        tableView.addTableColumn(column)

        tableContainer = NSScrollView()
        tableContainer.drawsBackground = false
        tableContainer.borderType = .bezelBorder
        tableContainer.documentView = tableView
        tableContainer.hasVerticalScroller = true
        tableContainer.autohidesScrollers = true
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.frame.size = NSSize(width: 320, height: 84)

        super.init()
        tableView.dataSource = self
        tableView.delegate = self
    }

    func selectInitialRowIfNeeded() {
        guard selectedRow >= 0, selectedRow < items.count else {
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: items[row])
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}

@MainActor
private final class TwoColumnMockTableController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let items: [(value: String, type: String)]
    let selectedRow: Int
    let tableView: NSTableView
    let tableContainer: NSScrollView

    init(items: [(String, String)], selectedRow: Int) {
        self.items = items
        self.selectedRow = selectedRow

        tableView = NSTableView()
        tableView.rowSizeStyle = .medium
        tableView.selectionHighlightStyle = .regular

        let valueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
        valueColumn.title = UICopy.valueColumnTitle
        valueColumn.width = 330
        tableView.addTableColumn(valueColumn)

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = UICopy.typeColumnTitle
        typeColumn.width = 160
        tableView.addTableColumn(typeColumn)

        tableContainer = NSScrollView()
        tableContainer.drawsBackground = false
        tableContainer.borderType = .bezelBorder
        tableContainer.documentView = tableView
        tableContainer.hasVerticalScroller = true
        tableContainer.autohidesScrollers = true
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        tableContainer.frame.size = NSSize(width: 520, height: 132)

        super.init()
        tableView.dataSource = self
        tableView.delegate = self
    }

    func selectInitialRowIfNeeded() {
        guard selectedRow >= 0, selectedRow < items.count else {
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else {
            return nil
        }

        let text: String
        if tableColumn.identifier.rawValue == "value" {
            text = items[row].value
        } else {
            text = items[row].type
        }

        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: text)
        textField.translatesAutoresizingMaskIntoConstraints = false
        if tableColumn.identifier.rawValue == "type" {
            textField.textColor = .secondaryLabelColor
        }
        cell.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
