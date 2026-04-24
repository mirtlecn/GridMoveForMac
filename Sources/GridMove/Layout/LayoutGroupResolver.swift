import AppKit
import Foundation

struct ResolvedLayoutEntry: Equatable {
    let layout: LayoutPreset
    let set: LayoutSet
    let groupName: String
    let menuIndex: Int
}

enum LayoutGroupResolver {
    static func activeGroup(in configuration: AppConfiguration) -> LayoutGroup? {
        configuration.activeGroup
    }

    static func flattenedEntries(in group: LayoutGroup) -> [ResolvedLayoutEntry] {
        var nextIndex = 1
        return group.sets.flatMap { set in
            set.layouts.map { layout in
                defer { nextIndex += 1 }
                return ResolvedLayoutEntry(layout: layout, set: set, groupName: group.name, menuIndex: nextIndex)
            }
        }
    }

    static func flattenedActiveEntries(in configuration: AppConfiguration) -> [ResolvedLayoutEntry] {
        guard let group = activeGroup(in: configuration) else {
            return []
        }
        return flattenedEntries(in: group)
    }

    static func indexedActiveEntries(in configuration: AppConfiguration) -> [ResolvedLayoutEntry] {
        flattenedActiveEntries(in: configuration).filter { $0.layout.includeInLayoutIndex }
    }

    static func resolvedSet(for screen: NSScreen, configuration: AppConfiguration) -> LayoutSet? {
        guard let group = activeGroup(in: configuration) else {
            return nil
        }

        let displayID = MonitorDiscovery.displayID(for: screen)
        let mainDisplayID = NSScreen.screens
            .first(where: MonitorDiscovery.isMainScreen(_:))
            .map(MonitorDiscovery.displayID(for:))

        return resolvedSet(
            in: group,
            forDisplayID: displayID,
            mainDisplayID: mainDisplayID
        )
    }

    static func resolvedLayouts(for screen: NSScreen, configuration: AppConfiguration) -> [LayoutPreset] {
        resolvedSet(for: screen, configuration: configuration)?.layouts ?? []
    }

    static func triggerableLayouts(for screen: NSScreen, configuration: AppConfiguration) -> [LayoutPreset] {
        resolvedLayouts(for: screen, configuration: configuration).filter { !$0.triggerRegions.isEmpty }
    }

    static func resolveNamedLayout(identifier: String, configuration: AppConfiguration) throws -> ResolvedLayoutEntry {
        let entries = flattenedActiveEntries(in: configuration)
        let matchedLayouts = entries.filter { $0.layout.name.caseInsensitiveCompare(identifier) == .orderedSame }
        if let entry = matchedLayouts.onlyElement {
            return entry
        }
        if !matchedLayouts.isEmpty {
            let layoutIndexByID = Dictionary(
                uniqueKeysWithValues: indexedActiveEntries(in: configuration).enumerated().map { offset, entry in
                    (entry.layout.id, offset + 1)
                }
            )
            let matches = matchedLayouts.map { entry in
                LayoutNameMatch(
                    name: entry.layout.name,
                    layoutIndex: layoutIndexByID[entry.layout.id]
                )
            }
            throw CommandLineLayoutResolutionError.ambiguousLayoutName(identifier, matches: matches)
        }
        throw CommandLineLayoutResolutionError.unknownLayout(identifier)
    }

    static func entry(for layoutID: String, configuration: AppConfiguration) -> ResolvedLayoutEntry? {
        flattenedActiveEntries(in: configuration).first(where: { $0.layout.id == layoutID })
    }

    static func entry(at index: Int, configuration: AppConfiguration) -> ResolvedLayoutEntry? {
        guard index >= 1 else {
            return nil
        }
        let indexedEntries = indexedActiveEntries(in: configuration)
        guard index <= indexedEntries.count else {
            return nil
        }
        return indexedEntries[index - 1]
    }

    static func targetScreen(
        for entry: ResolvedLayoutEntry,
        currentScreen: NSScreen?,
        configuration: AppConfiguration
    ) -> NSScreen? {
        guard let targetDisplayID = targetDisplayID(
            for: entry,
            currentDisplayID: currentScreen.map(MonitorDiscovery.displayID(for:)),
            mainDisplayID: NSScreen.screens.first(where: MonitorDiscovery.isMainScreen(_:)).map(MonitorDiscovery.displayID(for:)),
            availableDisplayIDs: NSScreen.screens.map(MonitorDiscovery.displayID(for:)),
            configuration: configuration
        ) else {
            return nil
        }

        return NSScreen.screens.first(where: { MonitorDiscovery.displayID(for: $0) == targetDisplayID })
    }

    static func targetDisplayID(
        for entry: ResolvedLayoutEntry,
        currentDisplayID: String?,
        mainDisplayID: String?,
        availableDisplayIDs: [String],
        configuration: AppConfiguration
    ) -> String? {
        if let group = activeGroup(in: configuration),
           group.name == entry.groupName {
            let candidateDisplayIDs = availableDisplayIDs.filter { displayID in
                resolvedSet(
                    in: group,
                    forDisplayID: displayID,
                    mainDisplayID: mainDisplayID
                ) == entry.set
            }

            if let currentDisplayID, candidateDisplayIDs.contains(currentDisplayID) {
                return currentDisplayID
            }

            if let candidateDisplayID = candidateDisplayIDs.first {
                return candidateDisplayID
            }
        }

        return targetDisplayID(
            for: entry.set.monitor,
            currentDisplayID: currentDisplayID,
            mainDisplayID: mainDisplayID,
            availableDisplayIDs: availableDisplayIDs
        )
    }

    static func targetDisplayID(
        for monitor: LayoutSetMonitor,
        currentDisplayID: String?,
        mainDisplayID: String?,
        availableDisplayIDs: [String]
    ) -> String? {
        switch monitor {
        case .all:
            if let currentDisplayID, availableDisplayIDs.contains(currentDisplayID) {
                return currentDisplayID
            }
            if let mainDisplayID, availableDisplayIDs.contains(mainDisplayID) {
                return mainDisplayID
            }
            return availableDisplayIDs.first
        case .main:
            if let mainDisplayID, availableDisplayIDs.contains(mainDisplayID) {
                return mainDisplayID
            }
            return availableDisplayIDs.first
        case let .displays(displayIDs):
            if let currentDisplayID,
               displayIDs.contains(currentDisplayID),
               availableDisplayIDs.contains(currentDisplayID) {
                return currentDisplayID
            }
            return displayIDs.first(where: { availableDisplayIDs.contains($0) })
        }
    }

    private static func resolvedSet(
        in group: LayoutGroup,
        forDisplayID displayID: String,
        mainDisplayID: String?
    ) -> LayoutSet? {
        if let explicitSet = group.sets.first(where: { set in
            if case let .displays(displayIDs) = set.monitor {
                return displayIDs.contains(displayID)
            }
            return false
        }) {
            return explicitSet
        }

        if displayID == mainDisplayID,
           let mainSet = group.sets.first(where: { $0.monitor == .main }) {
            return mainSet
        }

        return group.sets.first(where: { $0.monitor == .all })
    }
}

private extension Collection {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
