import AppKit

@MainActor
final class GeneralSettingsViewController: NSViewController {
    private let prototypeState: SettingsPrototypeState
    private let actionHandler: any SettingsActionHandling

    private enum ExclusionSelection {
        case bundleID(Int)
        case windowTitle(Int)
    }

    private var selectedExclusion: ExclusionSelection?
    private var isUpdatingExclusionSelection = false
    private let exclusionAddButton = NSButton(title: UICopy.settingsAddEllipsisButtonTitle, target: nil, action: nil)
    private let exclusionRemoveButton = NSButton(title: UICopy.settingsRemoveButtonTitle, target: nil, action: nil)

    private lazy var enableCheckbox = makeCheckboxRow(title: UICopy.enableMenuTitle)
    private lazy var launchAtLoginCheckbox = makeCheckboxRow(title: UICopy.launchAtLoginMenuTitle)
    private lazy var mouseButtonDragCheckbox = makeCheckboxRow(title: UICopy.mouseButtonDragMenuTitle(mouseButtonNumber: 3))
    private lazy var mouseButtonControl = makeMouseButtonControl()
    private lazy var modifierLeftMouseDragCheckbox = makeCheckboxRow(title: UICopy.modifierLeftMouseDragMenuTitle)
    private lazy var preferLayoutModeCheckbox = makeCheckboxRow(title: UICopy.preferLayoutModeMenuTitle)
    private lazy var applyLayoutImmediatelyWhileDraggingCheckbox = makeCheckboxRow(
        title: UICopy.applyLayoutImmediatelyWhileDraggingTitle
    )
    private let enableDescriptionLabel = makeSecondaryLabel(UICopy.enableMenuDescription)
    private let preferLayoutModeDescriptionLabel = makeSecondaryLabel("")

    init(prototypeState: SettingsPrototypeState, actionHandler: any SettingsActionHandling) {
        self.prototypeState = prototypeState
        self.actionHandler = actionHandler
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private lazy var modifierGroupsControl: SelectableListControlView = {
        let control = SelectableListControlView(
            items: modifierGroupDisplayNames,
            addButtonTitle: UICopy.settingsAddEllipsisButtonTitle,
            width: 420
        )
        control.onAdd = { [weak self] in
            self?.presentModifierGroupSheet()
        }
        control.onRemove = { [weak self] index in
            self?.removeModifierGroup(at: index)
        }
        return control
    }()

    private lazy var excludedBundleIDsControl: SelectableListControlView = {
        let control = SelectableListControlView(items: excludedBundleIDs, width: 420, showsButtons: false)
        control.onSelectionChanged = { [weak self] index in
            self?.updateSelectedExclusion(index.map(ExclusionSelection.bundleID))
        }
        return control
    }()

    private lazy var excludedWindowTitlesControl: SelectableListControlView = {
        let control = SelectableListControlView(items: excludedWindowTitles, width: 420, showsButtons: false)
        control.onSelectionChanged = { [weak self] index in
            self?.updateSelectedExclusion(index.map(ExclusionSelection.windowTitle))
        }
        return control
    }()

    override func loadView() {
        configureControls()

        let contentStackView = makeSettingsPageStackView()
        contentStackView.addArrangedSubview(makeRuntimeRows())
        contentStackView.addArrangedSubview(
            makeSettingsSection(
                title: UICopy.settingsDragBehaviorSectionTitle,
                rows: [
                    mouseButtonDragCheckbox,
                    makeLabeledControlRow(label: UICopy.settingsMouseButtonNumberLabel, control: mouseButtonControl),
                    modifierLeftMouseDragCheckbox,
                    makeLabeledControlRow(label: UICopy.settingsModifierGroupsLabel, control: modifierGroupsControl),
                    makeCheckboxWithDescription(
                        checkbox: preferLayoutModeCheckbox,
                        descriptionLabel: preferLayoutModeDescriptionLabel
                    ),
                    applyLayoutImmediatelyWhileDraggingCheckbox,
                ]
            )
        )
        contentStackView.addArrangedSubview(
            makeSettingsSection(
                title: UICopy.settingsExclusionsSectionTitle,
                rows: [
                    makeLabeledControlRow(label: UICopy.settingsExcludedBundleIDsLabel, control: excludedBundleIDsControl),
                    makeLabeledControlRow(label: UICopy.settingsExcludedWindowTitlesLabel, control: excludedWindowTitlesControl),
                    makeExclusionButtonsRow(),
                ]
            )
        )

        view = makeSettingsPageContainerView(contentView: contentStackView)
        title = UICopy.settingsGeneralTabTitle
        syncFromState()
        observePrototypeState()
    }

    private var modifierGroups: [[ModifierKey]] {
        prototypeState.configuration.dragTriggers.modifierGroups
    }

    private var modifierGroupDisplayNames: [String] {
        modifierGroups.map { group in
            ModifierKey.allCases
                .filter { group.contains($0) }
                .map(\.displayName)
                .joined(separator: " + ")
        }
    }

    private var excludedBundleIDs: [String] {
        prototypeState.configuration.general.excludedBundleIDs
    }

    private var excludedWindowTitles: [String] {
        prototypeState.configuration.general.excludedWindowTitles
    }

    private func configureControls() {
        enableCheckbox.target = self
        enableCheckbox.action = #selector(handleEnableToggle(_:))

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(handleLaunchAtLoginToggle(_:))

        mouseButtonDragCheckbox.target = self
        mouseButtonDragCheckbox.action = #selector(handleMouseButtonDragToggle(_:))

        mouseButtonControl.onValueChanged = { [weak self] value in
            self?.applyMouseButtonNumber(value)
        }

        modifierLeftMouseDragCheckbox.target = self
        modifierLeftMouseDragCheckbox.action = #selector(handleModifierLeftMouseDragToggle(_:))

        preferLayoutModeCheckbox.target = self
        preferLayoutModeCheckbox.action = #selector(handlePreferLayoutModeToggle(_:))

        applyLayoutImmediatelyWhileDraggingCheckbox.target = self
        applyLayoutImmediatelyWhileDraggingCheckbox.action = #selector(handleApplyLayoutImmediatelyWhileDraggingToggle(_:))
    }

    private func observePrototypeState() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePrototypeStateDidChange(_:)),
            name: .settingsPrototypeStateDidChange,
            object: prototypeState
        )
    }

    private func syncFromState() {
        let configuration = prototypeState.configuration
        enableCheckbox.state = configuration.general.isEnabled ? .on : .off
        launchAtLoginCheckbox.state = configuration.general.launchAtLogin ? .on : .off
        mouseButtonDragCheckbox.state = configuration.dragTriggers.enableMouseButtonDrag ? .on : .off
        mouseButtonDragCheckbox.title = UICopy.mouseButtonDragMenuTitle(
            mouseButtonNumber: configuration.general.mouseButtonNumber
        )
        mouseButtonControl.setValue(configuration.general.mouseButtonNumber)
        modifierLeftMouseDragCheckbox.state = configuration.dragTriggers.enableModifierLeftMouseDrag ? .on : .off
        preferLayoutModeCheckbox.state = configuration.dragTriggers.preferLayoutMode ? .on : .off
        applyLayoutImmediatelyWhileDraggingCheckbox.state = configuration.dragTriggers.applyLayoutImmediatelyWhileDragging ? .on : .off
        preferLayoutModeDescriptionLabel.stringValue = configuration.dragTriggers.preferLayoutMode
            ? UICopy.preferLayoutModeEnabledDescription
            : UICopy.preferLayoutModeDisabledDescription

        modifierGroupsControl.items = modifierGroupDisplayNames
        excludedBundleIDsControl.items = excludedBundleIDs
        excludedWindowTitlesControl.items = excludedWindowTitles

        if let selectedExclusion {
            switch selectedExclusion {
            case let .bundleID(index) where !excludedBundleIDs.indices.contains(index):
                self.selectedExclusion = nil
            case let .windowTitle(index) where !excludedWindowTitles.indices.contains(index):
                self.selectedExclusion = nil
            default:
                break
            }
        }

        updateExclusionButtons()
    }

    @objc
    private func handlePrototypeStateDidChange(_ notification: Notification) {
        syncFromState()
    }

    private func makeRuntimeRows() -> NSView {
        let rowsStackView = makeVerticalGroup(spacing: 9)
        rowsStackView.addArrangedSubview(
            makeCheckboxWithDescription(
                checkbox: enableCheckbox,
                descriptionLabel: enableDescriptionLabel
            )
        )
        rowsStackView.addArrangedSubview(launchAtLoginCheckbox)
        return makeIndentedContainer(for: rowsStackView)
    }

    private func presentModifierGroupSheet() {
        let sheetContentView = ModifierGroupSheetContentView()
        let sheetController = SettingsPrototypeSheetController(
            title: UICopy.settingsAddModifierGroupSheetTitle,
            message: UICopy.settingsAddModifierGroupSheetMessage,
            bodyView: sheetContentView,
            confirmButtonTitle: UICopy.settingsAddButtonTitle
        ) { [weak self] in
            guard let self else {
                return
            }

            let selectedModifiers = sheetContentView.selectedModifiers
            if let existingIndex = self.modifierGroups.firstIndex(of: selectedModifiers) {
                self.modifierGroupsControl.selectItem(at: existingIndex)
                return
            }

            _ = self.prototypeState.applyImmediateMutation(using: self.actionHandler) { configuration in
                configuration.dragTriggers.modifierGroups.append(selectedModifiers)
            }
            self.modifierGroupsControl.selectItem(at: self.modifierGroups.count - 1)
        }
        presentAsSheet(sheetController)
    }

    private func presentExclusionSheet(initialKind: ExclusionEntrySheetContentView.Kind) {
        let sheetContentView = ExclusionEntrySheetContentView(initialKind: initialKind)
        let sheetController = SettingsPrototypeSheetController(
            title: UICopy.settingsAddExclusionSheetTitle,
            message: UICopy.settingsAddExclusionSheetMessage,
            bodyView: sheetContentView,
            confirmButtonTitle: UICopy.settingsAddButtonTitle
        ) { [weak self] in
            self?.applyExclusionSheetResult(sheetContentView)
        }
        presentAsSheet(sheetController)
    }

    private func applyExclusionSheetResult(_ sheetContentView: ExclusionEntrySheetContentView) {
        let value = sheetContentView.resolvedValue
        guard value.isEmpty == false else {
            return
        }
        switch sheetContentView.selectedKind {
        case .bundleID:
            if prototypeState.applyImmediateMutation(using: actionHandler, { configuration in
                configuration.general.excludedBundleIDs.append(value)
            }) {
                selectedExclusion = .bundleID(excludedBundleIDs.count - 1)
                excludedBundleIDsControl.selectItem(at: excludedBundleIDs.indices.last)
            }
        case .windowTitle:
            if prototypeState.applyImmediateMutation(using: actionHandler, { configuration in
                configuration.general.excludedWindowTitles.append(value)
            }) {
                selectedExclusion = .windowTitle(excludedWindowTitles.count - 1)
                excludedWindowTitlesControl.selectItem(at: excludedWindowTitles.indices.last)
            }
        }
        updateExclusionButtons()
    }

    private func removeModifierGroup(at index: Int) {
        guard modifierGroups.indices.contains(index) else {
            return
        }

        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.dragTriggers.modifierGroups.remove(at: index)
        }
    }

    private func removeExcludedBundleID(at index: Int) {
        guard excludedBundleIDs.indices.contains(index) else {
            return
        }

        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.general.excludedBundleIDs.remove(at: index)
        }
    }

    private func removeExcludedWindowTitle(at index: Int) {
        guard excludedWindowTitles.indices.contains(index) else {
            return
        }

        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.general.excludedWindowTitles.remove(at: index)
        }
    }

    private func makeExclusionButtonsRow() -> NSView {
        exclusionAddButton.bezelStyle = .rounded
        exclusionAddButton.target = self
        exclusionAddButton.action = #selector(handleAddExclusion(_:))

        exclusionRemoveButton.bezelStyle = .rounded
        exclusionRemoveButton.target = self
        exclusionRemoveButton.action = #selector(handleRemoveExclusion(_:))

        updateExclusionButtons()

        let buttonsRow = makeHorizontalGroup(spacing: 8)
        buttonsRow.addArrangedSubview(NSView())
        buttonsRow.addArrangedSubview(exclusionAddButton)
        buttonsRow.addArrangedSubview(exclusionRemoveButton)

        let controlContainer = NSView()
        buttonsRow.translatesAutoresizingMaskIntoConstraints = false
        controlContainer.translatesAutoresizingMaskIntoConstraints = false
        controlContainer.widthAnchor.constraint(equalToConstant: 420).isActive = true
        controlContainer.addSubview(buttonsRow)

        NSLayoutConstraint.activate([
            buttonsRow.leadingAnchor.constraint(equalTo: controlContainer.leadingAnchor),
            buttonsRow.trailingAnchor.constraint(equalTo: controlContainer.trailingAnchor),
            buttonsRow.topAnchor.constraint(equalTo: controlContainer.topAnchor),
            buttonsRow.bottomAnchor.constraint(equalTo: controlContainer.bottomAnchor),
        ])

        return makeLabeledControlRow(label: "", control: controlContainer)
    }

    private func updateSelectedExclusion(_ selection: ExclusionSelection?) {
        guard !isUpdatingExclusionSelection else {
            return
        }

        isUpdatingExclusionSelection = true
        defer { isUpdatingExclusionSelection = false }
        selectedExclusion = selection

        switch selection {
        case .bundleID:
            excludedWindowTitlesControl.selectItem(at: nil)
        case .windowTitle:
            excludedBundleIDsControl.selectItem(at: nil)
        case nil:
            break
        }

        updateExclusionButtons()
    }

    private func updateExclusionButtons() {
        exclusionRemoveButton.isEnabled = selectedExclusion != nil
    }

    @objc
    private func handleEnableToggle(_ sender: NSButton) {
        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.general.isEnabled = sender.state == .on
        }
    }

    @objc
    private func handleLaunchAtLoginToggle(_ sender: NSButton) {
        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.general.launchAtLogin = sender.state == .on
        }
    }

    @objc
    private func handleMouseButtonDragToggle(_ sender: NSButton) {
        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.dragTriggers.enableMouseButtonDrag = sender.state == .on
        }
    }

    private func applyMouseButtonNumber(_ mouseButtonNumber: Int) {
        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.general.mouseButtonNumber = mouseButtonNumber
        }
    }

    @objc
    private func handleModifierLeftMouseDragToggle(_ sender: NSButton) {
        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.dragTriggers.enableModifierLeftMouseDrag = sender.state == .on
        }
    }

    @objc
    private func handlePreferLayoutModeToggle(_ sender: NSButton) {
        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.dragTriggers.preferLayoutMode = sender.state == .on
        }
    }

    @objc
    private func handleApplyLayoutImmediatelyWhileDraggingToggle(_ sender: NSButton) {
        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.dragTriggers.applyLayoutImmediatelyWhileDragging = sender.state == .on
        }
    }

    @objc
    private func handleAddExclusion(_ sender: NSButton) {
        let initialKind: ExclusionEntrySheetContentView.Kind
        switch selectedExclusion {
        case .windowTitle:
            initialKind = .windowTitle
        default:
            initialKind = .bundleID
        }
        presentExclusionSheet(initialKind: initialKind)
    }

    @objc
    private func handleRemoveExclusion(_ sender: NSButton) {
        switch selectedExclusion {
        case let .bundleID(index):
            removeExcludedBundleID(at: index)
            selectedExclusion = nil
            excludedBundleIDsControl.selectItem(at: nil)
        case let .windowTitle(index):
            removeExcludedWindowTitle(at: index)
            selectedExclusion = nil
            excludedWindowTitlesControl.selectItem(at: nil)
        case nil:
            break
        }

        updateExclusionButtons()
    }
}

extension GeneralSettingsViewController {
    var isEnabledForTesting: Bool {
        enableCheckbox.state == .on
    }

    func setEnabledForTesting(_ isEnabled: Bool) {
        enableCheckbox.state = isEnabled ? .on : .off
        handleEnableToggle(enableCheckbox)
    }

    func setLaunchAtLoginForTesting(_ isEnabled: Bool) {
        launchAtLoginCheckbox.state = isEnabled ? .on : .off
        handleLaunchAtLoginToggle(launchAtLoginCheckbox)
    }

    func setMouseButtonDragForTesting(_ isEnabled: Bool) {
        mouseButtonDragCheckbox.state = isEnabled ? .on : .off
        handleMouseButtonDragToggle(mouseButtonDragCheckbox)
    }

    func setMouseButtonNumberForTesting(_ mouseButtonNumber: Int) {
        mouseButtonControl.setValue(mouseButtonNumber)
        applyMouseButtonNumber(mouseButtonControl.value)
    }

    func setRawMouseButtonNumberForTesting(_ value: String) {
        mouseButtonControl.setRawValueForTesting(value)
        mouseButtonControl.commitTextEditingForTesting()
    }

    func decrementMouseButtonNumberForTesting() {
        mouseButtonControl.decrementForTesting()
    }

    var mouseButtonNumberValueForTesting: Int {
        mouseButtonControl.value
    }

    func setModifierLeftMouseDragForTesting(_ isEnabled: Bool) {
        modifierLeftMouseDragCheckbox.state = isEnabled ? .on : .off
        handleModifierLeftMouseDragToggle(modifierLeftMouseDragCheckbox)
    }

    func setPreferLayoutModeForTesting(_ isEnabled: Bool) {
        preferLayoutModeCheckbox.state = isEnabled ? .on : .off
        handlePreferLayoutModeToggle(preferLayoutModeCheckbox)
    }

    func setApplyLayoutImmediatelyWhileDraggingForTesting(_ isEnabled: Bool) {
        applyLayoutImmediatelyWhileDraggingCheckbox.state = isEnabled ? .on : .off
        handleApplyLayoutImmediatelyWhileDraggingToggle(applyLayoutImmediatelyWhileDraggingCheckbox)
    }

    var preferLayoutModeDescriptionForTesting: String {
        preferLayoutModeDescriptionLabel.stringValue
    }

    var enableDescriptionForTesting: String {
        enableDescriptionLabel.stringValue
    }

    var excludedWindowTitlesForTesting: [String] {
        excludedWindowTitles
    }

    func addModifierGroupForTesting(_ modifierKeys: [ModifierKey]) {
        if let existingIndex = modifierGroups.firstIndex(of: modifierKeys) {
            modifierGroupsControl.selectItem(at: existingIndex)
            return
        }

        _ = prototypeState.applyImmediateMutation(using: actionHandler) { configuration in
            configuration.dragTriggers.modifierGroups.append(modifierKeys)
        }
    }

    func addExcludedBundleIDForTesting(_ value: String) {
        if prototypeState.applyImmediateMutation(using: actionHandler, { configuration in
            configuration.general.excludedBundleIDs.append(value)
        }) {
            selectedExclusion = .bundleID(excludedBundleIDs.count - 1)
        }
    }

    func addExcludedWindowTitleForTesting(_ value: String) {
        if prototypeState.applyImmediateMutation(using: actionHandler, { configuration in
            configuration.general.excludedWindowTitles.append(value)
        }) {
            selectedExclusion = .windowTitle(excludedWindowTitles.count - 1)
        }
    }

    func submitExclusionForTesting(kind: ExclusionEntrySheetContentView.Kind, value: String) {
        let sheetContentView = ExclusionEntrySheetContentView(initialKind: kind)
        sheetContentView.setValueForTesting(value)
        applyExclusionSheetResult(sheetContentView)
    }
}
