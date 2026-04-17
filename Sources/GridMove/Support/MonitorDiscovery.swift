import AppKit
import Foundation

enum MonitorDiscovery {
    static func displayID(for screen: NSScreen) -> String {
        Geometry.screenIdentifier(for: screen)
    }

    static func isMainScreen(_ screen: NSScreen) -> Bool {
        guard let displayID = Geometry.cgDisplayID(for: screen) else {
            return false
        }
        return displayID == CGMainDisplayID()
    }

    static func currentMonitorMap() -> [String: String] {
        var result: [String: String] = [:]
        let screens = NSScreen.screens
        let nameCounts = Dictionary(grouping: screens.map(displayName(for:)), by: { $0 }).mapValues(\.count)

        for screen in screens {
            let displayID = displayID(for: screen)
            let displayName = displayName(for: screen)
            let key = (nameCounts[displayName] ?? 0) > 1 ? "\(displayName) (\(displayID))" : displayName
            result[key] = displayID
        }

        return result
    }

    static func targetScreen(for monitor: LayoutSetMonitor, currentScreen: NSScreen?) -> NSScreen? {
        switch monitor {
        case .all:
            return currentScreen ?? NSScreen.main ?? NSScreen.screens.first
        case .main:
            return NSScreen.screens.first(where: isMainScreen(_:)) ?? NSScreen.main ?? NSScreen.screens.first
        case let .displays(displayIDs):
            if let currentScreen, displayIDs.contains(displayID(for: currentScreen)) {
                return currentScreen
            }

            for displayID in displayIDs {
                if let screen = NSScreen.screens.first(where: { self.displayID(for: $0) == displayID }) {
                    return screen
                }
            }

            return nil
        }
    }

    static func displayName(for screen: NSScreen) -> String {
        if #available(macOS 12.0, *) {
            return screen.localizedName
        }

        return "Display \(displayID(for: screen))"
    }
}
