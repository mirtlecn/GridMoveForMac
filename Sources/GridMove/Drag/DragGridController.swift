@preconcurrency import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class DragGridController {
    let layoutEngine: LayoutEngine
    let windowController: WindowController
    let overlayController: OverlayController
    let configurationProvider: () -> AppConfiguration
    let cycleActiveLayoutGroup: () -> AppConfiguration?
    let accessibilityTrustedProvider: () -> Bool
    let accessibilityAccessValidator: () -> Bool
    let onAccessibilityRevoked: () -> Void

    var state = DragInteractionState()
    var eventTap: CFMachPort?
    var eventSource: CFRunLoopSource?
    var pendingAccessibilityRevocation = false

    var isEnabled = true

    init(
        layoutEngine: LayoutEngine,
        windowController: WindowController,
        overlayController: OverlayController,
        configurationProvider: @escaping () -> AppConfiguration,
        cycleActiveLayoutGroup: @escaping () -> AppConfiguration?,
        accessibilityTrustedProvider: @escaping () -> Bool,
        accessibilityAccessValidator: @escaping () -> Bool,
        onAccessibilityRevoked: @escaping () -> Void
    ) {
        self.layoutEngine = layoutEngine
        self.windowController = windowController
        self.overlayController = overlayController
        self.configurationProvider = configurationProvider
        self.cycleActiveLayoutGroup = cycleActiveLayoutGroup
        self.accessibilityTrustedProvider = accessibilityTrustedProvider
        self.accessibilityAccessValidator = accessibilityAccessValidator
        self.onAccessibilityRevoked = onAccessibilityRevoked
    }

    func start() {
        guard eventTap == nil else {
            return
        }

        let eventMask =
            (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.rightMouseUp.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let controller = Unmanaged<DragGridController>.fromOpaque(userInfo).takeUnretainedValue()
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
            AppLogger.shared.error("Failed to create drag event tap.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventSource = source
    }

    func stop() {
        cancelAndSuppressActiveMouseUp()
        if let eventSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        eventSource = nil
        eventTap = nil
    }

    static func preferredInteractionMode(preferLayoutMode: Bool) -> DragInteractionMode {
        preferLayoutMode ? .layoutSelection : .moveOnly
    }

    // This controller owns a small runtime state machine:
    // 1. primary trigger activation
    // 2. layout-selection vs move-only sub-mode
    // 3. overlay + target-window lifecycle while the trigger stays active
    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if SyntheticEventMarker.isMiddleMouseReplay(event) {
            return Unmanaged.passUnretained(event)
        }

        guard ensureAccessibilityIsStillGranted() else {
            return Unmanaged.passUnretained(event)
        }

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let configuration = configurationProvider()

        switch type {
        case .leftMouseDown:
            return handleLeftMouseDown(event: event, configuration: configuration)
        case .leftMouseDragged:
            return handleMouseDragged(event: event, expectedButton: .left, configuration: configuration)
        case .leftMouseUp:
            return handleMouseUp(event: event, button: .left)
        case .rightMouseDown:
            return handleRightMouseDown(event: event)
        case .rightMouseDragged:
            return handleRightMouseDragged(event: event)
        case .rightMouseUp:
            return handleRightMouseUp(event: event, configuration: configuration)
        case .otherMouseDown:
            return handleOtherMouseDown(event: event, configuration: configuration)
        case .otherMouseDragged:
            return handleMouseDragged(event: event, expectedButton: .middle, configuration: configuration)
        case .otherMouseUp:
            return handleOtherMouseUp(event: event)
        case .flagsChanged:
            return handleFlagsChanged(event: event, configuration: configuration)
        case .keyDown:
            return handleKeyDown(event: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
