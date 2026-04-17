import AppKit

@MainActor
final class PreferenceGeneralViewController: NSViewController {
    private enum TableKind {
        case modifierGroups
        case excludedWindows
    }

    private let viewModel: PreferenceViewModel

    private let enableCheckbox = NSButton(checkboxWithTitle: UICopy.enableTitle, target: nil, action: nil)
    private let middleMouseCheckbox = NSButton(checkboxWithTitle: UICopy.middleMouseTitle, target: nil, action: nil)
    private let modifierLeftMouseCheckbox = NSButton(checkboxWithTitle: UICopy.modifierLeftMouseTitle, target: nil, action: nil)
    private let modifierGroupsTableView = NSTableView()
    private let excludedWindowsTableView = NSTableView()
    private let modifierGroupsContainer = NSStackView()
    private let mouseTriggersBodyView = NSStackView()
    private var modifierGroupAddButton = NSButton()
    private var modifierGroupRemoveButton = NSButton()
    private var excludedWindowAddButton = NSButton()
    private var excludedWindowRemoveButton = NSButton()

    let sectionTitlesForTesting = [
        UICopy.enableTitle,
        UICopy.mouseTriggersSectionTitle,
        UICopy.excludedWindowsSectionTitle,
    ]

    init(viewModel: PreferenceViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = UICopy.generalSectionTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView()
        rootView.wantsLayer = true

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        contentStack.addArrangedSubview(makeEnableSection())
        contentStack.addArrangedSubview(makeMouseTriggersSection())
        contentStack.addArrangedSubview(makeExcludedWindowsSection())

        documentView.addSubview(contentStack)
        rootView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: rootView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentStack.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 28),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -28),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: documentView.leadingAnchor, constant: 28),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: documentView.trailingAnchor, constant: -28),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: 760),
        ])

        view = rootView
        reloadFromViewModel()
    }

    private func makeEnableSection() -> NSView {
        enableCheckbox.target = self
        enableCheckbox.action = #selector(toggleEnable)

        let subtitleLabel = makeSecondaryLabel(UICopy.enableSubtitle)

        let stackView = NSStackView(views: [enableCheckbox, subtitleLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6

        return makeSection(title: UICopy.enableTitle, body: stackView)
    }

    private func makeMouseTriggersSection() -> NSView {
        middleMouseCheckbox.target = self
        middleMouseCheckbox.action = #selector(toggleMiddleMouse)
        modifierLeftMouseCheckbox.target = self
        modifierLeftMouseCheckbox.action = #selector(toggleModifierLeftMouse)

        let checkboxStack = NSStackView(views: [
            makeCheckboxRow(checkbox: middleMouseCheckbox, subtitle: UICopy.middleMouseSubtitle),
            makeCheckboxRow(checkbox: modifierLeftMouseCheckbox, subtitle: UICopy.modifierLeftMouseSubtitle),
        ])
        checkboxStack.orientation = .vertical
        checkboxStack.alignment = .leading
        checkboxStack.spacing = 12

        let modifierGroupsLabel = NSTextField(labelWithString: UICopy.modifierGroupsTitle)
        modifierGroupsLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        configureModifierGroupsTableView()
        modifierGroupsContainer.orientation = .vertical
        modifierGroupsContainer.alignment = .leading
        modifierGroupsContainer.spacing = 8
        let modifierGroupList = makeTableContainer(
            tableView: modifierGroupsTableView,
            buttons: [
                makeModifierGroupAddButton(),
                makeModifierGroupRemoveButton(),
            ]
        )
        modifierGroupsContainer.addArrangedSubview(modifierGroupsLabel)
        modifierGroupsContainer.addArrangedSubview(modifierGroupList)

        mouseTriggersBodyView.orientation = .vertical
        mouseTriggersBodyView.alignment = .leading
        mouseTriggersBodyView.spacing = 14
        mouseTriggersBodyView.addArrangedSubview(checkboxStack)
        mouseTriggersBodyView.addArrangedSubview(modifierGroupsContainer)

        return makeSection(title: UICopy.mouseTriggersSectionTitle, body: mouseTriggersBodyView)
    }

    private func makeExcludedWindowsSection() -> NSView {
        configureExcludedWindowsTableView()
        let tableContainer = makeTableContainer(
            tableView: excludedWindowsTableView,
            buttons: [
                makeExcludedWindowAddButton(),
                makeExcludedWindowRemoveButton(),
            ]
        )

        return makeSection(title: UICopy.excludedWindowsSectionTitle, body: tableContainer)
    }

    private func makeSection(title: String, body: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let stackView = NSStackView(views: [titleLabel, body])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            body.widthAnchor.constraint(equalTo: stackView.widthAnchor),
        ])

        return container
    }

    private func makeCheckboxRow(checkbox: NSButton, subtitle: String) -> NSView {
        let subtitleLabel = makeSecondaryLabel(subtitle)

        let stackView = NSStackView(views: [checkbox, subtitleLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 4
        return stackView
    }

    private func makeSecondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        return label
    }

    func reloadFromViewModel() {
        enableCheckbox.state = viewModel.configuration.general.isEnabled ? .on : .off
        middleMouseCheckbox.state = viewModel.configuration.dragTriggers.enableMiddleMouseDrag ? .on : .off
        modifierLeftMouseCheckbox.state = viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag ? .on : .off

        modifierGroupsTableView.reloadData()
        excludedWindowsTableView.reloadData()

        let dragEnabled = viewModel.configuration.general.isEnabled
        middleMouseCheckbox.isEnabled = dragEnabled
        modifierLeftMouseCheckbox.isEnabled = dragEnabled
        modifierGroupsContainer.alphaValue = dragEnabled && viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag ? 1 : 0.45
        modifierGroupsTableView.isEnabled = dragEnabled && viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag
        modifierGroupAddButton.isEnabled = dragEnabled && viewModel.configuration.dragTriggers.enableModifierLeftMouseDrag
        modifierGroupRemoveButton.isEnabled = modifierGroupsTableView.selectedRow >= 0 && modifierGroupAddButton.isEnabled

        excludedWindowsTableView.isEnabled = dragEnabled
        excludedWindowAddButton.isEnabled = dragEnabled
        excludedWindowRemoveButton.isEnabled = dragEnabled && excludedWindowsTableView.selectedRow >= 0
    }

    private func configureModifierGroupsTableView() {
        modifierGroupsTableView.identifier = NSUserInterfaceItemIdentifier("modifierGroups")
        modifierGroupsTableView.headerView = nil
        modifierGroupsTableView.rowSizeStyle = .small
        modifierGroupsTableView.usesAlternatingRowBackgroundColors = true
        modifierGroupsTableView.allowsColumnSelection = false
        modifierGroupsTableView.allowsEmptySelection = true
        modifierGroupsTableView.selectionHighlightStyle = .regular
        modifierGroupsTableView.delegate = self
        modifierGroupsTableView.dataSource = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("modifierGroupValue"))
        column.title = UICopy.modifierGroupsTitle
        column.width = 520
        modifierGroupsTableView.addTableColumn(column)
    }

    private func configureExcludedWindowsTableView() {
        excludedWindowsTableView.identifier = NSUserInterfaceItemIdentifier("excludedWindows")
        excludedWindowsTableView.rowSizeStyle = .small
        excludedWindowsTableView.usesAlternatingRowBackgroundColors = true
        excludedWindowsTableView.allowsColumnSelection = false
        excludedWindowsTableView.allowsEmptySelection = true
        excludedWindowsTableView.selectionHighlightStyle = .regular
        excludedWindowsTableView.delegate = self
        excludedWindowsTableView.dataSource = self

        let valueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
        valueColumn.title = UICopy.valueColumnTitle
        valueColumn.width = 420
        excludedWindowsTableView.addTableColumn(valueColumn)

        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = UICopy.typeColumnTitle
        typeColumn.width = 160
        excludedWindowsTableView.addTableColumn(typeColumn)
    }

    private func makeModifierGroupAddButton() -> NSButton {
        let button = makeSmallActionButton(title: "+")
        button.target = self
        button.action = #selector(addModifierGroup)
        modifierGroupAddButton = button
        return button
    }

    private func makeModifierGroupRemoveButton() -> NSButton {
        let button = makeSmallActionButton(title: "−")
        button.target = self
        button.action = #selector(removeSelectedModifierGroup)
        modifierGroupRemoveButton = button
        return button
    }

    private func makeExcludedWindowAddButton() -> NSButton {
        let button = makeSmallActionButton(title: "+")
        button.target = self
        button.action = #selector(addExcludedWindow)
        excludedWindowAddButton = button
        return button
    }

    private func makeExcludedWindowRemoveButton() -> NSButton {
        let button = makeSmallActionButton(title: "−")
        button.target = self
        button.action = #selector(removeSelectedExcludedWindow)
        excludedWindowRemoveButton = button
        return button
    }

    private func makeTableContainer(tableView: NSTableView, buttons: [NSButton]) -> NSView {
        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 148).isActive = true

        let buttonStack = NSStackView(views: buttons)
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 8

        let footer = NSStackView(views: [buttonStack])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 0

        let containerStack = NSStackView(views: [scrollView, footer])
        containerStack.orientation = .vertical
        containerStack.alignment = .leading
        containerStack.spacing = 8

        return containerStack
    }

    private func makeSmallActionButton(title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .small
        return button
    }

    @objc private func toggleEnable() {
        viewModel.updateGeneralEnabled(enableCheckbox.state == .on)
        reloadFromViewModel()
    }

    @objc private func toggleMiddleMouse() {
        viewModel.updateDragTriggers(enableMiddleMouseDrag: middleMouseCheckbox.state == .on)
        reloadFromViewModel()
    }

    @objc private func toggleModifierLeftMouse() {
        viewModel.updateDragTriggers(enableModifierLeftMouseDrag: modifierLeftMouseCheckbox.state == .on)
        reloadFromViewModel()
    }

    @objc private func addModifierGroup() {
        let alert = NSAlert()
        alert.messageText = UICopy.addModifierGroupTitle
        alert.addButton(withTitle: UICopy.add)
        alert.addButton(withTitle: UICopy.cancel)

        let checkboxes = ModifierKey.allCases.map { key in
            let checkbox = NSButton(checkboxWithTitle: key.displayName, target: nil, action: nil)
            checkbox.identifier = NSUserInterfaceItemIdentifier(key.rawValue)
            return checkbox
        }

        let stackView = NSStackView(views: checkboxes)
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        alert.accessoryView = stackView

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let selectedKeys = ModifierKey.allCases.filter { key in
            checkboxes.first(where: { $0.identifier?.rawValue == key.rawValue })?.state == .on
        }
        viewModel.addModifierGroup(selectedKeys)
        reloadFromViewModel()
    }

    @objc private func removeSelectedModifierGroup() {
        let selectedRow = modifierGroupsTableView.selectedRow
        guard selectedRow >= 0,
              viewModel.modifierGroupItems.indices.contains(selectedRow) else {
            return
        }
        viewModel.removeModifierGroup(at: viewModel.modifierGroupItems[selectedRow].index)
        reloadFromViewModel()
    }

    @objc private func addExcludedWindow() {
        let alert = NSAlert()
        alert.messageText = UICopy.addExcludedWindowTitle
        alert.addButton(withTitle: UICopy.add)
        alert.addButton(withTitle: UICopy.cancel)

        let kindPopup = NSPopUpButton()
        kindPopup.addItems(withTitles: [UICopy.bundleIDTitle, UICopy.windowTitle])

        let valueField = NSTextField(string: "")
        valueField.placeholderString = UICopy.valueColumnTitle
        valueField.translatesAutoresizingMaskIntoConstraints = false
        valueField.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let accessoryStack = NSStackView(views: [kindPopup, valueField])
        accessoryStack.orientation = .vertical
        accessoryStack.alignment = .leading
        accessoryStack.spacing = 10
        alert.accessoryView = accessoryStack

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let kind: PreferenceViewModel.EntryKind = kindPopup.indexOfSelectedItem == 0 ? .bundleID : .windowTitle
        viewModel.addExcludedWindow(kind: kind, value: valueField.stringValue)
        reloadFromViewModel()
    }

    @objc private func removeSelectedExcludedWindow() {
        let selectedRow = excludedWindowsTableView.selectedRow
        let items = viewModel.excludedWindowItems
        guard selectedRow >= 0,
              items.indices.contains(selectedRow) else {
            return
        }
        viewModel.removeExcludedWindow(items[selectedRow])
        reloadFromViewModel()
    }
}

extension PreferenceGeneralViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableKind(for: tableView) {
        case .modifierGroups:
            return viewModel.modifierGroupItems.count
        case .excludedWindows:
            return viewModel.excludedWindowItems.count
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let text: String

        switch tableKind(for: tableView) {
        case .modifierGroups:
            text = viewModel.modifierGroupItems[row].symbolTitle
        case .excludedWindows:
            let rowValue = viewModel.excludedWindowItems[row]
            if tableColumn?.identifier.rawValue == "type" {
                text = rowValue.kind.title
            } else {
                text = rowValue.value
            }
        }

        let identifier = NSUserInterfaceItemIdentifier("\(tableColumn?.identifier.rawValue ?? "cell")Cell")
        let cellView: NSTableCellView
        if let reusedView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cellView = reusedView
        } else {
            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingMiddle
            textField.translatesAutoresizingMaskIntoConstraints = false

            let createdCellView = NSTableCellView()
            createdCellView.identifier = identifier
            createdCellView.textField = textField
            createdCellView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: createdCellView.leadingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: createdCellView.trailingAnchor, constant: -6),
                textField.centerYAnchor.constraint(equalTo: createdCellView.centerYAnchor),
            ])
            cellView = createdCellView
        }

        cellView.textField?.stringValue = text
        cellView.textField?.font = .systemFont(ofSize: 12)
        cellView.textField?.textColor = tableColumn?.identifier.rawValue == "type" ? .secondaryLabelColor : .labelColor
        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        reloadFromViewModel()
    }

    private func tableKind(for tableView: NSTableView) -> TableKind {
        switch tableView.identifier?.rawValue {
        case "modifierGroups":
            return .modifierGroups
        default:
            return .excludedWindows
        }
    }
}
