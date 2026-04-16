import AppKit
import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    enum LayoutPageMode: Equatable {
        case list
        case detail
    }

    enum Section: String, CaseIterable, Identifiable {
        case general
        case layouts
        case appearance
        case hotkeys
        case about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: return UICopy.generalSectionTitle
            case .layouts: return UICopy.layoutsSectionTitle
            case .appearance: return UICopy.appearanceSectionTitle
            case .hotkeys: return UICopy.hotkeysSectionTitle
            case .about: return UICopy.aboutSectionTitle
            }
        }

        var systemImage: String {
            switch self {
            case .general: return "slider.horizontal.3"
            case .layouts: return "square.grid.3x3"
            case .appearance: return "paintpalette"
            case .hotkeys: return "keyboard"
            case .about: return "info.circle"
            }
        }
    }

    struct ModifierGroupItem: Identifiable, Equatable {
        let id: String
        let index: Int
        let keys: [ModifierKey]

        var title: String {
            keys.map(\.displayName).joined(separator: " + ")
        }
    }

    struct ExcludedWindowItem: Identifiable, Equatable {
        let id: String
        let index: Int
        let value: String
        let kind: EntryKind
    }

    struct LayoutListItem: Identifiable, Equatable {
        let id: String
        let displayID: String
        let title: String
    }

    enum EntryKind: String, Identifiable {
        case bundleID
        case windowTitle

        var id: String { rawValue }

        var columnTitle: String {
            switch self {
            case .bundleID: return UICopy.bundleIDTitle
            case .windowTitle: return UICopy.windowTitle
            }
        }
    }

    @Published var configuration: AppConfiguration
    @Published var selectedSection: Section = .general
    @Published var selectedLayoutID: String?
    @Published var layoutDraft: LayoutPreset?
    @Published var statusMessage: String = ""
    @Published var layoutPageMode: LayoutPageMode = .list
    @Published var layoutDeleteArmed = false
    @Published var excludedWindowSheetPresented = false
    @Published var modifierGroupSheetPresented = false
    @Published var selectedModifierGroupID: String?
    @Published var selectedExcludedWindowID: String?
    @Published var selectedHotkeyBindingID: String?

    private let configurationStore: ConfigurationStore
    private let onConfigurationSaved: (AppConfiguration) -> Void
    private var backStack: [Section] = []
    private var forwardStack: [Section] = []
    private var layoutForwardSelectionID: String?

    init(
        configurationStore: ConfigurationStore,
        configurationProvider: @escaping () -> AppConfiguration,
        onConfigurationSaved: @escaping (AppConfiguration) -> Void
    ) {
        self.configurationStore = configurationStore
        self.onConfigurationSaved = onConfigurationSaved
        configuration = configurationProvider()
        selectedLayoutID = configuration.layouts.first?.id
        layoutDraft = configuration.layouts.first
    }

    var directBindings: [ShortcutBinding] {
        configuration.hotkeys.bindings.filter {
            switch $0.action {
            case .applyLayout:
                return true
            default:
                return false
            }
        }
    }

    var previousCycleBindings: [ShortcutBinding] {
        configuration.hotkeys.bindings.filter { $0.action == .cyclePrevious }
    }

    var nextCycleBindings: [ShortcutBinding] {
        configuration.hotkeys.bindings.filter { $0.action == .cycleNext }
    }

    var directActionOptions: [(String, HotkeyAction)] {
        configuration.layouts.map { ($0.name, HotkeyAction.applyLayout(layoutID: $0.id)) }
    }

    var hotkeyItems: [ShortcutBinding] {
        configuration.hotkeys.bindings
    }

    var hotkeyActionOptions: [(String, HotkeyAction)] {
        configuration.layouts.map { (UICopy.applyLayout(layoutDisplayLabel(for: $0)), HotkeyAction.applyLayout(layoutID: $0.id)) }
        + [
            (UICopy.applyNextLayout, .cycleNext),
            (UICopy.applyPreviousLayout, .cyclePrevious),
        ]
    }

    var layoutItems: [LayoutListItem] {
        configuration.layouts.enumerated().map { index, layout in
            LayoutListItem(
                id: layout.id,
                displayID: makeLayoutDisplayID(for: index),
                title: layoutDisplayLabel(for: layout, index: index)
            )
        }
    }

    var selectedLayoutDisplayID: String {
        guard let selectedLayoutID,
              let index = configuration.layouts.firstIndex(where: { $0.id == selectedLayoutID }) else {
            return UICopy.layoutsSectionTitle
        }
        return makeLayoutDisplayID(for: index)
    }

    var hasUnsavedLayoutChanges: Bool {
        guard let selectedLayoutID,
              let layoutDraft,
              let layout = configuration.layouts.first(where: { $0.id == selectedLayoutID }) else {
            return false
        }
        return layout != layoutDraft
    }

    var canDeleteSelectedLayout: Bool {
        configuration.layouts.count > 1 && selectedLayoutID != nil
    }

    var modifierGroupItems: [ModifierGroupItem] {
        configuration.dragTriggers.modifierGroups.enumerated().map { index, keys in
            ModifierGroupItem(
                id: "modifier-\(index)-\(keys.map(\.rawValue).joined(separator: "-"))",
                index: index,
                keys: keys
            )
        }
    }

    var excludedWindowItems: [ExcludedWindowItem] {
        let bundleIDItems = configuration.general.excludedBundleIDs.enumerated().map { index, value in
            ExcludedWindowItem(
                id: "bundle-\(index)-\(value)",
                index: index,
                value: value,
                kind: .bundleID
            )
        }

        let titleItems = configuration.general.excludedWindowTitles.enumerated().map { index, value in
            ExcludedWindowItem(
                id: "title-\(index)-\(value)",
                index: index,
                value: value,
                kind: .windowTitle
            )
        }

        return bundleIDItems + titleItems
    }

    func show() {
        if selectedLayoutID == nil {
            selectedLayoutID = configuration.layouts.first?.id
            layoutDraft = configuration.layouts.first
        }
        synchronizeSelectionState()
    }

    var canNavigateBack: Bool {
        !backStack.isEmpty
    }

    var canNavigateForward: Bool {
        !forwardStack.isEmpty
    }

    func navigateToSection(_ section: Section) {
        guard section != selectedSection else {
            return
        }

        backStack.append(selectedSection)
        forwardStack.removeAll()
        selectedSection = section
    }

    func navigateBack() {
        guard let previousSection = backStack.popLast() else {
            return
        }

        forwardStack.append(selectedSection)
        selectedSection = previousSection
    }

    func navigateForward() {
        guard let nextSection = forwardStack.popLast() else {
            return
        }

        backStack.append(selectedSection)
        selectedSection = nextSection
    }

    func openExcludedWindowSheet() {
        excludedWindowSheetPresented = true
    }

    func addExcludedWindow(kind: EntryKind, value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return
        }

        switch kind {
        case .bundleID:
            configuration.general.excludedBundleIDs.append(trimmedValue)
            persistConfiguration(status: UICopy.excludedBundleIDAdded)
        case .windowTitle:
            configuration.general.excludedWindowTitles.append(trimmedValue)
            persistConfiguration(status: UICopy.excludedWindowTitleAdded)
        }
    }

    func replaceConfiguration(_ configuration: AppConfiguration) {
        self.configuration = configuration

        if let selectedLayoutID,
           let matchedLayout = configuration.layouts.first(where: { $0.id == selectedLayoutID }) {
            layoutDraft = matchedLayout
        } else {
            selectedLayoutID = configuration.layouts.first?.id
            layoutDraft = configuration.layouts.first
        }

        layoutDeleteArmed = false
        synchronizeSelectionState()
    }

    func removeBundleID(at index: Int) {
        guard configuration.general.excludedBundleIDs.indices.contains(index) else {
            return
        }
        configuration.general.excludedBundleIDs.remove(at: index)
        persistConfiguration(status: UICopy.excludedBundleIDRemoved)
    }

    func removeWindowTitle(at index: Int) {
        guard configuration.general.excludedWindowTitles.indices.contains(index) else {
            return
        }
        configuration.general.excludedWindowTitles.remove(at: index)
        persistConfiguration(status: UICopy.excludedWindowTitleRemoved)
    }

    func removeSelectedExcludedWindow() {
        guard let selectedExcludedWindowID,
              let selectedItem = excludedWindowItems.first(where: { $0.id == selectedExcludedWindowID }) else {
            return
        }

        switch selectedItem.kind {
        case .bundleID:
            removeBundleID(at: selectedItem.index)
        case .windowTitle:
            removeWindowTitle(at: selectedItem.index)
        }
    }

    func updateDragTriggers(
        enableMiddleMouseDrag: Bool? = nil,
        enableModifierLeftMouseDrag: Bool? = nil
    ) {
        if let enableMiddleMouseDrag {
            configuration.dragTriggers.enableMiddleMouseDrag = enableMiddleMouseDrag
        }
        if let enableModifierLeftMouseDrag {
            configuration.dragTriggers.enableModifierLeftMouseDrag = enableModifierLeftMouseDrag
        }
        persistConfiguration(status: UICopy.dragTriggersUpdated)
    }

    func updateGeneralEnabled(_ isEnabled: Bool) {
        configuration.general.isEnabled = isEnabled
        persistConfiguration(status: UICopy.globalEnableUpdated)
    }

    func addModifierGroup(_ group: [ModifierKey]) {
        guard !group.isEmpty else {
            return
        }
        configuration.dragTriggers.modifierGroups.append(group)
        persistConfiguration(status: UICopy.modifierGroupAdded)
    }

    func removeModifierGroup(at index: Int) {
        guard configuration.dragTriggers.modifierGroups.indices.contains(index) else {
            return
        }
        configuration.dragTriggers.modifierGroups.remove(at: index)
        persistConfiguration(status: UICopy.modifierGroupRemoved)
    }

    func removeSelectedModifierGroup() {
        guard let selectedModifierGroupID,
              let selectedItem = modifierGroupItems.first(where: { $0.id == selectedModifierGroupID }) else {
            return
        }
        removeModifierGroup(at: selectedItem.index)
    }

    func selectLayout(id: String?) {
        selectedLayoutID = id
        layoutDraft = configuration.layouts.first(where: { $0.id == id })
        layoutDeleteArmed = false
    }

    func updateLayoutDraft(_ mutate: (inout LayoutPreset) -> Void) {
        guard var draft = layoutDraft else {
            return
        }
        mutate(&draft)
        draft.gridColumns = max(1, draft.gridColumns)
        draft.gridRows = max(1, draft.gridRows)
        draft.windowSelection = clamp(draft.windowSelection, columns: draft.gridColumns, rows: draft.gridRows)
        draft.triggerRegion = clamp(draft.triggerRegion, columns: draft.gridColumns, rows: draft.gridRows)
        layoutDraft = draft
        layoutDeleteArmed = false
    }

    func addLayout() {
        let preset = LayoutPreset(
            id: UUID().uuidString,
            name: "",
            gridColumns: 12,
            gridRows: 6,
            windowSelection: GridSelection(x: 3, y: 1, w: 6, h: 4),
            triggerRegion: .screen(GridSelection(x: 3, y: 1, w: 6, h: 4)),
            includeInCycle: true
        )
        configuration.layouts.append(preset)
        selectedLayoutID = preset.id
        layoutDraft = preset
        layoutPageMode = .detail
        layoutForwardSelectionID = nil
        persistConfiguration(status: UICopy.layoutAdded)
    }

    func openLayoutDetail(id: String) {
        selectLayout(id: id)
        layoutPageMode = .detail
        layoutForwardSelectionID = nil
    }

    func showLayoutsList() {
        guard layoutPageMode == .detail else {
            return
        }
        layoutForwardSelectionID = selectedLayoutID
        layoutPageMode = .list
        layoutDeleteArmed = false
    }

    func reopenLayoutDetail() {
        guard layoutPageMode == .list,
              let layoutForwardSelectionID else {
            return
        }
        openLayoutDetail(id: layoutForwardSelectionID)
    }

    var canNavigateToLayoutDetail: Bool {
        layoutPageMode == .list && layoutForwardSelectionID != nil
    }

    func deleteSelectedLayout() {
        guard configuration.layouts.count > 1, let selectedLayoutID else {
            statusMessage = UICopy.atLeastOneLayoutRequired
            return
        }

        guard layoutDeleteArmed else {
            layoutDeleteArmed = true
            return
        }

        configuration.removeLayout(id: selectedLayoutID)
        self.selectedLayoutID = configuration.layouts.first?.id
        layoutDraft = configuration.layouts.first(where: { $0.id == self.selectedLayoutID })
        layoutPageMode = .list
        layoutDeleteArmed = false
        layoutForwardSelectionID = nil
        persistConfiguration(status: UICopy.layoutRemoved)
    }

    func moveLayout(id: String, before targetID: String) {
        guard id != targetID,
              let sourceIndex = configuration.layouts.firstIndex(where: { $0.id == id }),
              let targetIndex = configuration.layouts.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        let movedLayout = configuration.layouts.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        configuration.layouts.insert(movedLayout, at: adjustedTargetIndex)

        selectedLayoutID = layoutDraft?.id ?? selectedLayoutID ?? configuration.layouts.first?.id
        persistConfiguration(status: UICopy.layoutOrderUpdated)
    }

    func saveLayoutDraft() {
        guard let layoutDraft, let index = configuration.layouts.firstIndex(where: { $0.id == layoutDraft.id }) else {
            return
        }
        configuration.layouts[index] = layoutDraft
        layoutDeleteArmed = false
        layoutForwardSelectionID = layoutDraft.id
        layoutPageMode = .list
        persistConfiguration(status: UICopy.layoutSaved)
    }

    func updateAppearance(_ mutate: (inout AppearanceSettings) -> Void) {
        mutate(&configuration.appearance)
        configuration.appearance.triggerGap = max(0, configuration.appearance.triggerGap)
        configuration.appearance.highlightStrokeWidth = max(1, configuration.appearance.highlightStrokeWidth)
        persistConfiguration(status: UICopy.appearanceUpdated)
    }

    func resetTriggerAppearanceToDefaults() {
        let defaults = AppConfiguration.defaultValue.appearance
        configuration.appearance.renderTriggerAreas = defaults.renderTriggerAreas
        configuration.appearance.triggerOpacity = defaults.triggerOpacity
        configuration.appearance.triggerGap = defaults.triggerGap
        configuration.appearance.triggerStrokeColor = defaults.triggerStrokeColor
        persistConfiguration(status: UICopy.triggerAppearanceReset)
    }

    func resetWindowAppearanceToDefaults() {
        let defaults = AppConfiguration.defaultValue.appearance
        configuration.appearance.renderWindowHighlight = defaults.renderWindowHighlight
        configuration.appearance.highlightFillOpacity = defaults.highlightFillOpacity
        configuration.appearance.highlightStrokeWidth = defaults.highlightStrokeWidth
        configuration.appearance.highlightStrokeColor = defaults.highlightStrokeColor
        persistConfiguration(status: UICopy.windowAppearanceReset)
    }

    func replaceBinding(_ binding: ShortcutBinding) {
        guard let index = configuration.hotkeys.bindings.firstIndex(where: { $0.id == binding.id }) else {
            return
        }
        configuration.hotkeys.bindings[index] = binding
        persistConfiguration(status: UICopy.hotkeysUpdated)
    }

    func deleteBinding(_ bindingID: String) {
        configuration.hotkeys.bindings.removeAll { $0.id == bindingID }
        persistConfiguration(status: UICopy.hotkeyRemoved)
    }

    func addHotkeyBinding() {
        let defaultAction = configuration.layouts.first.map { HotkeyAction.applyLayout(layoutID: $0.id) } ?? .cycleNext
        let binding = ShortcutBinding(isEnabled: true, shortcut: nil, action: defaultAction)
        configuration.hotkeys.bindings.insert(binding, at: 0)
        selectedHotkeyBindingID = binding.id
        persistConfiguration(status: UICopy.hotkeyAdded)
    }

    func deleteSelectedHotkeyBinding() {
        guard let selectedHotkeyBindingID else {
            return
        }
        deleteBinding(selectedHotkeyBindingID)
    }

    func addDirectActionBinding() {
        let action = directActionOptions.first?.1 ?? .applyLayout(layoutID: configuration.layouts.first?.id ?? "layout-1")
        configuration.hotkeys.bindings.append(
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.alt], key: "a"), action: action)
        )
        persistConfiguration(status: UICopy.directActionHotkeyAdded)
    }

    func addPreviousCycleBinding() {
        configuration.hotkeys.bindings.append(
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.alt], key: "h"), action: .cyclePrevious)
        )
        persistConfiguration(status: UICopy.previousLayoutHotkeyAdded)
    }

    func addNextCycleBinding() {
        configuration.hotkeys.bindings.append(
            ShortcutBinding(shortcut: KeyboardShortcut(modifiers: [.alt], key: "l"), action: .cycleNext)
        )
        persistConfiguration(status: UICopy.nextLayoutHotkeyAdded)
    }

    func layoutDisplayLabel(for layout: LayoutPreset) -> String {
        if let index = configuration.layouts.firstIndex(where: { $0.id == layout.id }) {
            return layoutDisplayLabel(for: layout, index: index)
        }
        return layout.id
    }

    func layoutDisplayLabel(for layoutID: String) -> String {
        guard let index = configuration.layouts.firstIndex(where: { $0.id == layoutID }) else {
            return layoutID
        }
        return layoutDisplayLabel(for: configuration.layouts[index], index: index)
    }

    private func clamp(_ selection: GridSelection, columns: Int, rows: Int) -> GridSelection {
        let x = min(max(selection.x, 0), max(columns - 1, 0))
        let y = min(max(selection.y, 0), max(rows - 1, 0))
        let w = min(max(selection.w, 1), max(columns - x, 1))
        let h = min(max(selection.h, 1), max(rows - y, 1))
        return GridSelection(x: x, y: y, w: w, h: h)
    }

    private func clamp(_ region: TriggerRegion, columns: Int, rows: Int) -> TriggerRegion {
        switch region {
        case let .screen(selection):
            return .screen(clamp(selection, columns: columns, rows: rows))
        case let .menuBar(selection):
            let x = min(max(selection.x, 0), max(rows - 1, 0))
            let w = min(max(selection.w, 1), max(rows - x, 1))
            return .menuBar(MenuBarSelection(x: x, w: w))
        }
    }

    private func persistConfiguration(status: String) {
        do {
            try configurationStore.save(configuration)
            onConfigurationSaved(configuration)
            statusMessage = status
            synchronizeSelectionState()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func synchronizeSelectionState() {
        if let selectedModifierGroupID,
           !modifierGroupItems.contains(where: { $0.id == selectedModifierGroupID }) {
            self.selectedModifierGroupID = nil
        }

        if let selectedExcludedWindowID,
           !excludedWindowItems.contains(where: { $0.id == selectedExcludedWindowID }) {
            self.selectedExcludedWindowID = nil
        }

        if let selectedHotkeyBindingID,
           !configuration.hotkeys.bindings.contains(where: { $0.id == selectedHotkeyBindingID }) {
            self.selectedHotkeyBindingID = nil
        }

        if let selectedLayoutID,
           !configuration.layouts.contains(where: { $0.id == selectedLayoutID }) {
            self.selectedLayoutID = configuration.layouts.first?.id
            layoutDraft = configuration.layouts.first
            layoutPageMode = .list
            layoutDeleteArmed = false
        }
    }

    private func makeLayoutDisplayID(for index: Int) -> String {
        "layout_\(index + 1)"
    }

    private func layoutDisplayLabel(for layout: LayoutPreset, index: Int) -> String {
        let displayID = makeLayoutDisplayID(for: index)
        let trimmedName = layout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return displayID
        }
        return "\(displayID): \(trimmedName)"
    }
}
