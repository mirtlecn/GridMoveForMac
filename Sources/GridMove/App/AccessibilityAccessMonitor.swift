import Foundation

@MainActor
final class AccessibilityAccessMonitor {
    private enum PollingInterval {
        static let granted: TimeInterval = 0.25
        static let revoked: TimeInterval = 2.0
    }

    private let statusProvider: () -> Bool

    private(set) var cachedAccess: Bool?

    init(statusProvider: @escaping () -> Bool) {
        self.statusProvider = statusProvider
    }

    var hasAccess: Bool {
        cachedAccess ?? false
    }

    var pollingInterval: TimeInterval {
        hasAccess ? PollingInterval.granted : PollingInterval.revoked
    }

    @discardableResult
    func refresh() -> Bool {
        let currentAccess = statusProvider()
        let didChange = cachedAccess != currentAccess
        cachedAccess = currentAccess
        return didChange
    }

    func invalidate() {
        cachedAccess = nil
    }
}
