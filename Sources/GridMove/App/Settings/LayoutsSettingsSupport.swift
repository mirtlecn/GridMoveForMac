import AppKit

@MainActor
final class ApplyToControlView: NSView {
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
final class TriggerTabContentView: NSView {
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

final class LayoutsTreeNode {
    enum Kind {
        case group(LayoutGroup, isActive: Bool)
        case set(groupName: String, setIndex: Int, set: LayoutSet)
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
                    LayoutsTreeNode(
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
                    kind: .set(groupName: group.name, setIndex: setIndex, set: set),
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

final class LayoutsOutlineView: NSOutlineView {
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

final class LayoutTreeCellView: NSTableCellView {
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

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
