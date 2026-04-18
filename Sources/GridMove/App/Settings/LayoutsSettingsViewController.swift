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

        static func == (lhs: NodeSelection, rhs: NodeSelection) -> Bool {
            switch (lhs, rhs) {
            case let (.group(leftName), .group(rightName)):
                return leftName == rightName
            case let (.set(leftGroupName, leftSetIndex), .set(rightGroupName, rightSetIndex)):
                return leftGroupName == rightGroupName && leftSetIndex == rightSetIndex
            case let (.layout(leftID), .layout(rightID)):
                return leftID == rightID
            default:
                return false
            }
        }
    }

    private let prototypeState: SettingsPrototypeState
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

    init(prototypeState: SettingsPrototypeState) {
        self.prototypeState = prototypeState
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

        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
        selectDefaultLayoutNode()
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
        guard let selectedNode = selectedNode else {
            return
        }
        updateDetailView(for: selectedNode)
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

    private func selectDefaultLayoutNode() {
        guard let firstGroup = treeNodes.first,
              let firstSet = firstGroup.children.first,
              let firstLayout = firstSet.children.first else {
            return
        }

        let row = outlineView.row(forItem: firstLayout)
        guard row >= 0 else {
            return
        }

        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        updateDetailView(for: firstLayout)
        updateCommandBar(for: firstLayout)
    }

    private func updateDetailView(for node: LayoutsTreeNode) {
        detailContainerView.subviews.forEach { $0.removeFromSuperview() }

        let contentView: NSView
        switch node.kind {
        case let .group(group, isActive):
            contentView = makeGroupDetailView(group: group, isActive: isActive)
        case let .set(_, _, set, layoutCount):
            contentView = makeSetDetailView(set: set, layoutCount: layoutCount)
        case let .layout(_, _, layout, _):
            contentView = makeLayoutDetailView(layout: layout)
        }

        detailContainerView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: detailContainerView.leadingAnchor, constant: 12),
            contentView.trailingAnchor.constraint(equalTo: detailContainerView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: detailContainerView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: detailContainerView.bottomAnchor),
        ])

        updateCommandBar(for: node)
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
        let formView = makeInlineTabContent(rows: [
            makeLabeledControlRow(label: UICopy.settingsNameLabel, control: makeEditableTextControl(value: group.name, width: 220)),
            makeLabeledControlRow(label: UICopy.settingsIncludeInGroupCycleLabel, control: makeEditableCheckboxControl(isOn: group.includeInGroupCycle)),
            makeLabeledControlRow(label: UICopy.settingsActiveGroupLabel, control: makeActiveGroupControl(groupName: group.name, isActive: isActive)),
        ], width: 460)
        contentStackView.addArrangedSubview(makeCenteredContainer(for: formView))
        return makeDetailPanelContainer(contentView: contentStackView)
    }

    private func makeActiveGroupControl(groupName: String, isActive: Bool) -> NSButton {
        let checkbox = makeEditableCheckboxControl(isOn: isActive)
        checkbox.target = self
        checkbox.action = #selector(handleActiveGroupToggle(_:))
        checkbox.identifier = NSUserInterfaceItemIdentifier(groupName)
        return checkbox
    }

    @objc
    private func handleActiveGroupToggle(_ sender: NSButton) {
        guard let groupName = sender.identifier?.rawValue else {
            return
        }

        if sender.state != .on {
            // There must always be one active group in the draft state.
            sender.state = .on
            return
        }

        guard draftConfiguration.general.activeLayoutGroup != groupName else {
            return
        }

        draftConfiguration.general.activeLayoutGroup = groupName
        reloadTree(preserving: .group(name: groupName))
    }

    private func makeSetDetailView(set: LayoutSet, layoutCount: Int) -> NSView {
        let contentStackView = makeSettingsPageStackView()
        let formView = makeInlineTabContent(rows: [
            makeLabeledControlRow(
                label: UICopy.settingsApplyToLabel,
                control: ApplyToControlView(
                    set: set,
                    persistedMonitorMapProvider: { [weak self] in
                        self?.prototypeState.currentMonitorNameMap() ?? [:]
                    }
                )
            ),
        ], width: 460)
        contentStackView.addArrangedSubview(makeCenteredContainer(for: formView))
        return makeDetailPanelContainer(contentView: contentStackView)
    }

    private func makeLayoutDetailView(layout: LayoutPreset) -> NSView {
        let contentStackView = makeSettingsPageStackView()

        let previewView = makeLayoutPreviewView(layout: layout, mode: .combined)
        contentStackView.addArrangedSubview(makeCenteredContainer(for: previewView))

        let windowSelection = layout.windowSelection
        let triggerContentView = TriggerTabContentView(layout: layout)
        previewView.triggerRegionOverride = triggerContentView.currentTriggerRegion
        triggerContentView.onTriggerRegionChanged = { [weak previewView] triggerRegion in
            previewView?.triggerRegionOverride = triggerRegion
        }

        let detailTabsView = SettingsInlineTabsView(
            tabs: [
                SettingsInlineTab(
                        title: UICopy.settingsGeneralInlineTabTitle,
                        contentView: makeInlineTabContent(rows: [
                            makeLabeledControlRow(label: UICopy.settingsNameLabel, control: makeEditableTextControl(value: layout.name, width: 220)),
                            makeLabeledControlRow(label: UICopy.settingsIncludeInMenuLabel, control: makeEditableCheckboxControl(isOn: layout.includeInMenu)),
                            makeLabeledControlRow(label: UICopy.settingsIncludeInLayoutIndexLabel, control: makeEditableCheckboxControl(isOn: layout.includeInLayoutIndex)),
                            makeLabeledControlRow(label: UICopy.settingsGridColumnsLabel, control: makeNumericStepperControl(value: layout.gridColumns, unit: "grid", minValue: 1, maxValue: 24)),
                            makeLabeledControlRow(label: UICopy.settingsGridRowsLabel, control: makeNumericStepperControl(value: layout.gridRows, unit: "grid", minValue: 1, maxValue: 24)),
                        ], width: 460)
                ),
                SettingsInlineTab(
                    title: UICopy.settingsWindowInlineTabTitle,
                    contentView: makeInlineTabContent(rows: [
                        makeLabeledControlRow(label: UICopy.settingsXPositionLabel, control: makeNumericStepperControl(value: windowSelection.x, unit: "grid", minValue: 0, maxValue: max(0, layout.gridColumns - 1))),
                        makeLabeledControlRow(label: UICopy.settingsYPositionLabel, control: makeNumericStepperControl(value: windowSelection.y, unit: "grid", minValue: 0, maxValue: max(0, layout.gridRows - 1))),
                        makeLabeledControlRow(label: UICopy.settingsWidthLabel, control: makeNumericStepperControl(value: windowSelection.w, unit: "grid", minValue: 0, maxValue: layout.gridColumns)),
                        makeLabeledControlRow(label: UICopy.settingsHeightLabel, control: makeNumericStepperControl(value: windowSelection.h, unit: "grid", minValue: 0, maxValue: layout.gridRows)),
                    ], width: 460)
                ),
                SettingsInlineTab(
                    title: UICopy.settingsTriggerInlineTabTitle,
                    contentView: triggerContentView
                ),
            ]
        )
        detailTabsView.onSelectionChanged = { [weak previewView] selectedIndex in
            previewView?.mode = switch selectedIndex {
            case 1: .windowLayout
            case 2: .triggerRegion
            default: .combined
            }
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

    private func makeReadonlyValueControl(_ value: String) -> NSView {
        let label = makeValueLabel(value)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private func makeReadonlyCheckboxControl(isOn: Bool) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.state = isOn ? .on : .off
        checkbox.isEnabled = false
        return checkbox
    }

    private func makeEditableTextControl(value: String, width: CGFloat) -> NSTextField {
        let textField = NSTextField(string: value)
        textField.controlSize = .small
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.widthAnchor.constraint(equalToConstant: width).isActive = true
        return textField
    }

    private func makeEditableCheckboxControl(isOn: Bool) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.state = isOn ? .on : .off
        return checkbox
    }

    private func makeDetailPanelContainer(contentView: NSView, buttonTitles: [String] = []) -> NSView {
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

        var constraints = [
            panelView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            panelView.topAnchor.constraint(equalTo: containerView.topAnchor),
            panelView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: panelContentView.leadingAnchor, constant: 18),
            contentView.trailingAnchor.constraint(equalTo: panelContentView.trailingAnchor, constant: -18),
            contentView.topAnchor.constraint(equalTo: panelContentView.topAnchor, constant: 18),
        ]

        constraints.append(contentView.bottomAnchor.constraint(lessThanOrEqualTo: panelContentView.bottomAnchor, constant: 0))

        NSLayoutConstraint.activate(constraints)

        return containerView
    }

    private func makeCommandBarView() -> NSView {
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        addButton.bezelStyle = .rounded
        removeButton.bezelStyle = .rounded
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

    private func updateCommandBar(for node: LayoutsTreeNode) {
        addButton.title = switch node.kind {
        case .group:
            UICopy.settingsAddGroupButtonTitle
        case .set:
            UICopy.settingsAddDisplaySetButtonTitle
        case .layout:
            UICopy.settingsAddLayoutButtonTitle
        }
        removeButton.title = UICopy.settingsRemoveButtonTitle
        saveButton.title = UICopy.settingsSaveButtonTitle
    }

    @objc
    private func handleSaveLayoutEdits(_ sender: NSButton) {
        // TODO: When real configuration persistence is connected, this is the
        // single save boundary for the Layouts page. Persist draftConfiguration
        // here instead of letting individual controls write immediately.
        prototypeState.configuration = draftConfiguration
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
              dragContext.setIndex == dropTarget.setIndex,
              moveLayout(
                id: dragContext.layoutID,
                groupName: dragContext.groupName,
                setIndex: dragContext.setIndex,
                toLocalIndex: dropTarget.childIndex
              ) else {
            return false
        }

        reloadTree(preserving: .layout(id: dragContext.layoutID))
        return true
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

        guard let selection, let node = findNode(matching: selection, in: treeNodes) else {
            return
        }

        let row = outlineView.row(forItem: node)
        guard row >= 0 else {
            return
        }

        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
        updateDetailView(for: node)
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
        case let .set(groupName, setIndex, _, _):
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
        case let .set(groupName, setIndex, _, _):
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
        draftConfiguration.layoutGroups[groupIndex].sets[setIndex].layouts = layouts
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
}

@MainActor
private final class ApplyToControlView: NSView {
    enum ApplyToKind {
        case all
        case main
        case custom
    }

    private let popupButton = NSPopUpButton()
    private let refreshButton = NSButton()
    private let customMonitorsStackView = makeVerticalGroup(spacing: 8)
    private let rootStackView = makeVerticalGroup(spacing: 10)
    private let selectedMonitorIDs: [String]
    private let persistedMonitorMapProvider: () -> [String: String]
    private var monitorOptions: [(id: String, name: String)] = []

    init(set: LayoutSet, persistedMonitorMapProvider: @escaping () -> [String: String]) {
        self.selectedMonitorIDs = set.monitor.explicitDisplayIDs
        self.persistedMonitorMapProvider = persistedMonitorMapProvider
        super.init(frame: .zero)

        popupButton.controlSize = .small
        popupButton.addItems(withTitles: [
            UICopy.settingsAllMonitorsValue,
            UICopy.settingsMainMonitorValue,
            UICopy.settingsCustomMonitorsValue,
        ])
        popupButton.selectItem(withTitle: selectedTitle(for: set.monitor))
        popupButton.target = self
        popupButton.action = #selector(handlePopupChange(_:))

        refreshButton.bezelStyle = .rounded
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: UICopy.reloadConfigMenuTitle)
        refreshButton.imagePosition = .imageOnly
        refreshButton.target = self
        refreshButton.action = #selector(handleRefreshMonitorOptions(_:))

        let headerRow = makeHorizontalGroup(spacing: 8)
        headerRow.alignment = .centerY
        headerRow.addArrangedSubview(popupButton)
        headerRow.addArrangedSubview(refreshButton)
        headerRow.addArrangedSubview(NSView())

        rootStackView.translatesAutoresizingMaskIntoConstraints = false
        rootStackView.alignment = .leading
        addSubview(rootStackView)

        rootStackView.addArrangedSubview(headerRow)
        rootStackView.addArrangedSubview(customMonitorsStackView)

        NSLayoutConstraint.activate([
            rootStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            rootStackView.topAnchor.constraint(equalTo: topAnchor),
            rootStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        refreshMonitorOptions(for: set.monitor)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    @objc
    private func handlePopupChange(_ sender: NSPopUpButton) {
        rebuildCustomMonitorList()
    }

    @objc
    private func handleRefreshMonitorOptions(_ sender: NSButton) {
        refreshMonitorOptions(for: resolvedMonitorTarget)
    }

    private var resolvedMonitorTarget: LayoutSetMonitor {
        switch popupButton.selectedItem?.title {
        case UICopy.settingsMainMonitorValue:
            return .main
        case UICopy.settingsCustomMonitorsValue:
            return .displays(selectedMonitorIDs)
        default:
            return .all
        }
    }

    private func refreshMonitorOptions(for monitor: LayoutSetMonitor) {
        // TODO: When real reload wiring starts, hook this button to the same
        // monitor refresh path used by config reload instead of only rebuilding
        // from the persisted prototype snapshot.
        monitorOptions = Self.makeMonitorOptions(for: monitor, monitorMap: persistedMonitorMapProvider())
        rebuildCustomMonitorList()
    }

    private func rebuildCustomMonitorList() {
        customMonitorsStackView.isHidden = popupButton.selectedItem?.title != UICopy.settingsCustomMonitorsValue

        for view in customMonitorsStackView.arrangedSubviews {
            customMonitorsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !customMonitorsStackView.isHidden else {
            return
        }

        for (displayID, name) in monitorOptions {
            let checkbox = NSButton(checkboxWithTitle: name, target: nil, action: nil)
            checkbox.state = selectedMonitorIDs.contains(displayID) ? .on : .off
            customMonitorsStackView.addArrangedSubview(checkbox)
        }
    }

    private func selectedTitle(for monitor: LayoutSetMonitor) -> String {
        switch monitor {
        case .all:
            UICopy.settingsAllMonitorsValue
        case .main:
            UICopy.settingsMainMonitorValue
        case .displays:
            UICopy.settingsCustomMonitorsValue
        }
    }

    private static func makeMonitorOptions(for monitor: LayoutSetMonitor, monitorMap: [String: String]) -> [(id: String, name: String)] {
        let explicitIDs = monitor.explicitDisplayIDs
        let mergedIDs = Array(Set(monitorMap.keys + explicitIDs)).sorted {
            let leftName = monitorMap[$0] ?? fallbackDisplayName(for: $0)
            let rightName = monitorMap[$1] ?? fallbackDisplayName(for: $1)
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }
        return mergedIDs.map { ($0, monitorMap[$0] ?? fallbackDisplayName(for: $0)) }
    }

    nonisolated static func fallbackDisplayName(for displayID: String) -> String {
        if displayID.count > 10 {
            return "Monitor \(displayID.prefix(8))"
        }
        return "Monitor \(displayID)"
    }
}

@MainActor
private final class TriggerTabContentView: NSView {
    enum TriggerAreaKind {
        case none
        case screen
        case menuBar
    }

    private let layout: LayoutPreset
    private let popupButton = NSPopUpButton()
    private let dynamicRowsStackView = makeVerticalGroup(spacing: 9)
    private let rootStackView: NSView
    private let screenSelection: GridSelection
    private let menuBarSelection: MenuBarSelection
    var onTriggerRegionChanged: ((TriggerRegion?) -> Void)?

    var currentTriggerRegion: TriggerRegion? {
        switch selectedTriggerArea {
        case .none:
            nil
        case .screen:
            .screen(screenSelection)
        case .menuBar:
            .menuBar(menuBarSelection)
        }
    }

    private var selectedTriggerArea: TriggerAreaKind {
        switch popupButton.selectedItem?.title {
        case UICopy.settingsMenuBarTriggerValue:
            .menuBar
        case UICopy.settingsNoneValue:
            .none
        default:
            .screen
        }
    }

    init(layout: LayoutPreset) {
        self.layout = layout

        switch layout.triggerRegion {
        case let .screen(selection):
            self.screenSelection = selection
            self.menuBarSelection = MenuBarSelection(x: 0, w: layout.gridRows)
        case let .menuBar(selection):
            self.screenSelection = GridSelection(x: 0, y: 0, w: max(1, layout.gridColumns), h: max(1, layout.gridRows))
            self.menuBarSelection = selection
        case nil:
            self.screenSelection = GridSelection(x: 0, y: 0, w: max(1, layout.gridColumns), h: max(1, layout.gridRows))
            self.menuBarSelection = MenuBarSelection(x: 0, w: layout.gridRows)
        }

        let triggerAreaRow = makeLabeledControlRow(
            label: UICopy.settingsTriggerAreaLabel,
            control: popupButton
        )
        self.rootStackView = makeInlineTabContent(rows: [triggerAreaRow, dynamicRowsStackView], width: 460)

        super.init(frame: .zero)

        popupButton.controlSize = .small
        popupButton.addItems(withTitles: [
            UICopy.settingsNoneValue,
            UICopy.settingsScreenGridValue,
            UICopy.settingsMenuBarTriggerValue,
        ])
        popupButton.selectItem(withTitle: selectedTitle(for: layout.triggerRegion))
        popupButton.target = self
        popupButton.action = #selector(handleTriggerAreaChange(_:))

        rootStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStackView)
        NSLayoutConstraint.activate([
            rootStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStackView.topAnchor.constraint(equalTo: topAnchor),
            rootStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        rebuildRows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    @objc
    private func handleTriggerAreaChange(_ sender: NSPopUpButton) {
        rebuildRows()
        onTriggerRegionChanged?(currentTriggerRegion)
    }

    private func rebuildRows() {
        for row in dynamicRowsStackView.arrangedSubviews {
            dynamicRowsStackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        let rows: [NSView]
        switch selectedTriggerArea {
        case .none:
            rows = []
        case .screen:
            rows = [
                makeLabeledControlRow(
                    label: UICopy.settingsXPositionLabel,
                    control: makeNumericStepperControl(
                        value: screenSelection.x,
                        unit: "grid",
                        minValue: 0,
                        maxValue: max(0, layout.gridColumns - 1)
                    )
                ),
                makeLabeledControlRow(
                    label: UICopy.settingsYPositionLabel,
                    control: makeNumericStepperControl(
                        value: screenSelection.y,
                        unit: "grid",
                        minValue: 0,
                        maxValue: max(0, layout.gridRows - 1)
                    )
                ),
                makeLabeledControlRow(
                    label: UICopy.settingsWidthLabel,
                    control: makeNumericStepperControl(
                        value: screenSelection.w,
                        unit: "grid",
                        minValue: 0,
                        maxValue: layout.gridColumns
                    )
                ),
                makeLabeledControlRow(
                    label: UICopy.settingsHeightLabel,
                    control: makeNumericStepperControl(
                        value: screenSelection.h,
                        unit: "grid",
                        minValue: 0,
                        maxValue: layout.gridRows
                    )
                ),
            ]
        case .menuBar:
            rows = [
                makeLabeledControlRow(
                    label: UICopy.settingsStartLabel,
                    control: makeNumericStepperControl(
                        value: menuBarSelection.x,
                        unit: "grid",
                        minValue: 0,
                        maxValue: max(0, layout.gridRows - 1)
                    )
                ),
                makeLabeledControlRow(
                    label: UICopy.settingsWidthLabel,
                    control: makeNumericStepperControl(
                        value: menuBarSelection.w,
                        unit: "grid",
                        minValue: 0,
                        maxValue: layout.gridRows
                    )
                ),
            ]
        }

        rows.forEach { dynamicRowsStackView.addArrangedSubview($0) }
    }

    private func selectedTitle(for triggerRegion: TriggerRegion?) -> String {
        switch triggerRegion {
        case .screen:
            UICopy.settingsScreenGridValue
        case .menuBar:
            UICopy.settingsMenuBarTriggerValue
        case nil:
            UICopy.settingsNoneValue
        }
    }
}

private extension TriggerRegion {
    var isMenuBar: Bool {
        if case .menuBar = self {
            return true
        }
        return false
    }
}

private final class LayoutsTreeNode {
    enum Kind {
        case group(LayoutGroup, isActive: Bool)
        case set(groupName: String, setIndex: Int, set: LayoutSet, layoutCount: Int)
        case layout(groupName: String, setIndex: Int, layout: LayoutPreset, layoutIndex: Int?)
    }

    let title: String
    let kind: Kind
    let children: [LayoutsTreeNode]

    init(title: String, kind: Kind, children: [LayoutsTreeNode] = []) {
        self.title = title
        self.kind = kind
        self.children = children
    }

    static func makeTree(configuration: AppConfiguration, monitorMap: [String: String]) -> [LayoutsTreeNode] {
        configuration.layoutGroups.map { group in
            let layoutMenuIndexByID = Dictionary(
                uniqueKeysWithValues: LayoutGroupResolver
                    .flattenedEntries(in: group)
                    .map { ($0.layout.id, $0.menuIndex) }
            )
            let setNodes: [LayoutsTreeNode] = group.sets.enumerated().map { setIndex, set in
                let layoutNodes: [LayoutsTreeNode] = set.layouts.map { layout in
                    return LayoutsTreeNode(
                        title: layout.name,
                        kind: .layout(
                            groupName: group.name,
                            setIndex: setIndex,
                            layout: layout,
                            layoutIndex: layoutMenuIndexByID[layout.id]
                        )
                    )
                }

                return LayoutsTreeNode(
                    title: monitorTitle(for: set.monitor, monitorMap: monitorMap),
                    kind: .set(groupName: group.name, setIndex: setIndex, set: set, layoutCount: set.layouts.count),
                    children: layoutNodes
                )
            }

            return LayoutsTreeNode(
                title: group.name,
                kind: .group(group, isActive: configuration.general.activeLayoutGroup == group.name),
                children: setNodes
            )
        }
    }

    static func monitorTitle(for monitor: LayoutSetMonitor, monitorMap: [String: String]) -> String {
        switch monitor {
        case .all:
            return UICopy.settingsAllMonitorsValue
        case .main:
            return UICopy.settingsMainMonitorValue
        case let .displays(displayIDs):
            return displayIDs
                .map { monitorMap[$0] ?? ApplyToControlView.fallbackDisplayName(for: $0) }
                .joined(separator: "; ")
        }
    }
}

private final class LayoutsOutlineView: NSOutlineView {
    private(set) var isCurrentMouseDownInLayoutDragHandle = false

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        if row >= 0,
           let cellView = view(atColumn: 0, row: row, makeIfNecessary: false) as? LayoutTreeCellView {
            let pointInCell = cellView.convert(point, from: self)
            isCurrentMouseDownInLayoutDragHandle = cellView.isPointInDragHandle(pointInCell)
        } else {
            isCurrentMouseDownInLayoutDragHandle = false
        }

        super.mouseDown(with: event)
        isCurrentMouseDownInLayoutDragHandle = false
    }
}

private final class LayoutTreeCellView: NSTableCellView {
    private let contentStackView = makeHorizontalGroup(spacing: 8)
    private let dragHandleStackView = makeHorizontalGroup(spacing: 8)
    private let indexLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var leadingConstraint: NSLayoutConstraint?
    private var dragHandleEnabled = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        contentStackView.alignment = .centerY
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        dragHandleStackView.alignment = .centerY
        dragHandleStackView.translatesAutoresizingMaskIntoConstraints = false

        indexLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        indexLabel.textColor = .tertiaryLabelColor
        indexLabel.alignment = .right
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.widthAnchor.constraint(equalToConstant: 18).isActive = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.symbolConfiguration = .init(pointSize: 12, weight: .regular)
        iconView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 14).isActive = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        dragHandleStackView.addArrangedSubview(indexLabel)
        dragHandleStackView.addArrangedSubview(iconView)

        contentStackView.addArrangedSubview(dragHandleStackView)
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(NSView())
        addSubview(contentStackView)
        textField = titleLabel

        let leadingConstraint = contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6)
        self.leadingConstraint = leadingConstraint

        NSLayoutConstraint.activate([
            leadingConstraint,
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            contentStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(title: String, kind: LayoutsTreeNode.Kind, icon: NSImage?, iconTintColor: NSColor?) {
        titleLabel.stringValue = title
        iconView.image = icon
        iconView.contentTintColor = iconTintColor

        switch kind {
        case .group:
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .labelColor
            indexLabel.isHidden = true
            dragHandleEnabled = false
            leadingConstraint?.constant = 6
        case .set:
            titleLabel.font = .systemFont(ofSize: 13)
            titleLabel.textColor = .secondaryLabelColor
            indexLabel.isHidden = true
            dragHandleEnabled = false
            leadingConstraint?.constant = 6
        case let .layout(_, _, _, layoutIndex):
            titleLabel.font = .systemFont(ofSize: 13)
            titleLabel.textColor = .labelColor
            indexLabel.stringValue = layoutIndex.map { "\($0)." } ?? "–"
            indexLabel.isHidden = false
            dragHandleEnabled = true
            leadingConstraint?.constant = -18
        }
    }

    func isPointInDragHandle(_ point: NSPoint) -> Bool {
        guard dragHandleEnabled else {
            return false
        }
        return dragHandleStackView.frame.insetBy(dx: -4, dy: -3).contains(point)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
