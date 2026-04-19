import AppKit

@MainActor
final class LayoutsSettingsViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSSplitViewDelegate {
    enum SplitViewMetrics {
        static let preferredSidebarWidth: CGFloat = 250
        static let minimumSidebarWidth: CGFloat = 210
        static let preferredDetailWidth: CGFloat = 700
        static let minimumDetailWidth: CGFloat = 520
    }

    enum DragPasteboard {
        static let layoutType = NSPasteboard.PasteboardType("com.mirtle.gridmove.settings.layout")
    }

    enum NodeSelection: Equatable {
        case group(name: String)
        case set(groupName: String, setIndex: Int)
        case layout(id: String)
    }

    enum AddAction {
        case group
        case monitorSet
        case layout
    }

    let prototypeState: SettingsPrototypeState
    let actionHandler: any SettingsActionHandling
    var draftConfiguration: AppConfiguration
    let outlineView = LayoutsOutlineView()
    let sidebarScrollView = NSScrollView()
    let detailContainerView = NSView()
    let splitView = NSSplitView()
    let addButton = NSButton(title: UICopy.settingsAddLayoutButtonTitle, target: nil, action: nil)
    let removeButton = NSButton(title: UICopy.settingsRemoveButtonTitle, target: nil, action: nil)
    let saveButton = NSButton(title: UICopy.settingsSaveButtonTitle, target: nil, action: nil)
    var treeNodes: [LayoutsTreeNode]
    var pendingSelection: NodeSelection?
    var selectedLayoutDetailTabIndex = 0
    var currentLayoutGridColumnsControl: SettingsIntegerStepperControl?
    var currentLayoutGridRowsControl: SettingsIntegerStepperControl?
    var currentLayoutWindowXControl: SettingsIntegerStepperControl?
    var currentLayoutWindowYControl: SettingsIntegerStepperControl?
    var currentLayoutWindowWidthControl: SettingsIntegerStepperControl?
    var currentLayoutWindowHeightControl: SettingsIntegerStepperControl?
    var currentGroupNameControl: CallbackTextField?
    var currentLayoutNameControl: CallbackTextField?
    var currentLayoutPreviewView: LayoutPreviewView?
    var currentLayoutTriggerContentView: TriggerTabContentView?

    private var hasAppliedInitialSplitPosition = false

    init(prototypeState: SettingsPrototypeState, actionHandler: any SettingsActionHandling) {
        self.prototypeState = prototypeState
        self.actionHandler = actionHandler
        draftConfiguration = prototypeState.configuration
        treeNodes = LayoutsTreeNode.makeTree(
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
        applyInitialExpansionState()
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

    override func viewDidAppear() {
        super.viewDidAppear()
        updateCommandBar()
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

    var selectedNode: LayoutsTreeNode? {
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
        outlineView.target = self
        outlineView.doubleAction = #selector(handleOutlineDoubleClick(_:))
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
        outlineView.registerForDraggedTypes([DragPasteboard.layoutType])
    }

    private func selectFallbackNodeIfNeeded() {
        guard outlineView.selectedRow < 0,
              let defaultSelection = preferredInitialSelection(in: treeNodes) else {
            return
        }
        reloadTree(preserving: defaultSelection)
    }

    func firstAvailableSelection(in nodes: [LayoutsTreeNode]) -> NodeSelection? {
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

    func treeIcon(for node: LayoutsTreeNode) -> NSImage? {
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

    func treeIconTintColor(for node: LayoutsTreeNode) -> NSColor? {
        switch node.kind {
        case .group(_, let isActive):
            return isActive ? .controlAccentColor : nil
        default:
            return nil
        }
    }

    func reloadTree(preserving selection: NodeSelection?) {
        let expandedSelections = expandedNodeSelections()
        treeNodes = LayoutsTreeNode.makeTree(
            configuration: draftConfiguration,
            monitorMap: prototypeState.currentMonitorNameMap()
        )
        outlineView.reloadData()
        restoreExpansionState(from: expandedSelections)

        let effectiveSelection = selection ?? preferredInitialSelection(in: treeNodes)
        guard let effectiveSelection,
              let node = findNode(matching: effectiveSelection, in: treeNodes) else {
            detailContainerView.subviews.forEach { $0.removeFromSuperview() }
            updateCommandBar()
            return
        }

        expandAncestors(of: node, in: treeNodes)
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

    private func preferredInitialSelection(in nodes: [LayoutsTreeNode]) -> NodeSelection? {
        if let activeGroupNode = findNode(
            matching: .group(name: draftConfiguration.general.activeLayoutGroup),
            in: nodes
        ) {
            return selectionKey(for: activeGroupNode)
        }
        return firstAvailableSelection(in: nodes)
    }

    private func applyInitialExpansionState() {
        restoreExpansionState(from: [])
    }

    private func expandedNodeSelections() -> [NodeSelection] {
        var expandedSelections: [NodeSelection] = []
        for row in 0..<outlineView.numberOfRows {
            guard let node = outlineView.item(atRow: row) as? LayoutsTreeNode,
                  outlineView.isItemExpanded(node) else {
                continue
            }
            expandedSelections.append(selectionKey(for: node))
        }
        return expandedSelections
    }

    private func restoreExpansionState(from expandedSelections: [NodeSelection]) {
        if expandedSelections.isEmpty {
            if let activeGroupNode = findNode(
                matching: .group(name: draftConfiguration.general.activeLayoutGroup),
                in: treeNodes
            ) {
                outlineView.expandItem(activeGroupNode, expandChildren: true)
            }
            return
        }

        for selection in expandedSelections {
            guard let node = findNode(matching: selection, in: treeNodes) else {
                continue
            }
            expandAncestors(of: node, in: treeNodes)
            outlineView.expandItem(node)
        }
    }

    @discardableResult
    private func expandAncestors(of targetNode: LayoutsTreeNode, in nodes: [LayoutsTreeNode]) -> Bool {
        for node in nodes {
            if node === targetNode {
                return true
            }
            if expandAncestors(of: targetNode, in: node.children) {
                outlineView.expandItem(node)
                return true
            }
        }
        return false
    }

    func selectionKey(for node: LayoutsTreeNode) -> NodeSelection {
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

    func itemForSet(groupName: String, setIndex: Int) -> LayoutsTreeNode? {
        treeNodes.first(where: {
            if case let .group(group, _) = $0.kind {
                return group.name == groupName
            }
            return false
        })?.children[safe: setIndex]
    }

    @objc
    func handleOutlineDoubleClick(_ sender: NSOutlineView) {
        guard let node = selectedNode else {
            return
        }

        guard case let .group(group, isActive) = node.kind, !isActive else {
            return
        }

        mutateLayoutsDraft(preserving: .group(name: group.name)) { configuration in
            configuration.general.activeLayoutGroup = group.name
        }
    }
}
