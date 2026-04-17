import AppKit
import Foundation

@MainActor
final class PreferenceViewModel {
    enum EntryKind: String {
        case bundleID
        case windowTitle

        var title: String {
            switch self {
            case .bundleID:
                return UICopy.bundleIDTitle
            case .windowTitle:
                return UICopy.windowTitle
            }
        }
    }

    struct ModifierGroupItem: Equatable {
        let index: Int
        let keys: [ModifierKey]

        var title: String {
            keys.map(\.displayName).joined(separator: " + ")
        }

        var symbolTitle: String {
            keys.map(\.symbol).joined()
        }
    }

    struct ExcludedWindowItem: Equatable {
        let index: Int
        let value: String
        let kind: EntryKind
    }

    struct HotkeyRow: Equatable, Identifiable {
        let id: String
        let action: HotkeyAction
        let shortcut: KeyboardShortcut?
        let bindingID: String?
        let isAdditional: Bool
    }

    private let configurationStore: ConfigurationStore
    private let onConfigurationSaved: (AppConfiguration) -> Void

    private(set) var configuration: AppConfiguration

    init(
        configurationStore: ConfigurationStore,
        configurationProvider: @escaping () -> AppConfiguration,
        onConfigurationSaved: @escaping (AppConfiguration) -> Void
    ) {
        self.configurationStore = configurationStore
        self.onConfigurationSaved = onConfigurationSaved
        configuration = configurationProvider()
    }

    var modifierGroupItems: [ModifierGroupItem] {
        configuration.dragTriggers.modifierGroups.enumerated().map { index, keys in
            ModifierGroupItem(index: index, keys: keys)
        }
    }

    var excludedWindowItems: [ExcludedWindowItem] {
        let bundleItems = configuration.general.excludedBundleIDs.enumerated().map { index, value in
            ExcludedWindowItem(index: index, value: value, kind: .bundleID)
        }
        let titleItems = configuration.general.excludedWindowTitles.enumerated().map { index, value in
            ExcludedWindowItem(index: index, value: value, kind: .windowTitle)
        }
        return bundleItems + titleItems
    }

    var allHotkeyActions: [HotkeyAction] {
        configuration.layouts.map { HotkeyAction.applyLayout(layoutID: $0.id) } + [.cyclePrevious, .cycleNext]
    }

    var hotkeyActionOptions: [(String, HotkeyAction)] {
        allHotkeyActions.map { (hotkeyActionTitle(for: $0), $0) }
    }

    var hotkeyRows: [HotkeyRow] {
        var rows: [HotkeyRow] = []

        for action in allHotkeyActions {
            let matchingBindings = configuration.hotkeys.bindings.filter { $0.action == action }
            if let primaryBinding = matchingBindings.first {
                rows.append(
                    HotkeyRow(
                        id: "base-\(actionKey(for: action))",
                        action: action,
                        shortcut: primaryBinding.isEnabled ? primaryBinding.shortcut : nil,
                        bindingID: primaryBinding.id,
                        isAdditional: false
                    )
                )
                for binding in matchingBindings.dropFirst() {
                    rows.append(
                        HotkeyRow(
                            id: binding.id,
                            action: action,
                            shortcut: binding.isEnabled ? binding.shortcut : nil,
                            bindingID: binding.id,
                            isAdditional: true
                        )
                    )
                }
            } else {
                rows.append(
                    HotkeyRow(
                        id: "base-\(actionKey(for: action))",
                        action: action,
                        shortcut: nil,
                        bindingID: nil,
                        isAdditional: false
                    )
                )
            }
        }

        return rows
    }

    func replaceConfiguration(_ configuration: AppConfiguration) {
        self.configuration = configuration
    }

    func updateGeneralEnabled(_ isEnabled: Bool) {
        configuration.general.isEnabled = isEnabled
        persistConfiguration()
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
        persistConfiguration()
    }

    func addModifierGroup(_ group: [ModifierKey]) {
        let normalizedGroup = ModifierKey.allCases.filter { group.contains($0) }
        guard !normalizedGroup.isEmpty else {
            return
        }
        configuration.dragTriggers.modifierGroups.append(normalizedGroup)
        persistConfiguration()
    }

    func removeModifierGroup(at index: Int) {
        guard configuration.dragTriggers.modifierGroups.indices.contains(index) else {
            return
        }
        configuration.dragTriggers.modifierGroups.remove(at: index)
        persistConfiguration()
    }

    func addExcludedWindow(kind: EntryKind, value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return
        }

        switch kind {
        case .bundleID:
            configuration.general.excludedBundleIDs.append(trimmedValue)
        case .windowTitle:
            configuration.general.excludedWindowTitles.append(trimmedValue)
        }

        persistConfiguration()
    }

    func removeExcludedWindow(_ item: ExcludedWindowItem) {
        switch item.kind {
        case .bundleID:
            guard configuration.general.excludedBundleIDs.indices.contains(item.index) else {
                return
            }
            configuration.general.excludedBundleIDs.remove(at: item.index)
        case .windowTitle:
            guard configuration.general.excludedWindowTitles.indices.contains(item.index) else {
                return
            }
            configuration.general.excludedWindowTitles.remove(at: item.index)
        }
        persistConfiguration()
    }

    func addHotkeyRow(defaultAction: HotkeyAction? = nil) {
        let action = defaultAction ?? allHotkeyActions.first ?? .cycleNext
        configuration.hotkeys.bindings.append(
            ShortcutBinding(isEnabled: false, shortcut: nil, action: action)
        )
        persistConfiguration()
    }

    func deleteHotkeyRow(id: String) {
        guard let bindingID = hotkeyRows.first(where: { $0.id == id })?.bindingID else {
            return
        }
        configuration.hotkeys.bindings.removeAll { $0.id == bindingID }
        persistConfiguration()
    }

    func updateHotkeyShortcut(id: String, shortcut: KeyboardShortcut?) {
        guard let row = hotkeyRows.first(where: { $0.id == id }) else {
            return
        }

        if let bindingID = row.bindingID,
           let bindingIndex = configuration.hotkeys.bindings.firstIndex(where: { $0.id == bindingID }) {
            configuration.hotkeys.bindings[bindingIndex].shortcut = shortcut
            configuration.hotkeys.bindings[bindingIndex].isEnabled = shortcut != nil
        } else if let shortcut {
            configuration.hotkeys.bindings.append(
                ShortcutBinding(
                    isEnabled: true,
                    shortcut: shortcut,
                    action: row.action
                )
            )
        } else {
            return
        }

        persistConfiguration()
    }

    func updateHotkeyAction(id: String, action: HotkeyAction) {
        guard let bindingID = hotkeyRows.first(where: { $0.id == id })?.bindingID,
              let bindingIndex = configuration.hotkeys.bindings.firstIndex(where: { $0.id == bindingID }) else {
            return
        }

        configuration.hotkeys.bindings[bindingIndex].action = action
        persistConfiguration()
    }

    func hotkeyActionTitle(for action: HotkeyAction) -> String {
        switch action {
        case let .applyLayout(layoutID):
            return UICopy.applyLayout(layoutDisplayLabel(for: layoutID))
        case .cyclePrevious:
            return UICopy.applyPreviousLayout
        case .cycleNext:
            return UICopy.applyNextLayout
        }
    }

    private func layoutDisplayLabel(for layoutID: String) -> String {
        guard let index = configuration.layouts.firstIndex(where: { $0.id == layoutID }) else {
            return layoutID
        }

        let layout = configuration.layouts[index]
        let trimmedName = layout.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return "layout_\(index + 1)"
    }

    private func actionKey(for action: HotkeyAction) -> String {
        switch action {
        case let .applyLayout(layoutID):
            return "layout-\(layoutID)"
        case .cyclePrevious:
            return "cycle-previous"
        case .cycleNext:
            return "cycle-next"
        }
    }

    private func persistConfiguration() {
        do {
            try configurationStore.save(configuration)
            onConfigurationSaved(configuration)
        } catch {
            NSSound.beep()
        }
    }
}

private extension ModifierKey {
    var symbol: String {
        switch self {
        case .ctrl:
            return "⌃"
        case .cmd:
            return "⌘"
        case .shift:
            return "⇧"
        case .alt:
            return "⌥"
        }
    }
}
