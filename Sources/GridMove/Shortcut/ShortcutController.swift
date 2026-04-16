@preconcurrency import AppKit
import Foundation

@MainActor
final class ShortcutController {
    private let layoutEngine: LayoutEngine
    private let windowController: WindowController
    private let configurationProvider: () -> AppConfiguration
    private let accessibilityTrustedProvider: () -> Bool
    private let onAccessibilityRevoked: () -> Void

    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var pendingAccessibilityRevocation = false

    var isEnabled = true

    init(
        layoutEngine: LayoutEngine,
        windowController: WindowController,
        configurationProvider: @escaping () -> AppConfiguration,
        accessibilityTrustedProvider: @escaping () -> Bool,
        onAccessibilityRevoked: @escaping () -> Void
    ) {
        self.layoutEngine = layoutEngine
        self.windowController = windowController
        self.configurationProvider = configurationProvider
        self.accessibilityTrustedProvider = accessibilityTrustedProvider
        self.onAccessibilityRevoked = onAccessibilityRevoked
    }

    func start() {
        guard eventTap == nil else {
            return
        }

        let eventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let controller = Unmanaged<ShortcutController>.fromOpaque(userInfo).takeUnretainedValue()
            return MainActor.assumeIsolated {
                controller.handle(type: type, event: event)
            }
        }

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        guard let tap else {
            AppLogger.shared.error("Failed to create shortcut event tap.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventSource = source
    }

    func stop() {
        if let eventSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        eventSource = nil
        eventTap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard ensureAccessibilityIsStillGranted() else {
            return Unmanaged.passUnretained(event)
        }

        guard isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let configuration = configurationProvider()
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = normalizedModifiers(from: event.flags)

        guard let binding = configuration.hotkeys.bindings.first(where: {
            guard $0.isEnabled, let shortcut = $0.shortcut else {
                return false
            }
            return ShortcutKeyMap.keyCode(for: shortcut.key) == keyCode
                && Set(shortcut.modifiers) == modifiers
        }) else {
            return Unmanaged.passUnretained(event)
        }

        guard let window = windowController.windowForLayoutAction(configuration: configuration) else {
            return nil
        }

        switch binding.action {
        case let .applyLayout(layoutID):
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: nil,
                configuration: configuration
            )
        case .cycleNext:
            guard let layoutID = layoutEngine.nextLayoutID(for: window.identity, layouts: configuration.layouts) else {
                return nil
            }
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: nil,
                configuration: configuration
            )
        case .cyclePrevious:
            guard let layoutID = layoutEngine.previousLayoutID(for: window.identity, layouts: configuration.layouts) else {
                return nil
            }
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: nil,
                configuration: configuration
            )
        }

        return nil
    }

    private func normalizedModifiers(from flags: CGEventFlags) -> Set<ModifierKey> {
        var result: Set<ModifierKey> = []
        if flags.contains(.maskControl) { result.insert(.ctrl) }
        if flags.contains(.maskCommand) { result.insert(.cmd) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskAlternate) { result.insert(.alt) }
        return result
    }

    private func ensureAccessibilityIsStillGranted() -> Bool {
        guard accessibilityTrustedProvider() else {
            stop()
            scheduleAccessibilityRevocationHandling()
            return false
        }
        return true
    }

    private func scheduleAccessibilityRevocationHandling() {
        guard !pendingAccessibilityRevocation else {
            return
        }

        pendingAccessibilityRevocation = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.pendingAccessibilityRevocation = false
            self.onAccessibilityRevoked()
        }
    }
}
