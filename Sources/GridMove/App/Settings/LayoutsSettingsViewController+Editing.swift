import AppKit

@MainActor
extension LayoutsSettingsViewController {
    @objc
    func handleSaveLayoutEdits(_ sender: NSButton) {
        _ = prototypeState.commitLayoutsDraft(using: actionHandler)
    }

    @objc
    func handleAddAction(_ sender: NSButton) {
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
    func handleRemoveAction(_ sender: NSButton) {
        guard let selectedNode, removeButton.isEnabled else {
            return
        }
        presentRemoveConfirmation(for: selectedNode)
    }

    func presentRemoveConfirmation(for node: LayoutsTreeNode) {
        let alert = NSAlert()
        alert.messageText = UICopy.settingsRemoveButtonTitle
        alert.informativeText = UICopy.settingsRemoveDraftConfirmationMessage
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

    func mutateLayoutsDraft(preserving selection: NodeSelection?, _ mutate: (inout AppConfiguration) -> Void) {
        pendingSelection = selection
        prototypeState.applyLayoutsMutation(mutate)
    }

    func renameGroup(from oldName: String, to proposedName: String) {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            updateDetailView()
            return
        }

        let normalizedName = trimmedName
        if normalizedName == oldName {
            return
        }

        guard !draftConfiguration.layoutGroups.contains(where: { $0.name == normalizedName }) else {
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

    func updateSetMonitor(groupName: String, setIndex: Int, monitor: LayoutSetMonitor) {
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

    func refreshMonitorMetadata() {
        guard let refreshedConfiguration = actionHandler.refreshMonitorMetadata() else {
            return
        }
        prototypeState.syncExternalConfiguration(refreshedConfiguration)
    }

    func updateLayoutTriggerRegion(groupName: String, setIndex: Int, layoutID: String, triggerRegion: TriggerRegion?) {
        updateLayout(groupName: groupName, setIndex: setIndex, layoutID: layoutID) { draftLayout in
            draftLayout.triggerRegion = triggerRegion
        }
    }

    func updateLayout(
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

    func addGroup() {
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

    func addMonitorSet(toGroupNamed groupName: String) {
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

    func addLayout(toGroupNamed groupName: String, setIndex: Int) {
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

    func nextSetIndex(inGroupNamed groupName: String) -> Int {
        draftConfiguration.layoutGroups.first(where: { $0.name == groupName })?.sets.count ?? 0
    }

    func nextAvailableGroupName() -> String {
        var index = 1
        while draftConfiguration.layoutGroups.contains(where: { $0.name == "Group \(index)" }) {
            index += 1
        }
        return "Group \(index)"
    }

    func nextLayoutID() -> String {
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

    func removeNode(_ node: LayoutsTreeNode) {
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

    func selectionAfterRemoving(node: LayoutsTreeNode) -> NodeSelection? {
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

    func suggestedMonitorForNewSet(inGroupNamed groupName: String) -> LayoutSetMonitor? {
        guard let group = draftConfiguration.layoutGroups.first(where: { $0.name == groupName }) else {
            return nil
        }

        let hasAll = group.sets.contains(where: { $0.monitor == .all })
        if !hasAll {
            return .all
        }

        let hasMain = group.sets.contains(where: { $0.monitor == .main })
        if !hasMain {
            return .main
        }

        let usedDisplayIDs = Set(group.sets.flatMap(\.monitor.explicitDisplayIDs))
        let availableDisplayID = prototypeState.currentMonitorNameMap()
            .keys
            .sorted()
            .first(where: { !usedDisplayIDs.contains($0) })

        if let availableDisplayID {
            return .displays([availableDisplayID])
        }

        return nil
    }

    func removeButtonState(for node: LayoutsTreeNode?) -> (isEnabled: Bool, toolTip: String?) {
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

    func addActionState(for node: LayoutsTreeNode?) -> Bool {
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

    func preferredAddAction(for node: LayoutsTreeNode?) -> AddAction? {
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

    func groupNameForAddAction(from node: LayoutsTreeNode) -> String? {
        switch node.kind {
        case let .group(group, _):
            return group.name
        case let .set(groupName, _, _):
            return groupName
        case let .layout(groupName, _, _, _):
            return groupName
        }
    }

    func setContextForAddAction(from node: LayoutsTreeNode) -> (groupName: String, setIndex: Int)? {
        switch node.kind {
        case let .set(groupName, setIndex, _):
            return (groupName, setIndex)
        case let .layout(groupName, setIndex, _, _):
            return (groupName, setIndex)
        case .group:
            return nil
        }
    }

    func canAssignMonitor(_ monitor: LayoutSetMonitor, toSetAt setIndex: Int, inGroupNamed groupName: String) -> Bool {
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
                guard !hasAllSet else {
                    return false
                }
                hasAllSet = true
            case .main:
                guard !hasMainSet else {
                    return false
                }
                hasMainSet = true
            case let .displays(displayIDs):
                for displayID in displayIDs {
                    guard !explicitDisplayIDs.contains(displayID) else {
                        return false
                    }
                    explicitDisplayIDs.insert(displayID)
                }
            }
        }

        return true
    }

    func layoutPath(
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

    func normalizeLayout(_ layout: inout LayoutPreset) {
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
    func moveLayout(id: String, groupName: String, setIndex: Int, toLocalIndex targetIndex: Int) -> Bool {
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
}

@MainActor
extension LayoutsSettingsViewController {
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

    var saveButtonUsesDefaultActionStyleForTesting: Bool {
        saveButton.keyEquivalent == "\r"
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

    func activateSelectedGroupForTesting() {
        handleOutlineDoubleClick(outlineView)
    }

    func updateSetMonitorForTesting(groupName: String, setIndex: Int, monitor: LayoutSetMonitor) {
        updateSetMonitor(groupName: groupName, setIndex: setIndex, monitor: monitor)
    }

    func updateCurrentLayoutGridSizeForTesting(columns: Int, rows: Int) {
        currentLayoutGridColumnsControl?.setRawValueForTesting(String(columns))
        currentLayoutGridColumnsControl?.commitTextEditingForTesting()
        currentLayoutGridRowsControl?.setRawValueForTesting(String(rows))
        currentLayoutGridRowsControl?.commitTextEditingForTesting()
    }

    var currentLayoutGridSizeValuesForTesting: (columns: Int, rows: Int)? {
        guard let currentLayoutGridColumnsControl,
              let currentLayoutGridRowsControl else {
            return nil
        }
        return (currentLayoutGridColumnsControl.value, currentLayoutGridRowsControl.value)
    }

    var currentLayoutWindowSelectionButtonStateForTesting: (xCanIncrement: Bool, yCanIncrement: Bool, widthCanIncrement: Bool, heightCanIncrement: Bool)? {
        guard let currentLayoutWindowXControl,
              let currentLayoutWindowYControl,
              let currentLayoutWindowWidthControl,
              let currentLayoutWindowHeightControl else {
            return nil
        }
        return (
            currentLayoutWindowXControl.canIncrementForTesting,
            currentLayoutWindowYControl.canIncrementForTesting,
            currentLayoutWindowWidthControl.canIncrementForTesting,
            currentLayoutWindowHeightControl.canIncrementForTesting
        )
    }

    func mutateLayoutsDraftForTesting(_ mutate: (inout AppConfiguration) -> Void) {
        let preservedSelection = selectedNode.map(selectionKey(for:)) ?? firstAvailableSelection(in: treeNodes)
        mutateLayoutsDraft(preserving: preservedSelection, mutate)
    }

    var draftConfigurationForTesting: AppConfiguration {
        draftConfiguration
    }

    var expandedGroupNamesForTesting: [String] {
        treeNodes.compactMap { node in
            guard case let .group(group, _) = node.kind,
                  outlineView.isItemExpanded(node) else {
                return nil
            }
            return group.name
        }
    }

    func expandedSetCountForTesting(groupName: String) -> Int {
        guard let groupNode = treeNodes.first(where: { node in
            guard case let .group(group, _) = node.kind else {
                return false
            }
            return group.name == groupName
        }) else {
            return 0
        }

        return groupNode.children.reduce(into: 0) { count, child in
            if outlineView.isItemExpanded(child) {
                count += 1
            }
        }
    }

    func layoutTreeTitleForTesting(id layoutID: String) -> String? {
        findNode(withLayoutID: layoutID, in: treeNodes)?.title
    }

    private func findNode(withLayoutID layoutID: String, in nodes: [LayoutsTreeNode]) -> LayoutsTreeNode? {
        for node in nodes {
            if case let .layout(_, _, layout, _) = node.kind, layout.id == layoutID {
                return node
            }
            if let match = findNode(withLayoutID: layoutID, in: node.children) {
                return match
            }
        }
        return nil
    }
}
