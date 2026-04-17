import Foundation

@MainActor
final class AccessibilityAccessMonitor {
    private enum PollingInterval {
        static let revoked: TimeInterval = 1.0
    }

    private let statusProvider: () -> Bool

    private(set) var cachedAccess: Bool?

    init(statusProvider: @escaping () -> Bool) {
        self.statusProvider = statusProvider
    }

    var hasAccess: Bool {
        cachedAccess ?? false
    }

    var pollingInterval: TimeInterval? {
        hasAccess ? nil : PollingInterval.revoked
    }

    @discardableResult
    func refresh() -> Bool {
        refresh(currentAccess: statusProvider())
    }

    @discardableResult
    func refresh(currentAccess: Bool) -> Bool {
        let didChange = cachedAccess != currentAccess
        cachedAccess = currentAccess
        return didChange
    }

    func invalidate() {
        cachedAccess = nil
    }
}
