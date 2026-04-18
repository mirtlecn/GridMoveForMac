import AppKit

@MainActor
final class LayoutsSettingsViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSSplitViewDelegate {
    private enum SplitViewMetrics {
        static let preferredSidebarWidth: CGFloat = 250
        static let minimumSidebarWidth: CGFloat = 210
        static let preferredDetailWidth: CGFloat = 700
        static let minimumDetailWidth: CGFloat = 520
    }

    private enum DragPasteboard {
        static let layoutType = NSPasteboard.PasteboardType("com.mirtle.gridmove.settings.layout")
    }

    private enum NodeSelection: Equatable {
        case group(name: String)
        case set(groupName: String, setIndex: Int)
        case layout(id: String)
    }

    private enum AddAction {
        case group
        case monitorSet
        case layout
    }

    private let prototypeState: SettingsPrototypeState
    private let actionHandler: any SettingsActionHandling
    private var draftConfiguration: AppConfiguration
    private let outlineView = LayoutsOutlineView()
    private let sidebarScrollView = NSScrollView()
    private let detailContainerView = NSView()
    private let splitView = NSSplitView()
    private let addButton = NSButton(title: UICopy.settingsAddLayoutButtonTitle, target: nil, action: nil)
    private let removeButton = NSButton(title: UICopy.settingsRemoveButtonTitle, target: nil, action: nil)
    private let saveButton = NSButton(title: UICopy.settingsSaveButtonTitle, target: nil, action: nil)
    private var treeNodes: [LayoutsTreeNode]
    private var hasAppliedInitialSplitPosition = false
    private var pendingSelection: NodeSelection?
    private var selectedLayoutDetailTabIndex = 0

    init(prototypeState: SettingsPrototypeState, actionHandler: any SettingsActionHandling) {
        self.prototypeState = prototypeState
        self.actionHandler = actionHandler
        self.draftConfiguration = prototypeState.configuration
        self.treeNodes = LayoutsTreeNode.makeTree(
            configuration: prototypeState.configuration,
            monitorMap: prototypeState.currentMonitorNameMap()
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        configureOutlineView()

        sidebarScrollView.borderType = .bezelBorder
        sidebarScrollView.hasVerticalScroller = true
        sidebarScrollView.hasHorizontalScroller = false
        sidebarScrollView.documentView = outlineView
        sidebarScrollView.translatesAutoresizingMaskIntoConstraints = false

        detailContainerView.translatesAutoresizingMaskIntoConstraints = false
        detailContainerView.widthAnchor.constraint(greaterThanOrEqualToConstant: SplitViewMetrics.minimumDetailWidth).isActive = true
        let preferredDetailWidthConstraint = detailContainerView.widthAnchor.constraint(equalToConstant: SplitViewMetrics.preferredDetailWidth)
        preferredDetailWidthConstraint.priority = .defaultLow
        preferredDetailWidthConstraint.isActive = true

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.delegate = self
        splitView.addArrangedSubview(sidebarScrollView)
        splitView.addArrangedSubview(detailContainerView)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)

        let commandBarView = makeCommandBarView()
        let containerView = NSView()
        containerView.addSubview(splitView)
        containerView.addSubview(commandBarView)

        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            splitView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            splitView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            splitView.bottomAnchor.constraint(equalTo: commandBarView.topAnchor, constant: -12),
            commandBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            commandBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            commandBarView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
        ])

        view = containerView
        title = UICopy.settingsLayoutsTabTitle
        observePrototypeState()

        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
        selectFallbackNodeIfNeeded()
        updateCommandBar()
    }

    private func observePrototypeState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePrototypeStateDidChangeNotification(_:)),
            name: .settingsPrototypeStateDidChange,
            object: prototypeState
        )
    }

    @objc
    private func handlePrototypeStateDidChangeNotification(_ notification: Notification) {
        let preservedSelection = pendingSelection ?? selectedNode.map(selectionKey(for:))
        pendingSelection = nil
        draftConfiguration = prototypeState.configuration
        reloadTree(preserving: preservedSelection)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        guard !hasAppliedInitialSplitPosition, splitView.subviews.count >= 2 else {
            return
        }

        let maximumSidebarWidth = splitView.bounds.width - SplitViewMetrics.minimumDetailWidth - splitView.dividerThickness
        let sidebarWidth = min(
            SplitViewMetrics.preferredSidebarWidth,
            max(SplitViewMetrics.minimumSidebarWidth, maximumSidebarWidth)
        )
        splitView.setPosition(sidebarWidth, ofDividerAt: 0)
        hasAppliedInitialSplitPosition = true
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let node = item as? LayoutsTreeNode
        return (node?.children ?? treeNodes).count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? LayoutsTreeNode else {
            return false
        }
        return !node.children.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let node = item as? LayoutsTreeNode
        return (node?.children ?? treeNodes)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? LayoutsTreeNode else {
            return nil
        }
        return makeTreeCellView(for: node)
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard selectedNode != nil else {
            detailContainerView.subviews.forEach { $0.removeFromSuperview() }
            updateCommandBar()
            return
        }
        updateDetailView()
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        SplitViewMetrics.minimumSidebarWidth
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        max(
            SplitViewMetrics.minimumSidebarWidth,
            splitView.bounds.width - SplitViewMetrics.minimumDetailWidth - splitView.dividerThickness
        )
    }

    private var selectedNode: LayoutsTreeNode? {
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0 else {
            return nil
        }
        return outlineView.item(atRow: selectedRow) as? LayoutsTreeNode
    }

    private func configureOutlineView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("layouts"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.rowHeight = 24
        outlineView.indentationPerLevel = 14
        outlineView.selectionHighlightStyle = .regular
        outlineView.focusRingType = .none
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
        outlineView.registerForDraggedTypes([DragPasteboard.layoutType])
    }

    private func selectFallbackNodeIfNeeded() {
        guard outlineView.selectedRow < 0,
              let defaultSelection = firstAvailableSelection(in: treeNodes) else {
            return
        }
        reloadTree(preserving: defaultSelection)
    }

    private func firstAvailableSelection(in nodes: [LayoutsTreeNode]) -> NodeSelection? {
        for node in nodes {
            if node.children.isEmpty {
                return selectionKey(for: node)
            }
            if let childSelection = firstAvailableSelection(in: node.children) {
                return childSelection
            }
            return selectionKey(for: node)
        }
        return nil
    }

    private func updateDetailView() {
        detailContainerView.subviews.forEach { $0.removeFromSuperview() }

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

    private func makeTreeCellView(for node: LayoutsTreeNode) -> NSTableCellView {
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

    private func makeGroupDetailView(group: LayoutGroup, isActive: Bool) -> NSView {
        let contentStackView = makeSettingsPageStackView()
        let nameControl = makeEditableTextControl(value: group.name, width: 220, isEditable: !group.protect) { [weak self] value in
            self?.renameGroup(from: group.name, to: value)
        }
        let includeInCycleControl = makeEditableCheckboxControl(isOn: group.includeInGroupCycle) { [weak self] isOn in
            self?.mutateLayoutsDraft(preserving: .group(name: group.name)) { configuration in
                guard let groupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == group.name }) else {
                    return
                }
                configuration.layoutGroups[groupIndex].includeInGroupCycle = isOn
            }
        }
        let activeGroupControl = makeActiveGroupControl(groupName: group.name, isActive: isActive)

        let formView = makeInlineTabContent(rows: [
            makeLabeledControlRow(label: UICopy.settingsNameLabel, control: nameControl),
            makeLabeledControlRow(label: UICopy.settingsIncludeInGroupCycleLabel, control: includeInCycleControl),
            makeLabeledControlRow(label: UICopy.settingsActiveGroupLabel, control: activeGroupControl),
        ], width: 460)
        contentStackView.addArrangedSubview(makeCenteredContainer(for: formView))
        return makeDetailPanelContainer(contentView: contentStackView)
    }

    private func makeActiveGroupControl(groupName: String, isActive: Bool) -> NSButton {
        let checkbox = makeEditableCheckboxControl(isOn: isActive) { [weak self] isOn in
            self?.handleActiveGroupToggle(groupName: groupName, isOn: isOn)
        }
        return checkbox
    }

    private func handleActiveGroupToggle(groupName: String, isOn: Bool) {
        guard isOn else {
            updateDetailView()
            return
        }

        guard draftConfiguration.general.activeLayoutGroup != groupName else {
            return
        }

        mutateLayoutsDraft(preserving: .group(name: groupName)) { configuration in
            configuration.general.activeLayoutGroup = groupName
        }
    }

    private func makeSetDetailView(groupName: String, setIndex: Int, set: LayoutSet) -> NSView {
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

    private func makeLayoutDetailView(groupName: String, setIndex: Int, layout: LayoutPreset) -> NSView {
        let contentStackView = makeSettingsPageStackView()

        let previewView = makeLayoutPreviewView(layout: layout, mode: previewMode(for: selectedLayoutDetailTabIndex))
        contentStackView.addArrangedSubview(makeCenteredContainer(for: previewView))

        let triggerContentView = TriggerTabContentView(layout: layout)
        previewView.triggerRegionOverride = triggerContentView.currentTriggerRegion
        triggerContentView.onTriggerRegionChanged = { [weak self, weak previewView] triggerRegion in
            previewView?.triggerRegionOverride = triggerRegion
            self?.updateLayoutTriggerRegion(groupName: groupName, setIndex: setIndex, layoutID: layout.id, triggerRegion: triggerRegion)
        }

        let detailTabsView = SettingsInlineTabsView(
            tabs: [
                SettingsInlineTab(
                    title: UICopy.settingsLayoutInlineTabTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeLabeledControlRow(
                            label: UICopy.settingsNameLabel,
                            control: makeEditableTextControl(value: layout.name, width: 220) { [weak self] value in
                                self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                    draftLayout.name = value
                                }
                            }
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
                        makeLabeledControlRow(
                            label: UICopy.settingsGridColumnsLabel,
                            control: makeNumericStepperControl(
                                value: layout.gridColumns,
                                unit: "grid",
                                minValue: 1,
                                maxValue: 24,
                                onValueChanged: { [weak self] value in
                                    self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                        draftLayout.gridColumns = value
                                    }
                                }
                            )
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsGridRowsLabel,
                            control: makeNumericStepperControl(
                                value: layout.gridRows,
                                unit: "grid",
                                minValue: 1,
                                maxValue: 24,
                                onValueChanged: { [weak self] value in
                                    self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                        draftLayout.gridRows = value
                                    }
                                }
                            )
                        ),
                    ], width: 460)
                ),
                SettingsInlineTab(
                    title: UICopy.settingsWindowAreaInlineTabTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeLabeledControlRow(
                            label: UICopy.settingsXPositionLabel,
                            control: makeNumericStepperControl(
                                value: layout.windowSelection.x,
                                unit: "grid",
                                minValue: 0,
                                maxValue: max(0, layout.gridColumns - 1),
                                onValueChanged: { [weak self] value in
                                    self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                        draftLayout.windowSelection.x = value
                                    }
                                }
                            )
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsYPositionLabel,
                            control: makeNumericStepperControl(
                                value: layout.windowSelection.y,
                                unit: "grid",
                                minValue: 0,
                                maxValue: max(0, layout.gridRows - 1),
                                onValueChanged: { [weak self] value in
                                    self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                        draftLayout.windowSelection.y = value
                                    }
                                }
                            )
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsWidthLabel,
                            control: makeNumericStepperControl(
                                value: layout.windowSelection.w,
                                unit: "grid",
                                minValue: 1,
                                maxValue: layout.gridColumns,
                                onValueChanged: { [weak self] value in
                                    self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                        draftLayout.windowSelection.w = value
                                    }
                                }
                            )
                        ),
                        makeLabeledControlRow(
                            label: UICopy.settingsHeightLabel,
                            control: makeNumericStepperControl(
                                value: layout.windowSelection.h,
                                unit: "grid",
                                minValue: 1,
                                maxValue: layout.gridRows,
                                onValueChanged: { [weak self] value in
                                    self?.updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layout.id) { draftLayout in
                                        draftLayout.windowSelection.h = value
                                    }
                                }
                            )
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
        detailTabsView.onSelectionChanged = { [weak self, weak previewView] selectedIndex in
            self?.selectedLayoutDetailTabIndex = selectedIndex
            previewView?.mode = self?.previewMode(for: selectedIndex) ?? .combined
        }

        contentStackView.addArrangedSubview(makeFullWidthContainer(for: detailTabsView))
        return makeDetailPanelContainer(contentView: contentStackView)
    }

    private func makeLayoutPreviewView(layout: LayoutPreset, mode: LayoutPreviewView.Mode) -> LayoutPreviewView {
        let previewView = LayoutPreviewView(layout: layout, appearance: draftConfiguration.appearance, mode: mode)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.widthAnchor.constraint(equalToConstant: 420).isActive = true
        previewView.heightAnchor.constraint(equalToConstant: 260).isActive = true
        return previewView
    }

    private func previewMode(for selectedIndex: Int) -> LayoutPreviewView.Mode {
        switch selectedIndex {
        case 1:
            return .windowLayout
        case 2:
            return .triggerRegion
        default:
            return .combined
        }
    }

    private func makeEditableTextControl(
        value: String,
        width: CGFloat,
        isEditable: Bool = true,
        onCommit: @escaping (String) -> Void
    ) -> NSTextField {
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

    private func makeEditableCheckboxControl(isOn: Bool, onToggle: @escaping (Bool) -> Void) -> NSButton {
        let checkbox = CallbackCheckbox()
        checkbox.state = isOn ? .on : .off
        checkbox.onToggle = onToggle
        return checkbox
    }

    private func makeDetailPanelContainer(contentView: NSView) -> NSView {
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
            contentView.topAnchor.constraint(equalTo: panelContentView.topAnchor, constant: 18),
            contentView.bottomAnchor.constraint(lessThanOrEqualTo: panelContentView.bottomAnchor),
        ])

        return containerView
    }

    private func makeCommandBarView() -> NSView {
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

        let row = makeHorizontalGroup(spacing: 8)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.alignment = .centerY
        row.addArrangedSubview(addButton)
        row.addArrangedSubview(NSView())
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

    private func updateCommandBar() {
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
        removeButton.title = UICopy.settingsRemoveButtonTitle
        saveButton.isEnabled = prototypeState.hasLayoutsDraftChanges

        let removeState = removeButtonState(for: selectedNode)
        removeButton.isEnabled = removeState.isEnabled
        removeButton.toolTip = removeState.toolTip

        addButton.isEnabled = addActionState(for: selectedNode)
    }

    @objc
    private func handleSaveLayoutEdits(_ sender: NSButton) {
        _ = prototypeState.commitLayoutsDraft(using: actionHandler)
    }

    @objc
    private func handleAddAction(_ sender: NSButton) {
        guard let selectedNode,
              let addAction = preferredAddAction(for: selectedNode) else {
            return
        }

        switch addAction {
        case .group:
            addGroup()
        case .monitorSet:
            guard let groupName = groupNameForAddAction(from: selectedNode) else {
                return
            }
            addMonitorSet(toGroupNamed: groupName)
        case .layout:
            guard let setContext = setContextForAddAction(from: selectedNode) else {
                return
            }
            addLayout(toGroupNamed: setContext.groupName, setIndex: setContext.setIndex)
        }
    }

    @objc
    private func handleRemoveAction(_ sender: NSButton) {
        guard let selectedNode, removeButton.isEnabled else {
            return
        }
        presentRemoveConfirmation(for: selectedNode)
    }

    private func presentRemoveConfirmation(for node: LayoutsTreeNode) {
        let alert = NSAlert()
        alert.messageText = UICopy.settingsRemoveButtonTitle
        alert.informativeText = "This change stays in draft mode until you click Save."
        alert.alertStyle = .warning
        alert.addButton(withTitle: UICopy.settingsRemoveButtonTitle)
        alert.addButton(withTitle: UICopy.settingsCancelButtonTitle)

        let performRemoval = { [weak self] in
            self?.removeNode(node)
        }

        if let window = view.window {
            alert.beginSheetModal(for: window) { response in
                guard response == .alertFirstButtonReturn else {
                    return
                }
                performRemoval()
            }
            return
        }

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }
        performRemoval()
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
        guard self.outlineView.isCurrentMouseDownInLayoutDragHandle,
              let node = item as? LayoutsTreeNode,
              case let .layout(groupName, setIndex, layout, _) = node.kind else {
            return nil
        }

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(
            [groupName, String(setIndex), layout.id].joined(separator: "\t"),
            forType: DragPasteboard.layoutType
        )
        return pasteboardItem
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        validateDrop info: NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        guard let dragContext = dragContext(from: info) else {
            return []
        }

        let draggingPoint = outlineView.convert(info.draggingLocation, from: nil)
        guard let dropTarget = dropTarget(for: item, childIndex: index, draggingPoint: draggingPoint),
              dragContext.groupName == dropTarget.groupName,
              dragContext.setIndex == dropTarget.setIndex else {
            return []
        }

        outlineView.setDropItem(itemForSet(groupName: dropTarget.groupName, setIndex: dropTarget.setIndex), dropChildIndex: dropTarget.childIndex)
        return .move
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        acceptDrop info: NSDraggingInfo,
        item: Any?,
        childIndex index: Int
    ) -> Bool {
        guard let dragContext = dragContext(from: info),
              let dropTarget = dropTarget(
                for: item,
                childIndex: index,
                draggingPoint: outlineView.convert(info.draggingLocation, from: nil)
              ),
              dragContext.groupName == dropTarget.groupName,
              dragContext.setIndex == dropTarget.setIndex else {
            return false
        }

        return moveLayout(
            id: dragContext.layoutID,
            groupName: dragContext.groupName,
            setIndex: dragContext.setIndex,
            toLocalIndex: dropTarget.childIndex
        )
    }

    private func treeIcon(for node: LayoutsTreeNode) -> NSImage? {
        let symbolName: String = switch node.kind {
        case .group(_, let isActive):
            isActive ? "checkmark.circle.fill" : "square.stack.3d.up"
        case .set:
            "display"
        case .layout:
            "rectangle.inset.filled"
        }
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    private func treeIconTintColor(for node: LayoutsTreeNode) -> NSColor? {
        switch node.kind {
        case .group(_, let isActive):
            return isActive ? .controlAccentColor : nil
        default:
            return nil
        }
    }

    private func reloadTree(preserving selection: NodeSelection?) {
        treeNodes = LayoutsTreeNode.makeTree(
            configuration: draftConfiguration,
            monitorMap: prototypeState.currentMonitorNameMap()
        )
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)

        let effectiveSelection = selection ?? firstAvailableSelection(in: treeNodes)
        guard let effectiveSelection,
              let node = findNode(matching: effectiveSelection, in: treeNodes) else {
            detailContainerView.subviews.forEach { $0.removeFromSuperview() }
            updateCommandBar()
            return
        }

        let row = outlineView.row(forItem: node)
        guard row >= 0 else {
            return
        }

        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
        updateDetailView()
    }

    private func findNode(matching selection: NodeSelection, in nodes: [LayoutsTreeNode]) -> LayoutsTreeNode? {
        for node in nodes {
            if selectionKey(for: node) == selection {
                return node
            }
            if let childMatch = findNode(matching: selection, in: node.children) {
                return childMatch
            }
        }
        return nil
    }

    private func selectionKey(for node: LayoutsTreeNode) -> NodeSelection {
        switch node.kind {
        case let .group(group, _):
            return .group(name: group.name)
        case let .set(groupName, setIndex, _):
            return .set(groupName: groupName, setIndex: setIndex)
        case let .layout(_, _, layout, _):
            return .layout(id: layout.id)
        }
    }

    private struct DragContext {
        let groupName: String
        let setIndex: Int
        let layoutID: String
    }

    private struct DropTarget {
        let groupName: String
        let setIndex: Int
        let childIndex: Int
    }

    private func dragContext(from info: NSDraggingInfo) -> DragContext? {
        guard let rawValue = info.draggingPasteboard.string(forType: DragPasteboard.layoutType) else {
            return nil
        }
        let components = rawValue.components(separatedBy: "\t")
        guard components.count == 3, let setIndex = Int(components[1]) else {
            return nil
        }
        return DragContext(groupName: components[0], setIndex: setIndex, layoutID: components[2])
    }

    private func dropTarget(for item: Any?, childIndex index: Int, draggingPoint: NSPoint) -> DropTarget? {
        guard let node = item as? LayoutsTreeNode else {
            return nil
        }

        switch node.kind {
        case let .set(groupName, setIndex, _):
            let boundedIndex = max(0, min(index, node.children.count))
            return DropTarget(groupName: groupName, setIndex: setIndex, childIndex: boundedIndex)
        case let .layout(groupName, setIndex, _, _):
            guard let parentNode = outlineView.parent(forItem: node) as? LayoutsTreeNode,
                  case .set = parentNode.kind,
                  let sourceIndex = parentNode.children.firstIndex(where: { $0 === node }) else {
                return nil
            }
            let row = outlineView.row(forItem: node)
            guard row >= 0 else {
                return nil
            }
            let rowFrame = outlineView.frameOfCell(atColumn: 0, row: row)
            let insertAfter = draggingPoint.y < rowFrame.midY
            return DropTarget(groupName: groupName, setIndex: setIndex, childIndex: sourceIndex + (insertAfter ? 1 : 0))
        case .group:
            return nil
        }
    }

    private func itemForSet(groupName: String, setIndex: Int) -> LayoutsTreeNode? {
        treeNodes.first(where: {
            if case let .group(group, _) = $0.kind {
                return group.name == groupName
            }
            return false
        })?.children[safe: setIndex]
    }

    private func mutateLayoutsDraft(preserving selection: NodeSelection?, _ mutate: (inout AppConfiguration) -> Void) {
        pendingSelection = selection
        prototypeState.applyLayoutsMutation(mutate)
    }

    private func renameGroup(from oldName: String, to proposedName: String) {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            updateDetailView()
            return
        }

        let normalizedName = trimmedName
        if normalizedName == oldName {
            return
        }

        guard draftConfiguration.layoutGroups.contains(where: { $0.name == normalizedName }) == false else {
            updateDetailView()
            return
        }

        mutateLayoutsDraft(preserving: .group(name: normalizedName)) { configuration in
            guard let groupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == oldName }) else {
                return
            }
            configuration.layoutGroups[groupIndex].name = normalizedName
            if configuration.general.activeLayoutGroup == oldName {
                configuration.general.activeLayoutGroup = normalizedName
            }
        }
    }

    private func updateSetMonitor(groupName: String, setIndex: Int, monitor: LayoutSetMonitor) {
        guard canAssignMonitor(monitor, toSetAt: setIndex, inGroupNamed: groupName) else {
            reloadTree(preserving: .set(groupName: groupName, setIndex: setIndex))
            return
        }

        mutateLayoutsDraft(preserving: .set(groupName: groupName, setIndex: setIndex)) { configuration in
            guard let groupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == groupName }),
                  configuration.layoutGroups[groupIndex].sets.indices.contains(setIndex) else {
                return
            }
            configuration.layoutGroups[groupIndex].sets[setIndex].monitor = monitor
        }
    }

    private func refreshMonitorMetadata() {
        guard let refreshedConfiguration = actionHandler.refreshMonitorMetadata() else {
            return
        }
        prototypeState.syncExternalConfiguration(refreshedConfiguration)
    }

    private func updateLayoutTriggerRegion(groupName: String, setIndex: Int, layoutID: String, triggerRegion: TriggerRegion?) {
        updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layoutID) { draftLayout in
            draftLayout.triggerRegion = triggerRegion
        }
    }

    private func updateLayout(
        groupName: String,
        setIndex: Int,
        layoutID: String,
        mutate: @escaping (inout LayoutPreset) -> Void
    ) {
        mutateLayoutsDraft(preserving: .layout(id: layoutID)) { configuration in
            guard let layoutPath = self.layoutPath(for: layoutID, groupName: groupName, setIndex: setIndex, in: configuration) else {
                return
            }
            mutate(&configuration.layoutGroups[layoutPath.groupIndex].sets[layoutPath.setIndex].layouts[layoutPath.layoutIndex])
            self.normalizeLayout(
                &configuration.layoutGroups[layoutPath.groupIndex].sets[layoutPath.setIndex].layouts[layoutPath.layoutIndex]
            )
        }
    }

    private func addGroup() {
        let groupName = nextAvailableGroupName()
        let newGroup = LayoutGroup(
            name: groupName,
            includeInGroupCycle: false,
            protect: false,
            sets: [LayoutSet(monitor: .all, layouts: [])]
        )
        mutateLayoutsDraft(preserving: .group(name: groupName)) { configuration in
            configuration.layoutGroups.append(newGroup)
        }
    }

    private func addMonitorSet(toGroupNamed groupName: String) {
        guard let monitor = suggestedMonitorForNewSet(inGroupNamed: groupName) else {
            return
        }
        mutateLayoutsDraft(preserving: .set(groupName: groupName, setIndex: nextSetIndex(inGroupNamed: groupName))) { configuration in
            guard let groupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == groupName }) else {
                return
            }
            configuration.layoutGroups[groupIndex].sets.append(LayoutSet(monitor: monitor, layouts: []))
        }
    }

    private func addLayout(toGroupNamed groupName: String, setIndex: Int) {
        let templateLayout = AppConfiguration.defaultLayouts[3]
        let newLayout = LayoutPreset(
            id: nextLayoutID(),
            name: "",
            gridColumns: templateLayout.gridColumns,
            gridRows: templateLayout.gridRows,
            windowSelection: templateLayout.windowSelection,
            triggerRegion: templateLayout.triggerRegion,
            includeInLayoutIndex: templateLayout.includeInLayoutIndex,
            includeInMenu: templateLayout.includeInMenu
        )
        mutateLayoutsDraft(preserving: .layout(id: newLayout.id)) { configuration in
            guard let groupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == groupName }),
                  configuration.layoutGroups[groupIndex].sets.indices.contains(setIndex) else {
                return
            }
            configuration.layoutGroups[groupIndex].sets[setIndex].layouts.append(newLayout)
        }
    }

    private func nextSetIndex(inGroupNamed groupName: String) -> Int {
        draftConfiguration.layoutGroups.first(where: { $0.name == groupName })?.sets.count ?? 0
    }

    private func nextAvailableGroupName() -> String {
        var index = 1
        while draftConfiguration.layoutGroups.contains(where: { $0.name == "Group \(index)" }) {
            index += 1
        }
        return "Group \(index)"
    }

    private func nextLayoutID() -> String {
        let nextIndex = draftConfiguration.layoutGroups
            .flatMap(\.sets)
            .flatMap(\.layouts)
            .compactMap { layout -> Int? in
                guard layout.id.hasPrefix("layout-") else {
                    return nil
                }
                return Int(layout.id.dropFirst("layout-".count))
            }
            .max()
            .map { $0 + 1 } ?? 1
        return "layout-\(nextIndex)"
    }

    private func removeNode(_ node: LayoutsTreeNode) {
        let nextSelection = selectionAfterRemoving(node: node)
        mutateLayoutsDraft(preserving: nextSelection) { configuration in
            switch node.kind {
            case let .group(group, _):
                guard let groupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == group.name }) else {
                    return
                }
                configuration.layoutGroups.remove(at: groupIndex)
                if configuration.general.activeLayoutGroup == group.name,
                   let fallbackGroupName = configuration.layoutGroups.first?.name {
                    configuration.general.activeLayoutGroup = fallbackGroupName
                }
            case let .set(groupName, setIndex, _):
                guard let groupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == groupName }),
                      configuration.layoutGroups[groupIndex].sets.indices.contains(setIndex) else {
                    return
                }
                configuration.layoutGroups[groupIndex].sets.remove(at: setIndex)
            case let .layout(groupName, setIndex, layout, _):
                guard let layoutPath = self.layoutPath(for: layout.id, groupName: groupName, setIndex: setIndex, in: configuration) else {
                    return
                }
                configuration.layoutGroups[layoutPath.groupIndex].sets[layoutPath.setIndex].layouts.remove(at: layoutPath.layoutIndex)
            }
        }
    }

    private func selectionAfterRemoving(node: LayoutsTreeNode) -> NodeSelection? {
        switch node.kind {
        case let .group(group, _):
            guard let groupIndex = treeNodes.firstIndex(where: {
                if case let .group(existingGroup, _) = $0.kind {
                    return existingGroup.name == group.name
                }
                return false
            }) else {
                return firstAvailableSelection(in: treeNodes)
            }
            if treeNodes.indices.contains(groupIndex + 1) {
                return selectionKey(for: treeNodes[groupIndex + 1])
            }
            if treeNodes.indices.contains(groupIndex - 1) {
                return selectionKey(for: treeNodes[groupIndex - 1])
            }
            return nil
        case let .set(groupName, setIndex, _):
            guard let groupNode = treeNodes.first(where: {
                if case let .group(group, _) = $0.kind {
                    return group.name == groupName
                }
                return false
            }) else {
                return firstAvailableSelection(in: treeNodes)
            }
            if groupNode.children.indices.contains(setIndex + 1) {
                return selectionKey(for: groupNode.children[setIndex + 1])
            }
            if groupNode.children.indices.contains(setIndex - 1) {
                return selectionKey(for: groupNode.children[setIndex - 1])
            }
            return selectionKey(for: groupNode)
        case let .layout(groupName, setIndex, layout, _):
            guard let setNode = itemForSet(groupName: groupName, setIndex: setIndex),
                  let layoutIndex = setNode.children.firstIndex(where: {
                      if case let .layout(_, _, candidateLayout, _) = $0.kind {
                          return candidateLayout.id == layout.id
                      }
                      return false
                  }) else {
                return firstAvailableSelection(in: treeNodes)
            }
            if setNode.children.indices.contains(layoutIndex + 1) {
                return selectionKey(for: setNode.children[layoutIndex + 1])
            }
            if setNode.children.indices.contains(layoutIndex - 1) {
                return selectionKey(for: setNode.children[layoutIndex - 1])
            }
            return selectionKey(for: setNode)
        }
    }

    private func suggestedMonitorForNewSet(inGroupNamed groupName: String) -> LayoutSetMonitor? {
        guard let group = draftConfiguration.layoutGroups.first(where: { $0.name == groupName }) else {
            return nil
        }

        let hasAll = group.sets.contains(where: { $0.monitor == .all })
        if hasAll == false {
            return .all
        }

        let hasMain = group.sets.contains(where: { $0.monitor == .main })
        if hasMain == false {
            return .main
        }

        let usedDisplayIDs = Set(group.sets.flatMap(\.monitor.explicitDisplayIDs))
        let availableDisplayID = prototypeState.currentMonitorNameMap()
            .keys
            .sorted()
            .first(where: { usedDisplayIDs.contains($0) == false })

        if let availableDisplayID {
            return .displays([availableDisplayID])
        }

        return nil
    }

    private func removeButtonState(for node: LayoutsTreeNode?) -> (isEnabled: Bool, toolTip: String?) {
        guard let node else {
            return (false, nil)
        }

        switch node.kind {
        case let .group(group, _):
            if group.protect {
                return (false, UICopy.settingsProtectedGroupTooltip)
            }
            return (draftConfiguration.layoutGroups.count > 1, nil)
        case .set, .layout:
            return (true, nil)
        }
    }

    private func addActionState(for node: LayoutsTreeNode?) -> Bool {
        guard let node,
              let addAction = preferredAddAction(for: node) else {
            return false
        }

        switch addAction {
        case .group:
            return true
        case .monitorSet:
            guard let groupName = groupNameForAddAction(from: node) else {
                return false
            }
            return suggestedMonitorForNewSet(inGroupNamed: groupName) != nil
        case .layout:
            return true
        }
    }

    private func preferredAddAction(for node: LayoutsTreeNode?) -> AddAction? {
        guard let node else {
            return nil
        }

        switch node.kind {
        case let .group(group, _):
            return group.sets.isEmpty ? .monitorSet : .group
        case let .set(_, _, set):
            return set.layouts.isEmpty ? .layout : .monitorSet
        case .layout:
            return .layout
        }
    }

    private func groupNameForAddAction(from node: LayoutsTreeNode) -> String? {
        switch node.kind {
        case let .group(group, _):
            return group.name
        case let .set(groupName, _, _):
            return groupName
        case let .layout(groupName, _, _, _):
            return groupName
        }
    }

    private func setContextForAddAction(from node: LayoutsTreeNode) -> (groupName: String, setIndex: Int)? {
        switch node.kind {
        case let .set(groupName, setIndex, _):
            return (groupName, setIndex)
        case let .layout(groupName, setIndex, _, _):
            return (groupName, setIndex)
        case .group:
            return nil
        }
    }

    private func canAssignMonitor(_ monitor: LayoutSetMonitor, toSetAt setIndex: Int, inGroupNamed groupName: String) -> Bool {
        guard let group = draftConfiguration.layoutGroups.first(where: { $0.name == groupName }),
              group.sets.indices.contains(setIndex) else {
            return false
        }

        var explicitDisplayIDs: Set<String> = []
        var hasMainSet = false
        var hasAllSet = false

        for (currentIndex, set) in group.sets.enumerated() {
            let candidateMonitor = currentIndex == setIndex ? monitor : set.monitor
            switch candidateMonitor {
            case .all:
                guard hasAllSet == false else {
                    return false
                }
                hasAllSet = true
            case .main:
                guard hasMainSet == false else {
                    return false
                }
                hasMainSet = true
            case let .displays(displayIDs):
                for displayID in displayIDs {
                    guard explicitDisplayIDs.contains(displayID) == false else {
                        return false
                    }
                    explicitDisplayIDs.insert(displayID)
                }
            }
        }

        return true
    }

    private func layoutPath(
        for layoutID: String,
        groupName: String,
        setIndex: Int,
        in configuration: AppConfiguration
    ) -> (groupIndex: Int, setIndex: Int, layoutIndex: Int)? {
        guard let groupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == groupName }),
              configuration.layoutGroups[groupIndex].sets.indices.contains(setIndex),
              let layoutIndex = configuration.layoutGroups[groupIndex].sets[setIndex].layouts.firstIndex(where: { $0.id == layoutID }) else {
            return nil
        }
        return (groupIndex, setIndex, layoutIndex)
    }

    private func normalizeLayout(_ layout: inout LayoutPreset) {
        layout.gridColumns = max(1, layout.gridColumns)
        layout.gridRows = max(1, layout.gridRows)

        layout.windowSelection.w = max(1, min(layout.gridColumns, layout.windowSelection.w))
        layout.windowSelection.h = max(1, min(layout.gridRows, layout.windowSelection.h))
        layout.windowSelection.x = max(0, min(layout.windowSelection.x, layout.gridColumns - layout.windowSelection.w))
        layout.windowSelection.y = max(0, min(layout.windowSelection.y, layout.gridRows - layout.windowSelection.h))

        switch layout.triggerRegion {
        case var .screen(selection):
            selection.w = max(1, min(layout.gridColumns, selection.w))
            selection.h = max(1, min(layout.gridRows, selection.h))
            selection.x = max(0, min(selection.x, layout.gridColumns - selection.w))
            selection.y = max(0, min(selection.y, layout.gridRows - selection.h))
            layout.triggerRegion = .screen(selection)
        case var .menuBar(selection):
            selection.w = max(1, min(layout.gridRows, selection.w))
            selection.x = max(0, min(selection.x, layout.gridRows - selection.w))
            layout.triggerRegion = .menuBar(selection)
        case nil:
            break
        }
    }

    @discardableResult
    private func moveLayout(id: String, groupName: String, setIndex: Int, toLocalIndex targetIndex: Int) -> Bool {
        guard let groupIndex = draftConfiguration.layoutGroups.firstIndex(where: { $0.name == groupName }),
              draftConfiguration.layoutGroups[groupIndex].sets.indices.contains(setIndex) else {
            return false
        }

        var layouts = draftConfiguration.layoutGroups[groupIndex].sets[setIndex].layouts
        guard let sourceIndex = layouts.firstIndex(where: { $0.id == id }) else {
            return false
        }

        var destinationIndex = max(0, min(targetIndex, layouts.count))
        if sourceIndex < destinationIndex {
            destinationIndex -= 1
        }

        guard destinationIndex != sourceIndex else {
            return false
        }

        let movedLayout = layouts.remove(at: sourceIndex)
        layouts.insert(movedLayout, at: max(0, min(destinationIndex, layouts.count)))
        mutateLayoutsDraft(preserving: .layout(id: id)) { configuration in
            guard let mutationGroupIndex = configuration.layoutGroups.firstIndex(where: { $0.name == groupName }),
                  configuration.layoutGroups[mutationGroupIndex].sets.indices.contains(setIndex) else {
                return
            }
            configuration.layoutGroups[mutationGroupIndex].sets[setIndex].layouts = layouts
        }
        return true
    }

    func moveLayoutForTesting(id: String, groupName: String, setIndex: Int, toLocalIndex targetIndex: Int) -> Bool {
        moveLayout(id: id, groupName: groupName, setIndex: setIndex, toLocalIndex: targetIndex)
    }

    func layoutTitlesForTesting(groupName: String, setIndex: Int) -> [String] {
        guard let group = draftConfiguration.layoutGroups.first(where: { $0.name == groupName }),
              group.sets.indices.contains(setIndex) else {
            return []
        }
        return group.sets[setIndex].layouts.map(\.name)
    }

    var saveButtonEnabledForTesting: Bool {
        saveButton.isEnabled
    }

    var removeButtonEnabledForTesting: Bool {
        removeButton.isEnabled
    }

    var removeButtonToolTipForTesting: String? {
        removeButton.toolTip
    }

    var selectedGroupNameForTesting: String? {
        selectedNode.flatMap {
            switch $0.kind {
            case let .group(group, _):
                return group.name
            default:
                return nil
            }
        }
    }

    var activeGroupNameForTesting: String {
        draftConfiguration.general.activeLayoutGroup
    }

    func selectGroupForTesting(named groupName: String) {
        reloadTree(preserving: .group(name: groupName))
    }

    func selectSetForTesting(groupName: String, setIndex: Int) {
        reloadTree(preserving: .set(groupName: groupName, setIndex: setIndex))
    }

    func selectLayoutForTesting(id: String) {
        reloadTree(preserving: .layout(id: id))
    }

    func addActionForTesting() {
        handleAddAction(addButton)
    }

    func removeSelectionForTesting() {
        guard let selectedNode else {
            return
        }
        removeNode(selectedNode)
    }

    func saveLayoutsForTesting() {
        handleSaveLayoutEdits(saveButton)
    }

    func updateSetMonitorForTesting(groupName: String, setIndex: Int, monitor: LayoutSetMonitor) {
        updateSetMonitor(groupName: groupName, setIndex: setIndex, monitor: monitor)
    }

    var draftConfigurationForTesting: AppConfiguration {
        draftConfiguration
    }
}

@MainActor
private final class CallbackTextField: NSTextField, NSTextFieldDelegate {
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
