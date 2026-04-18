import AppKit

@MainActor
final class SelectableListControlView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    var items: [String] {
        didSet {
            let previousSelectedIndex = selectedIndex
            tableView.reloadData()
            syncColumnWidth()
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
    private let valueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
    private var selectedIndex: Int?
    private let initialColumnWidth: CGFloat

    init(
        items: [String],
        addButtonTitle: String = UICopy.settingsAddButtonTitle,
        removeButtonTitle: String = UICopy.settingsRemoveButtonTitle,
        width: CGFloat = 340,
        height: CGFloat = 78,
        showsButtons: Bool = true
    ) {
        self.items = items
        self.initialColumnWidth = width
        self.scrollView = makeSettingsTableScrollView(tableView: tableView, width: width, height: height)
        self.addButton = NSButton(title: addButtonTitle, target: nil, action: nil)
        self.removeButton = NSButton(title: removeButtonTitle, target: nil, action: nil)
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
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

    override func layout() {
        super.layout()
        syncColumnWidth()
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

    private func syncColumnWidth() {
        let resolvedWidth = max(initialColumnWidth, scrollView.contentSize.width)
        valueColumn.minWidth = min(initialColumnWidth, resolvedWidth)
        valueColumn.width = resolvedWidth
    }

    private func updateButtons() {
        removeButton.isEnabled = selectedIndex != nil
    }
}
