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

    static func resolvedSet(for screen: NSScreen, configuration: AppConfiguration) -> LayoutSet? {
        guard let group = activeGroup(in: configuration) else {
            return nil
        }

        let displayID = MonitorDiscovery.displayID(for: screen)

        if let explicitSet = group.sets.first(where: {
            if case let .displays(displayIDs) = $0.monitor {
                return displayIDs.contains(displayID)
            }
            return false
        }) {
            return explicitSet
        }

        if MonitorDiscovery.isMainScreen(screen),
           let mainSet = group.sets.first(where: { $0.monitor == .main }) {
            return mainSet
        }

        return group.sets.first(where: { $0.monitor == .all })
    }

    static func resolvedLayouts(for screen: NSScreen, configuration: AppConfiguration) -> [LayoutPreset] {
        resolvedSet(for: screen, configuration: configuration)?.layouts ?? []
    }

    static func triggerableLayouts(for screen: NSScreen, configuration: AppConfiguration) -> [LayoutPreset] {
        resolvedLayouts(for: screen, configuration: configuration).filter { $0.triggerRegion != nil }
    }

    static func resolveNamedLayout(identifier: String, configuration: AppConfiguration) throws -> ResolvedLayoutEntry {
        let entries = flattenedActiveEntries(in: configuration)
        if let matchedByID = entries.first(where: { $0.layout.id.caseInsensitiveCompare(identifier) == .orderedSame }) {
            return matchedByID
        }

        let matchedLayouts = entries.filter { $0.layout.name.caseInsensitiveCompare(identifier) == .orderedSame }
        if let entry = matchedLayouts.onlyElement {
            return entry
        }
        if !matchedLayouts.isEmpty {
            throw CommandLineLayoutResolutionError.ambiguousLayoutName(identifier, matches: matchedLayouts.map(\.layout))
        }
        throw CommandLineLayoutResolutionError.unknownLayout(identifier)
    }

    static func entry(for layoutID: String, configuration: AppConfiguration) -> ResolvedLayoutEntry? {
        flattenedActiveEntries(in: configuration).first(where: { $0.layout.id == layoutID })
    }

    static func entry(at index: Int, on screen: NSScreen, configuration: AppConfiguration) -> ResolvedLayoutEntry? {
        guard index >= 1, let group = activeGroup(in: configuration), let set = resolvedSet(for: screen, configuration: configuration) else {
            return nil
        }

        let currentSetEntries = group.sets.flatMap { candidateSet in
            candidateSet.layouts.map { layout in
                ResolvedLayoutEntry(layout: layout, set: candidateSet, groupName: group.name, menuIndex: 0)
            }
        }.filter { $0.set == set }

        guard index <= currentSetEntries.count else {
            return nil
        }
        return currentSetEntries[index - 1]
    }

    static func targetScreen(for entry: ResolvedLayoutEntry, currentScreen: NSScreen?) -> NSScreen? {
        MonitorDiscovery.targetScreen(for: entry.set.monitor, currentScreen: currentScreen)
    }
}

private extension Collection {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
