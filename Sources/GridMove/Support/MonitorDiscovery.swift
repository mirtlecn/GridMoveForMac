import AppKit
import Foundation

enum MonitorDiscovery {
    static func displayID(for screen: NSScreen) -> String {
        Geometry.screenIdentifier(for: screen)
    }

    static func fingerprint(for screen: NSScreen) -> String? {
        guard let displayID = Geometry.cgDisplayID(for: screen) else {
            return nil
        }
        return Geometry.displayFingerprint(for: displayID)
    }

    static func isMainScreen(_ screen: NSScreen) -> Bool {
        guard let displayID = Geometry.cgDisplayID(for: screen) else {
            return false
        }
        return displayID == CGMainDisplayID()
    }

    static func currentMonitorMap() -> [String: String] {
        var result: [String: String] = [:]
        for screen in NSScreen.screens {
            guard let fingerprint = fingerprint(for: screen) else {
                continue
            }
            result[fingerprint] = displayID(for: screen)
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
}
