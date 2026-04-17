import AppKit

@MainActor
final class PreferenceGeneralViewController: NSViewController {
    private enum TableKind {
        case modifierGroups
        case excludedWindows
    }

    private struct ExcludedWindowRow {
        let value: String
        let typeTitle: String
    }

    private let defaultConfiguration = AppConfiguration.defaultValue
    private lazy var modifierGroupRows = defaultConfiguration.dragTriggers.modifierGroups.map { group in
        group.map { modifierSymbol(for: $0) }.joined()
    }

    private lazy var excludedWindowRows: [ExcludedWindowRow] = {
        let bundleRows = defaultConfiguration.general.excludedBundleIDs.map {
            ExcludedWindowRow(value: $0, typeTitle: UICopy.bundleIDTitle)
        }
        let titleRows = defaultConfiguration.general.excludedWindowTitles.map {
            ExcludedWindowRow(value: $0, typeTitle: UICopy.windowTitle)
        }
        return bundleRows + titleRows
    }()

    private let modifierGroupsTableView = NSTableView()
    private let excludedWindowsTableView = NSTableView()

    let sectionTitlesForTesting = [
        UICopy.enableTitle,
        UICopy.mouseTriggersSectionTitle,
        UICopy.excludedWindowsSectionTitle,
    ]

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

        contentStack.addArrangedSubview(makeIntroLabel())
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
    }

    private func makeIntroLabel() -> NSView {
        let label = NSTextField(wrappingLabelWithString: UICopy.generalPreviewNote)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        return label
    }

    private func makeEnableSection() -> NSView {
        let checkbox = NSButton(checkboxWithTitle: UICopy.enableTitle, target: nil, action: nil)
        checkbox.state = defaultConfiguration.general.isEnabled ? .on : .off

        let subtitleLabel = makeSecondaryLabel(UICopy.enableSubtitle)

        let stackView = NSStackView(views: [checkbox, subtitleLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6

        return makeSection(title: UICopy.enableTitle, body: stackView)
    }

    private func makeMouseTriggersSection() -> NSView {
        let middleMouseCheckbox = NSButton(checkboxWithTitle: UICopy.middleMouseTitle, target: nil, action: nil)
        middleMouseCheckbox.state = defaultConfiguration.dragTriggers.enableMiddleMouseDrag ? .on : .off

        let modifierLeftCheckbox = NSButton(checkboxWithTitle: UICopy.modifierLeftMouseTitle, target: nil, action: nil)
        modifierLeftCheckbox.state = defaultConfiguration.dragTriggers.enableModifierLeftMouseDrag ? .on : .off

        let checkboxStack = NSStackView(views: [
            makeCheckboxRow(checkbox: middleMouseCheckbox, subtitle: UICopy.middleMouseSubtitle),
            makeCheckboxRow(checkbox: modifierLeftCheckbox, subtitle: UICopy.modifierLeftMouseSubtitle),
        ])
        checkboxStack.orientation = .vertical
        checkboxStack.alignment = .leading
        checkboxStack.spacing = 12

        let modifierGroupsLabel = NSTextField(labelWithString: UICopy.modifierGroupsTitle)
        modifierGroupsLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        configureModifierGroupsTableView()
        let modifierGroupList = makeTableContainer(
            tableView: modifierGroupsTableView,
            buttons: [
                makeSmallActionButton(title: "+"),
                makeSmallActionButton(title: "−"),
            ]
        )

        let stackView = NSStackView(views: [checkboxStack, modifierGroupsLabel, modifierGroupList])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 14

        return makeSection(title: UICopy.mouseTriggersSectionTitle, body: stackView)
    }

    private func makeExcludedWindowsSection() -> NSView {
        configureExcludedWindowsTableView()
        let tableContainer = makeTableContainer(
            tableView: excludedWindowsTableView,
            buttons: [
                makeSmallActionButton(title: "+"),
                makeSmallActionButton(title: "−"),
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

    private func modifierSymbol(for key: ModifierKey) -> String {
        switch key {
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
}

extension PreferenceGeneralViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableKind(for: tableView) {
        case .modifierGroups:
            return modifierGroupRows.count
        case .excludedWindows:
            return excludedWindowRows.count
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let text: String

        switch tableKind(for: tableView) {
        case .modifierGroups:
            text = modifierGroupRows[row]
        case .excludedWindows:
            let rowValue = excludedWindowRows[row]
            if tableColumn?.identifier.rawValue == "type" {
                text = rowValue.typeTitle
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

    private func tableKind(for tableView: NSTableView) -> TableKind {
        switch tableView.identifier?.rawValue {
        case "modifierGroups":
            return .modifierGroups
        default:
            return .excludedWindows
        }
    }
}
