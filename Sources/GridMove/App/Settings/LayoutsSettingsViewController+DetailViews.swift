import AppKit

@MainActor
extension LayoutsSettingsViewController {
    func updateDetailView() {
        currentGroupNameControl = nil
        currentSetApplyToControl = nil
        currentLayoutNameControl = nil
        currentLayoutGridColumnsControl = nil
        currentLayoutGridRowsControl = nil
        currentLayoutWindowXControl = nil
        currentLayoutWindowYControl = nil
        currentLayoutWindowWidthControl = nil
        currentLayoutWindowHeightControl = nil
        detailContainerView.subviews.forEach { $0.removeFromSuperview() }
        currentLayoutPreviewView = nil
        currentLayoutTriggerContentViews = []

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
        contentStackView.alignment = .centerX
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
            makeCenteredLabeledControlRow(label: UICopy.settingsNameLabel, control: nameControl),
            makeCenteredLabeledControlRow(label: UICopy.settingsIncludeInGroupCycleLabel, control: includeInCycleContent),
        ]
        if group.protect {
            rows.append(
                makeCenteredLabeledControlRow(
                    label: UICopy.settingsNoteLabel,
                    control: makeInfoMessageRow(text: UICopy.settingsProtectedGroupInfo)
                )
            )
        }
        let formView = makeInlineTabContent(rows: rows)
        contentStackView.addArrangedSubview(makeDetailContentContainer(for: formView))
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
        currentSetApplyToControl = applyToControl
        contentStackView.alignment = .centerX
        let formView = makeInlineTabContent(rows: [
            makeCenteredLabeledControlRow(label: UICopy.settingsApplyToLabel, control: applyToControl),
        ])
        contentStackView.addArrangedSubview(makeDetailContentContainer(for: formView))
        return makeDetailPanelContainer(contentView: contentStackView)
    }

    func makeLayoutDetailView(groupName: String, setIndex: Int, layout: LayoutPreset) -> NSView {
        let contentStackView = makeSettingsPageStackView()

        let previewView = makeLayoutPreviewView(layout: layout, mode: previewMode(for: selectedLayoutDetailTabIndex))
        currentLayoutPreviewView = previewView
        contentStackView.addArrangedSubview(makeCenteredContainer(for: previewView))

        let triggerCount = max(1, layout.triggerRegions.count)
        var triggerContentViews: [TriggerTabContentView] = []
        for triggerIndex in 0..<triggerCount {
            let region = layout.triggerRegions.indices.contains(triggerIndex) ? layout.triggerRegions[triggerIndex] : nil
            let contentView = TriggerTabContentView(
                triggerRegion: region,
                gridColumns: layout.gridColumns,
                gridRows: layout.gridRows,
                allowNone: triggerCount == 1,
                triggerCount: triggerCount
            )
            contentView.onTriggerAreaKindChanged = { [weak self, weak previewView, weak contentView] _ in
                guard let self else { return }
                let activeTab = self.selectedLayoutDetailTabIndex
                guard activeTab - 2 == triggerIndex else { return }
                previewView?.interactionMode = self.previewInteractionMode(
                    for: activeTab,
                    triggerAreaKind: contentView?.currentTriggerAreaKind ?? .none
                )
            }
            contentView.onTriggerRegionChanged = { [weak self, weak previewView] triggerRegion in
                guard let self else { return }
                let activeTab = self.selectedLayoutDetailTabIndex
                if activeTab - 2 == triggerIndex {
                    previewView?.triggerRegionOverride = triggerRegion
                }
                if let triggerRegion {
                    self.updateLayoutTriggerRegion(
                        groupName: groupName, setIndex: setIndex, layoutID: layout.id,
                        atIndex: triggerIndex, region: triggerRegion
                    )
                } else {
                    self.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                        draftLayout.triggerRegions = []
                    }
                }
            }
            contentView.onAddTriggerRegion = { [weak self] in
                self?.addTriggerRegion(groupName: groupName, setIndex: setIndex, layoutID: layout.id, after: triggerIndex)
            }
            contentView.onRemoveTriggerRegion = { [weak self] in
                self?.removeTriggerRegion(groupName: groupName, setIndex: setIndex, layoutID: layout.id, atIndex: triggerIndex)
            }
            triggerContentViews.append(contentView)
        }
        currentLayoutTriggerContentViews = triggerContentViews

        let activeTriggerIndex = selectedLayoutDetailTabIndex - 2
        if triggerContentViews.indices.contains(activeTriggerIndex) {
            previewView.triggerRegionOverride = triggerContentViews[activeTriggerIndex].currentTriggerRegion
            previewView.interactionMode = previewInteractionMode(
                for: selectedLayoutDetailTabIndex,
                triggerAreaKind: triggerContentViews[activeTriggerIndex].currentTriggerAreaKind
            )
        } else {
            previewView.interactionMode = previewInteractionMode(for: selectedLayoutDetailTabIndex, triggerAreaKind: .none)
        }

        previewView.onWindowSelectionCommitted = { [weak self] selection in
            self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                draftLayout.windowSelection = selection
            }
        }
        previewView.onTriggerRegionCommitted = { [weak self, weak previewView] triggerRegion in
            guard let self else { return }
            let activeTrigger = self.selectedLayoutDetailTabIndex - 2
            let clampedIndex = max(0, activeTrigger)
            let activeView = triggerContentViews.indices.contains(clampedIndex) ? triggerContentViews[clampedIndex] : nil
            activeView?.syncFromTriggerRegion(triggerRegion)
            previewView?.triggerRegionOverride = triggerRegion
            previewView?.interactionMode = self.previewInteractionMode(
                for: self.selectedLayoutDetailTabIndex,
                triggerAreaKind: activeView?.currentTriggerAreaKind ?? .none
            )
            self.updateLayoutTriggerRegion(
                groupName: groupName, setIndex: setIndex, layoutID: layout.id,
                atIndex: clampedIndex, region: triggerRegion
            )
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

        let triggerTabTitles: [String] = {
            if triggerCount == 1 {
                return [UICopy.settingsTriggerAreaInlineTabTitle]
            }
            return [
                UICopy.settingsTriggerArea1InlineTabTitle,
                UICopy.settingsTriggerArea2InlineTabTitle,
                UICopy.settingsTriggerArea3InlineTabTitle,
            ].prefix(triggerCount).map { $0 }
        }()

        let triggerTabs: [SettingsInlineTab] = triggerContentViews.enumerated().map { index, contentView in
            SettingsInlineTab(title: triggerTabTitles[index], contentView: contentView)
        }

        let detailTabsView = SettingsInlineTabsView(
            tabs: [
                SettingsInlineTab(
                    title: UICopy.settingsLayoutInlineTabTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeCenteredLabeledControlRow(
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
                        makeCenteredLabeledControlRow(
                            label: UICopy.settingsIncludeInMenuLabel,
                            control: makeEditableCheckboxControl(isOn: layout.includeInMenu) { [weak self] isOn in
                                self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                    draftLayout.includeInMenu = isOn
                                }
                            }
                        ),
                        makeCenteredLabeledControlRow(
                            label: UICopy.settingsIncludeInLayoutIndexLabel,
                            control: makeEditableCheckboxControl(isOn: layout.includeInLayoutIndex) { [weak self] isOn in
                                self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                    draftLayout.includeInLayoutIndex = isOn
                                }
                            }
                        ),
                        makeCenteredLabeledControlRow(label: UICopy.settingsGridColumnsLabel, control: makeGridControlRow(control: gridColumnsControl)),
                        makeCenteredLabeledControlRow(label: UICopy.settingsGridRowsLabel, control: makeGridControlRow(control: gridRowsControl)),
                    ], width: 460)
                ),
                SettingsInlineTab(
                    title: UICopy.settingsWindowAreaInlineTabTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeCenteredLabeledControlRow(
                            label: UICopy.settingsXPositionLabel,
                            control: makeGridControlRow(control: windowXControl)
                        ),
                        makeCenteredLabeledControlRow(
                            label: UICopy.settingsYPositionLabel,
                            control: makeGridControlRow(control: windowYControl)
                        ),
                        makeCenteredLabeledControlRow(
                            label: UICopy.settingsWidthLabel,
                            control: makeGridControlRow(control: windowWidthControl)
                        ),
                        makeCenteredLabeledControlRow(
                            label: UICopy.settingsHeightLabel,
                            control: makeGridControlRow(control: windowHeightControl)
                        ),
                    ], width: 460)
                ),
            ] + triggerTabs,
            selectedIndex: selectedLayoutDetailTabIndex
        )
        detailTabsView.onSelectionChanged = { [weak self, weak previewView] (selectedIndex: Int) in
            guard let self else { return }
            self.selectedLayoutDetailTabIndex = selectedIndex
            previewView?.mode = self.previewMode(for: selectedIndex)
            let triggerIdx = selectedIndex - 2
            if triggerContentViews.indices.contains(triggerIdx) {
                previewView?.triggerRegionOverride = triggerContentViews[triggerIdx].currentTriggerRegion
                previewView?.interactionMode = self.previewInteractionMode(
                    for: selectedIndex,
                    triggerAreaKind: triggerContentViews[triggerIdx].currentTriggerAreaKind
                )
            } else {
                previewView?.interactionMode = self.previewInteractionMode(for: selectedIndex, triggerAreaKind: .none)
            }
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

    private func makeDetailContentContainer(for view: NSView) -> NSView {
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

    func makeLayoutPreviewView(layout: LayoutPreset, mode: LayoutPreviewView.Mode) -> LayoutPreviewView {
        let previewView = LayoutPreviewView(layout: layout, appearance: draftConfiguration.appearance, mode: mode)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        let preferredWidthConstraint = previewView.widthAnchor.constraint(equalToConstant: 420)
        preferredWidthConstraint.priority = .defaultHigh
        preferredWidthConstraint.isActive = true
        previewView.heightAnchor.constraint(equalToConstant: 260).isActive = true
        return previewView
    }

    func previewMode(for selectedIndex: Int) -> LayoutPreviewView.Mode {
        switch selectedIndex {
        case 1:
            return .windowLayout
        case _ where selectedIndex >= 2:
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
        case _ where selectedIndex >= 2:
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
        let preferredWidthConstraint = textField.widthAnchor.constraint(equalToConstant: width)
        preferredWidthConstraint.priority = .defaultHigh
        preferredWidthConstraint.isActive = true
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
        row.addArrangedSubview(removeButton)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(restoreButton)
        row.addArrangedSubview(saveButton)
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
        removeButton.title = "-"
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
