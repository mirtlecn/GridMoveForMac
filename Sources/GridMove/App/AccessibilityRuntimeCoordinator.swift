import Foundation

@MainActor
final class AccessibilityRuntimeCoordinator {
    private let statusProvider: () -> Bool
    private let promptRequester: () -> Bool
    private let onStateDidUpdate: () -> Void
    private let monitor: AccessibilityAccessMonitor

    private var pollingTimer: Timer?
    private var currentPollingInterval: TimeInterval?

    init(
        statusProvider: @escaping () -> Bool,
        promptRequester: @escaping () -> Bool,
        onStateDidUpdate: @escaping () -> Void
    ) {
        self.statusProvider = statusProvider
        self.promptRequester = promptRequester
        self.onStateDidUpdate = onStateDidUpdate
        self.monitor = AccessibilityAccessMonitor(statusProvider: statusProvider)
    }

    var hasAccess: Bool {
        monitor.hasAccess
    }

    var isPollingActive: Bool {
        pollingTimer != nil
    }

    var pollingInterval: TimeInterval? {
        currentPollingInterval
    }

    @discardableResult
    func evaluate(promptOnMissing: Bool) -> Bool {
        let currentAccess = statusProvider()
        let didChange = monitor.refresh(currentAccess: currentAccess)
        synchronizePolling()
        onStateDidUpdate()

        if promptOnMissing && didChange && !currentAccess {
            _ = promptRequester()
        }

        return currentAccess
    }

    func invalidateAndEvaluate(promptOnMissing: Bool) {
        monitor.invalidate()
        _ = evaluate(promptOnMissing: promptOnMissing)
    }

    func startPollingIfNeeded() {
        synchronizePolling()
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        currentPollingInterval = nil
    }

    private func synchronizePolling() {
        guard let nextPollingInterval = monitor.pollingInterval else {
            stop()
            return
        }

        guard pollingTimer == nil || currentPollingInterval != nextPollingInterval else {
            return
        }

        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: nextPollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                _ = self?.evaluate(promptOnMissing: true)
            }
        }
        currentPollingInterval = nextPollingInterval
    }
}
