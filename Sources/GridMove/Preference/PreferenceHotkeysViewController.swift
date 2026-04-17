import AppKit

@MainActor
final class PreferenceHotkeysViewController: NSViewController {
    private let viewModel: PreferenceViewModel
    private let rowsStackView = NSStackView()

    init(viewModel: PreferenceViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = UICopy.hotkeysSectionTitle
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var rowCountForTesting: Int {
        viewModel.hotkeyRows.count
    }

    override func loadView() {
        let rootView = NSView()
        rootView.wantsLayer = true

        let helpLabel = NSTextField(wrappingLabelWithString: UICopy.hotkeysHelpText)
        helpLabel.font = NSFont.systemFont(ofSize: 12)
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.maximumNumberOfLines = 0

        rowsStackView.orientation = .vertical
        rowsStackView.alignment = .leading
        rowsStackView.spacing = 0
        rowsStackView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(rowsStackView)

        NSLayoutConstraint.activate([
            rowsStackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            rowsStackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            rowsStackView.topAnchor.constraint(equalTo: documentView.topAnchor),
            rowsStackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            rowsStackView.widthAnchor.constraint(equalTo: documentView.widthAnchor),
        ])

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = documentView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 420).isActive = true

        let addButton = NSButton(title: "+", target: self, action: #selector(addHotkeyRow))
        addButton.bezelStyle = .rounded
        addButton.controlSize = .small

        let footer = NSStackView(views: [addButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8

        let contentStack = NSStackView(views: [helpLabel, scrollView, footer])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 28),
            contentStack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -28),
            contentStack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 28),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: rootView.bottomAnchor, constant: -28),
            scrollView.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
        ])

        view = rootView
        reloadFromViewModel()
    }

    func reloadFromViewModel() {
        rowsStackView.arrangedSubviews.forEach { arrangedSubview in
            rowsStackView.removeArrangedSubview(arrangedSubview)
            arrangedSubview.removeFromSuperview()
        }

        let rows = viewModel.hotkeyRows
        for (index, row) in rows.enumerated() {
            let rowView = PreferenceHotkeyRowView(
                row: row,
                actionOptions: viewModel.hotkeyActionOptions,
                actionTitle: viewModel.hotkeyActionTitle(for: row.action),
                onShortcutChange: { [weak self] shortcut in
                    self?.viewModel.updateHotkeyShortcut(id: row.id, shortcut: shortcut)
                    self?.reloadFromViewModel()
                },
                onActionChange: { [weak self] action in
                    self?.viewModel.updateHotkeyAction(id: row.id, action: action)
                    self?.reloadFromViewModel()
                },
                onDelete: { [weak self] in
                    self?.viewModel.deleteHotkeyRow(id: row.id)
                    self?.reloadFromViewModel()
                }
            )
            rowsStackView.addArrangedSubview(rowView)

            if index != rows.index(before: rows.endIndex) {
                let divider = NSBox()
                divider.boxType = .separator
                rowsStackView.addArrangedSubview(divider)
            }
        }
    }

    @objc private func addHotkeyRow() {
        viewModel.addHotkeyRow()
        reloadFromViewModel()
    }
}

@MainActor
private final class PreferenceHotkeyRowView: NSView {
    private var actionSleeves: [TargetActionSleeve] = []

    init(
        row: PreferenceViewModel.HotkeyRow,
        actionOptions: [(String, HotkeyAction)],
        actionTitle: String,
        onShortcutChange: @escaping (KeyboardShortcut?) -> Void,
        onActionChange: @escaping (HotkeyAction) -> Void,
        onDelete: @escaping () -> Void
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView()
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let actionView: NSView
        if row.isAdditional {
            let popupButton = NSPopUpButton()
            popupButton.translatesAutoresizingMaskIntoConstraints = false
            popupButton.font = NSFont.systemFont(ofSize: 12)
            actionOptions.forEach { title, action in
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.representedObject = action
                popupButton.menu?.addItem(item)
                if action == row.action {
                    popupButton.select(item)
                }
            }
            let popupSleeve = TargetActionSleeve { button in
                guard let popupButton = button as? NSPopUpButton,
                      let action = popupButton.selectedItem?.representedObject as? HotkeyAction else {
                    return
                }
                onActionChange(action)
            }
            actionSleeves.append(popupSleeve)
            popupButton.target = popupSleeve
            popupButton.action = #selector(TargetActionSleeve.invoke(_:))
            popupButton.widthAnchor.constraint(equalToConstant: 300).isActive = true
            actionView = popupButton
        } else {
            let actionLabel = NSTextField(labelWithString: actionTitle)
            actionLabel.font = NSFont.systemFont(ofSize: 13)
            actionLabel.lineBreakMode = .byTruncatingTail
            actionLabel.translatesAutoresizingMaskIntoConstraints = false
            actionLabel.widthAnchor.constraint(equalToConstant: 300).isActive = true
            actionView = actionLabel
        }

        let recorder = PreferenceShortcutRecorderControl()
        recorder.shortcut = row.shortcut
        recorder.onShortcutChange = onShortcutChange
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.widthAnchor.constraint(equalToConstant: 140).isActive = true

        contentStack.addArrangedSubview(actionView)
        contentStack.addArrangedSubview(recorder)

        if row.isAdditional {
            let deleteButton = NSButton(title: UICopy.delete, target: nil, action: nil)
            deleteButton.bezelStyle = .rounded
            deleteButton.controlSize = .small
            let deleteSleeve = TargetActionSleeve { _ in
                onDelete()
            }
            actionSleeves.append(deleteSleeve)
            deleteButton.target = deleteSleeve
            deleteButton.action = #selector(TargetActionSleeve.invoke(_:))
            contentStack.addArrangedSubview(deleteButton)
        } else {
            let spacer = NSView()
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.widthAnchor.constraint(equalToConstant: 56).isActive = true
            contentStack.addArrangedSubview(spacer)
        }

        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private final class TargetActionSleeve: NSObject {
    private let handler: (NSControl) -> Void

    init(handler: @escaping (NSControl) -> Void) {
        self.handler = handler
    }

    @objc func invoke(_ sender: NSControl) {
        handler(sender)
    }
}
