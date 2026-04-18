import AppKit

@MainActor
final class GeneralSettingsViewController: NSViewController {
    private enum ExclusionSelection {
        case bundleID(Int)
        case windowTitle(Int)
    }

    private var modifierGroups = [
        "Ctrl + Cmd + Shift + Option",
        "Ctrl + Shift + Option",
    ]
    private var excludedBundleIDs = [
        "com.apple.Spotlight",
        "com.example.HiddenApp",
    ]
    private var excludedWindowTitles = [
        "Picture in Picture",
        "Quick Look",
    ]
    private var selectedExclusion: ExclusionSelection?
    private var isUpdatingExclusionSelection = false
    private let exclusionAddButton = NSButton(title: UICopy.settingsAddEllipsisButtonTitle, target: nil, action: nil)
    private let exclusionRemoveButton = NSButton(title: UICopy.settingsRemoveButtonTitle, target: nil, action: nil)

    private lazy var modifierGroupsControl: SelectableListControlView = {
        let control = SelectableListControlView(
            items: modifierGroups,
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
        let contentStackView = makeSettingsPageStackView()
        contentStackView.addArrangedSubview(makeRuntimeRows())
        contentStackView.addArrangedSubview(
            makeSettingsSection(
                title: UICopy.settingsDragBehaviorSectionTitle,
                rows: [
                    makeCheckboxRow(title: UICopy.mouseButtonDragMenuTitle(mouseButtonNumber: 3)),
                    makeLabeledControlRow(label: UICopy.settingsMouseButtonNumberLabel, control: makeMouseButtonPopup()),
                    makeCheckboxRow(title: UICopy.modifierLeftMouseDragMenuTitle),
                    makeLabeledControlRow(label: UICopy.settingsModifierGroupsLabel, control: modifierGroupsControl),
                    makeCheckboxRow(title: UICopy.preferLayoutModeMenuTitle),
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
    }

    private func makeRuntimeRows() -> NSView {
        let rowsStackView = makeVerticalGroup(spacing: 9)
        rowsStackView.addArrangedSubview(makeCheckboxRow(title: UICopy.enableMenuTitle))
        rowsStackView.addArrangedSubview(makeCheckboxRow(title: UICopy.launchAtLoginMenuTitle))
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
            self.modifierGroups.append(sheetContentView.selectedModifierDisplayName)
            self.modifierGroupsControl.items = self.modifierGroups
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
        switch sheetContentView.selectedKind {
        case .bundleID:
            excludedBundleIDs.append(sheetContentView.resolvedValue)
            excludedBundleIDsControl.items = excludedBundleIDs
            excludedBundleIDsControl.selectItem(at: excludedBundleIDs.indices.last)
            selectedExclusion = .bundleID(excludedBundleIDs.count - 1)
        case .windowTitle:
            excludedWindowTitles.append(sheetContentView.resolvedValue)
            excludedWindowTitlesControl.items = excludedWindowTitles
            excludedWindowTitlesControl.selectItem(at: excludedWindowTitles.indices.last)
            selectedExclusion = .windowTitle(excludedWindowTitles.count - 1)
        }
        updateExclusionButtons()
    }

    private func removeModifierGroup(at index: Int) {
        guard modifierGroups.indices.contains(index) else {
            return
        }
        modifierGroups.remove(at: index)
        modifierGroupsControl.items = modifierGroups
    }

    private func removeExcludedBundleID(at index: Int) {
        guard excludedBundleIDs.indices.contains(index) else {
            return
        }
        excludedBundleIDs.remove(at: index)
        excludedBundleIDsControl.items = excludedBundleIDs
    }

    private func removeExcludedWindowTitle(at index: Int) {
        guard excludedWindowTitles.indices.contains(index) else {
            return
        }
        excludedWindowTitles.remove(at: index)
        excludedWindowTitlesControl.items = excludedWindowTitles
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
        case .bundleID(_):
            excludedWindowTitlesControl.selectItem(at: nil)
        case .windowTitle(_):
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
    private func handleAddExclusion(_ sender: NSButton) {
        let initialKind: ExclusionEntrySheetContentView.Kind
        switch selectedExclusion {
        case .windowTitle(_):
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
