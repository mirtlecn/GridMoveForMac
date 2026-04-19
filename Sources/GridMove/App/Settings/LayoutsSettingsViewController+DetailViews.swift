import AppKit

@MainActor
extension LayoutsSettingsViewController {
    func updateDetailView() {
        currentGroupNameControl = nil
        currentLayoutNameControl = nil
        currentLayoutGridColumnsControl = nil
        currentLayoutGridRowsControl = nil
        currentLayoutWindowXControl = nil
        currentLayoutWindowYControl = nil
        currentLayoutWindowWidthControl = nil
        currentLayoutWindowHeightControl = nil
        detailContainerView.subviews.forEach { $0.removeFromSuperview() }
        currentLayoutPreviewView = nil
        currentLayoutTriggerContentView = nil

        guard let node = selectedNode else {
            updateCommandBar()
            return
        }

        let contentView: NSView
        switch node.kind {
        case let .group(group, isActive):
            contentView = makeGroupDetailView(group: group, isActive: isActive)
        case let .set(groupName, setIndex, set):
            contentView = makeSetDetailView(groupName: groupName, setIndex: setIndex, set: set)
        case let .layout(groupName, setIndex, layout, _):
            contentView = makeLayoutDetailView(groupName: groupName, setIndex: setIndex, layout: layout)
        }

        detailContainerView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: detailContainerView.leadingAnchor, constant: 12),
            contentView.trailingAnchor.constraint(equalTo: detailContainerView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: detailContainerView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: detailContainerView.bottomAnchor),
        ])

        updateCommandBar()
    }

    func makeTreeCellView(for node: LayoutsTreeNode) -> NSTableCellView {
        let identifier = NSUserInterfaceItemIdentifier("layout-tree-cell")
        let cellView = (outlineView.makeView(withIdentifier: identifier, owner: self) as? LayoutTreeCellView) ?? LayoutTreeCellView(frame: .zero)
        cellView.identifier = identifier
        cellView.configure(
            title: node.title,
            kind: node.kind,
            icon: treeIcon(for: node),
            iconTintColor: treeIconTintColor(for: node)
        )
        return cellView
    }

    func makeGroupDetailView(group: LayoutGroup, isActive _: Bool) -> NSView {
        let contentStackView = makeSettingsPageStackView()
        let nameControl = makeEditableTextControl(value: group.name, width: 220, isEditable: !group.protect) { [weak self] value in
            self?.renameGroup(from: group.name, to: value)
        }
        currentGroupNameControl = nameControl
        let includeInCycleControl = makeEditableCheckboxControl(isOn: group.includeInGroupCycle) { [weak self] isOn in
            self?.mutateLayoutsDraft(preserving: .group(name: group.name)) { configuration in
                guard let groupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == group.name }) else {
                    return
                }
                configuration.layoutGroups[groupIndex].includeInGroupCycle = isOn
            }
        }
        let includeInCycleDescriptionLabel = makeSecondaryLabel(UICopy.settingsIncludeInGroupCycleDescription)
        let includeInCycleContent = makeControlWithDescription(
            control: includeInCycleControl,
            descriptionLabel: includeInCycleDescriptionLabel
        )
        var rows = [
            makeLabeledControlRow(label: UICopy.settingsNameLabel, control: nameControl),
            makeLabeledControlRow(label: UICopy.settingsIncludeInGroupCycleLabel, control: includeInCycleContent),
        ]
        if group.protect {
            rows.append(
                makeLabeledControlRow(
                    label: UICopy.settingsNoteLabel,
                    control: makeInfoMessageRow(text: UICopy.settingsProtectedGroupInfo)
                )
            )
        }
        let formView = makeInlineTabContent(rows: rows, width: 460)
        contentStackView.addArrangedSubview(makeCenteredContainer(for: formView))
        return makeDetailPanelContainer(contentView: contentStackView)
    }

    func makeSetDetailView(groupName: String, setIndex: Int, set: LayoutSet) -> NSView {
        let contentStackView = makeSettingsPageStackView()
        let applyToControl = ApplyToControlView(
            set: set,
            persistedMonitorMapProvider: { [weak self] in
                self?.prototypeState.currentMonitorNameMap() ?? [:]
            }
        )
        applyToControl.onMonitorChanged = { [weak self] monitor in
            self?.updateSetMonitor(groupName: groupName, setIndex: setIndex, monitor: monitor)
        }
        applyToControl.onRefreshRequested = { [weak self] in
            self?.refreshMonitorMetadata()
        }
        let formView = makeInlineTabContent(rows: [
            makeLabeledControlRow(label: UICopy.settingsApplyToLabel, control: applyToControl),
        ], width: 460)
        contentStackView.addArrangedSubview(makeCenteredContainer(for: formView))
        return makeDetailPanelContainer(contentView: contentStackView)
    }

    func makeLayoutDetailView(groupName: String, setIndex: Int, layout: LayoutPreset) -> NSView {
        let contentStackView = makeSettingsPageStackView()

        let previewView = makeLayoutPreviewView(layout: layout, mode: previewMode(for: selectedLayoutDetailTabIndex))
        currentLayoutPreviewView = previewView
        contentStackView.addArrangedSubview(makeCenteredContainer(for: previewView))

        let triggerContentView = TriggerTabContentView(layout: layout)
        currentLayoutTriggerContentView = triggerContentView
        previewView.triggerRegionOverride = triggerContentView.currentTriggerRegion
        previewView.interactionMode = previewInteractionMode(
            for: selectedLayoutDetailTabIndex,
            triggerAreaKind: triggerContentView.currentTriggerAreaKind
        )
        previewView.onWindowSelectionCommitted = { [weak self] selection in
            self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                draftLayout.windowSelection = selection
            }
        }
        previewView.onTriggerRegionCommitted = { [weak self, weak previewView, weak triggerContentView] triggerRegion in
            triggerContentView?.syncFromTriggerRegion(triggerRegion)
            previewView?.triggerRegionOverride = triggerRegion
            previewView?.interactionMode = self?.previewInteractionMode(
                for: self?.selectedLayoutDetailTabIndex ?? 0,
                triggerAreaKind: triggerContentView?.currentTriggerAreaKind ?? .none
            ) ?? .none
            self?.updateLayoutTriggerRegion(groupName: groupName, setIndex: setIndex, layoutID: layout.id, triggerRegion: triggerRegion)
        }
        triggerContentView.onTriggerAreaKindChanged = { [weak self, weak previewView, weak triggerContentView] _ in
            previewView?.interactionMode = self?.previewInteractionMode(
                for: self?.selectedLayoutDetailTabIndex ?? 0,
                triggerAreaKind: triggerContentView?.currentTriggerAreaKind ?? .none
            ) ?? .none
        }
        triggerContentView.onTriggerRegionChanged = { [weak self, weak previewView] triggerRegion in
            previewView?.triggerRegionOverride = triggerRegion
            self?.updateLayoutTriggerRegion(groupName: groupName, setIndex: setIndex, layoutID: layout.id, triggerRegion: triggerRegion)
        }

        let gridColumnsControl = SettingsIntegerStepperControl(value: layout.gridColumns, minValue: 1, maxValue: nil)
        gridColumnsControl.onValueChanged = { [weak self] value in
            self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                draftLayout.gridColumns = value
            }
        }
        currentLayoutGridColumnsControl = gridColumnsControl

        let gridRowsControl = SettingsIntegerStepperControl(value: layout.gridRows, minValue: 1, maxValue: nil)
        gridRowsControl.onValueChanged = { [weak self] value in
            self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                draftLayout.gridRows = value
            }
        }
        currentLayoutGridRowsControl = gridRowsControl

        let windowXControl = SettingsIntegerStepperControl(
            value: layout.windowSelection.x,
            minValue: 0,
            maxValue: max(0, layout.gridColumns - layout.windowSelection.w)
        )
        windowXControl.onValueChanged = { [weak self] value in
            self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                draftLayout.windowSelection.x = value
            }
        }
        currentLayoutWindowXControl = windowXControl

        let windowYControl = SettingsIntegerStepperControl(
            value: layout.windowSelection.y,
            minValue: 0,
            maxValue: max(0, layout.gridRows - layout.windowSelection.h)
        )
        windowYControl.onValueChanged = { [weak self] value in
            self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                draftLayout.windowSelection.y = value
            }
        }
        currentLayoutWindowYControl = windowYControl

        let windowWidthControl = SettingsIntegerStepperControl(
            value: layout.windowSelection.w,
            minValue: 1,
            maxValue: layout.gridColumns - layout.windowSelection.x
        )
        windowWidthControl.onValueChanged = { [weak self] value in
            self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                draftLayout.windowSelection.w = value
            }
        }
        currentLayoutWindowWidthControl = windowWidthControl

        let windowHeightControl = SettingsIntegerStepperControl(
            value: layout.windowSelection.h,
            minValue: 1,
            maxValue: layout.gridRows - layout.windowSelection.y
        )
        windowHeightControl.onValueChanged = { [weak self] value in
            self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                draftLayout.windowSelection.h = value
            }
        }
        currentLayoutWindowHeightControl = windowHeightControl

        let detailTabsView = SettingsInlineTabsView(
            tabs: [
                SettingsInlineTab(
                    title: UICopy.settingsLayoutInlineTabTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeLabeledControlRow(
                            label: UICopy.settingsNameLabel,
                            control: {
                                let nameControl = makeEditableTextControl(value: layout.name, width: 220) { [weak self] value in
                                    self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                        draftLayout.name = value
                                    }
                                }
                                currentLayoutNameControl = nameControl
                                return nameControl
                            }()
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsIncludeInMenuLabel,
                            control: makeEditableCheckboxControl(isOn: layout.includeInMenu) { [weak self] isOn in
                                self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                    draftLayout.includeInMenu = isOn
                                }
                            }
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsIncludeInLayoutIndexLabel,
                            control: makeEditableCheckboxControl(isOn: layout.includeInLayoutIndex) { [weak self] isOn in
                                self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                    draftLayout.includeInLayoutIndex = isOn
                                }
                            }
                        ),
                        makeLabeledControlRow(label: UICopy.settingsGridColumnsLabel, control: makeGridControlRow(control: gridColumnsControl)),
                        makeLabeledControlRow(label: UICopy.settingsGridRowsLabel, control: makeGridControlRow(control: gridRowsControl)),
                    ], width: 460)
                ),
                SettingsInlineTab(
                    title: UICopy.settingsWindowAreaInlineTabTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeLabeledControlRow(
                            label: UICopy.settingsXPositionLabel,
                            control: makeGridControlRow(control: windowXControl)
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsYPositionLabel,
                            control: makeGridControlRow(control: windowYControl)
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsWidthLabel,
                            control: makeGridControlRow(control: windowWidthControl)
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsHeightLabel,
                            control: makeGridControlRow(control: windowHeightControl)
                        ),
                    ], width: 460)
                ),
                SettingsInlineTab(
                    title: UICopy.settingsTriggerAreaInlineTabTitle,
                    contentView: triggerContentView
                ),
            ],
            selectedIndex: selectedLayoutDetailTabIndex
        )
        detailTabsView.onSelectionChanged = { [weak self, weak previewView] (selectedIndex: Int) in
            self?.selectedLayoutDetailTabIndex = selectedIndex
            previewView?.mode = self?.previewMode(for: selectedIndex) ?? .combined
            previewView?.interactionMode = self?.previewInteractionMode(
                for: selectedIndex,
                triggerAreaKind: triggerContentView.currentTriggerAreaKind
            ) ?? .none
        }

        contentStackView.addArrangedSubview(makeFullWidthContainer(for: detailTabsView))
        return makeDetailPanelContainer(contentView: contentStackView)
    }

    private func makeGridControlRow(control: SettingsIntegerStepperControl) -> NSView {
        let row = makeHorizontalGroup(spacing: 8)
        row.alignment = .centerY
        row.addArrangedSubview(control)
        row.addArrangedSubview(makeFieldLabel("grid"))
        return row
    }

    func makeLayoutPreviewView(layout: LayoutPreset, mode: LayoutPreviewView.Mode) -> LayoutPreviewView {
        let previewView = LayoutPreviewView(layout: layout, appearance: draftConfiguration.appearance, mode: mode)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.widthAnchor.constraint(equalToConstant: 420).isActive = true
        previewView.heightAnchor.constraint(equalToConstant: 260).isActive = true
        return previewView
    }

    func previewMode(for selectedIndex: Int) -> LayoutPreviewView.Mode {
        switch selectedIndex {
        case 1:
            return .windowLayout
        case 2:
            return .triggerRegion
        default:
            return .combined
        }
    }

    func previewInteractionMode(
        for selectedIndex: Int,
        triggerAreaKind: TriggerTabContentView.TriggerAreaKind
    ) -> LayoutPreviewView.InteractionMode {
        switch selectedIndex {
        case 1:
            return .windowSelection
        case 2:
            switch triggerAreaKind {
            case .none:
                return .none
            case .screen:
                return .triggerScreenSelection
            case .menuBar:
                return .triggerMenuBarSelection
            }
        default:
            return .none
        }
    }

    func makeEditableTextControl(
        value: String,
        width: CGFloat,
        isEditable: Bool = true,
        onCommit: @escaping (String) -> Void
    ) -> CallbackTextField {
        let textField = CallbackTextField(string: value)
        textField.controlSize = .small
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: width).isActive = true
        textField.isEditable = isEditable
        textField.isSelectable = isEditable
        textField.isEnabled = true
        textField.onCommit = onCommit
        if isEditable == false {
            textField.textColor = .secondaryLabelColor
            textField.backgroundColor = .controlBackgroundColor
        }
        return textField
    }

    func makeEditableCheckboxControl(isOn: Bool, onToggle: @escaping (Bool) -> Void) -> NSButton {
        let checkbox = CallbackCheckbox()
        checkbox.state = isOn ? .on : .off
        checkbox.onToggle = onToggle
        return checkbox
    }

    func makeDetailPanelContainer(contentView: NSView) -> NSView {
        let containerView = NSView()
        let panelView = NSBox()
        panelView.boxType = .custom
        panelView.titlePosition = .noTitle
        panelView.borderColor = .separatorColor
        panelView.fillColor = .clear
        panelView.cornerRadius = 8
        panelView.contentViewMargins = .zero
        let panelContentView = panelView.contentView!
        contentView.translatesAutoresizingMaskIntoConstraints = false
        panelView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(panelView)
        panelContentView.addSubview(contentView)

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            panelView.topAnchor.constraint(equalTo: containerView.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: panelContentView.leadingAnchor, constant: 18),
            contentView.trailingAnchor.constraint(equalTo: panelContentView.trailingAnchor, constant: -18),
            contentView.topAnchor.constraint(equalTo: panelContentView.topAnchor),
            contentView.bottomAnchor.constraint(lessThanOrEqualTo: panelContentView.bottomAnchor),
        ])

        return containerView
    }

    private func makeInfoMessageRow(text: String) -> NSView {
        let label = makeSecondaryLabel(text)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    func makeCommandBarView() -> NSView {
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(handleAddAction(_:))

        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(handleRemoveAction(_:))

        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(handleSaveLayoutEdits(_:))

        restoreButton.bezelStyle = .rounded
        restoreButton.target = self
        restoreButton.action = #selector(handleRestoreLayoutEdits(_:))

        let row = makeHorizontalGroup(spacing: 8)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.alignment = .centerY
        row.addArrangedSubview(addButton)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(restoreButton)
        row.addArrangedSubview(saveButton)
        row.addArrangedSubview(removeButton)
        containerView.addSubview(row)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
            row.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            row.topAnchor.constraint(equalTo: containerView.topAnchor),
            row.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        return containerView
    }

    func updateCommandBar() {
        switch preferredAddAction(for: selectedNode) {
        case .group:
            addButton.title = UICopy.settingsAddGroupButtonTitle
        case .monitorSet:
            addButton.title = UICopy.settingsAddDisplaySetButtonTitle
        case .layout:
            addButton.title = UICopy.settingsAddLayoutButtonTitle
        case nil:
            addButton.title = UICopy.settingsAddButtonTitle
        }

        saveButton.title = UICopy.settingsSaveButtonTitle
        restoreButton.title = UICopy.settingsRestoreButtonTitle
        removeButton.title = UICopy.settingsRemoveButtonTitle
        saveButton.isEnabled = prototypeState.hasLayoutsDraftChanges
        restoreButton.isHidden = !prototypeState.hasLayoutsDraftChanges
        restoreButton.isEnabled = prototypeState.hasLayoutsDraftChanges
        saveButton.keyEquivalent = saveButton.isEnabled ? "\r" : ""
        saveButton.keyEquivalentModifierMask = []
        if let buttonCell = saveButton.cell as? NSButtonCell {
            view.window?.defaultButtonCell = saveButton.isEnabled ? buttonCell : nil
        }

        let removeState = removeButtonState(for: selectedNode)
        removeButton.isEnabled = removeState.isEnabled
        removeButton.toolTip = removeState.toolTip

        addButton.isEnabled = addActionState(for: selectedNode)
    }
}

@MainActor
final class CallbackTextField: NSTextField, NSTextFieldDelegate {
    var onCommit: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        delegate = self
    }

    convenience init(string value: String) {
        self.init(frame: .zero)
        stringValue = value
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        onCommit?(stringValue)
    }
}

extension CallbackTextField {
    func setRawValueForTesting(_ value: String) {
        window?.makeFirstResponder(self)
        stringValue = value
    }
}

@MainActor
private final class CallbackCheckbox: NSButton {
    var onToggle: ((Bool) -> Void)?

    init() {
        super.init(frame: .zero)
        setButtonType(.switch)
        title = ""
        target = self
        action = #selector(handleToggle(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    @objc
    private func handleToggle(_ sender: NSButton) {
        onToggle?(sender.state == .on)
    }
}
