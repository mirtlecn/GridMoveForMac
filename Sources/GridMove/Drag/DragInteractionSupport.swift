@preconcurrency import AppKit
import Foundation

enum DragInteractionMode: Equatable {
    case layoutSelection
    case moveOnly
}

enum DragTriggerButton: Int {
    case left = 0
    case middle = 2
}

enum OptionToggleEventResult: Equatable {
    case ignore
    case consume
    case toggle
}

struct OptionToggleTracker: Equatable {
    let baselinePressed: Bool
    private(set) var lastPressed: Bool
    private(set) var isPending = false

    init(baselinePressed: Bool) {
        self.baselinePressed = baselinePressed
        lastPressed = baselinePressed
    }

    mutating func register(isPressed: Bool) -> OptionToggleEventResult {
        guard isPressed != lastPressed else {
            return .ignore
        }

        defer {
            lastPressed = isPressed
        }

        if lastPressed == baselinePressed, isPressed != baselinePressed {
            isPending = true
            return .consume
        }

        if lastPressed != baselinePressed, isPressed == baselinePressed, isPending {
            isPending = false
            return .toggle
        }

        if isPending {
            return .consume
        }

        return .ignore
    }
}

struct MoveAnchor: Equatable {
    let mousePoint: CGPoint
    let windowOrigin: CGPoint

    func movedOrigin(for mousePoint: CGPoint) -> CGPoint {
        CGPoint(
            x: windowOrigin.x + (mousePoint.x - self.mousePoint.x),
            y: windowOrigin.y + (mousePoint.y - self.mousePoint.y)
        )
    }
}

struct DragInteractionState {
    var active = false
    var activeButton: DragTriggerButton?
    var activationTimer: DispatchSourceTimer?
    var interactionMode: DragInteractionMode = .layoutSelection
    var activeScreen: NSScreen?
    var hasDraggedPastThreshold = false
    var hoveredLayoutID: String?
    var lastAppliedLayoutID: String?
    var mouseDownPoint: CGPoint?
    var overlayActivationPoint: CGPoint?
    var resolvedSlots: [ResolvedTriggerSlot] = []
    var suppressedMouseUpButton: DragTriggerButton?
    var targetWindow: ManagedWindow?
    var currentWindowFrame: CGRect?
    var moveAnchor: MoveAnchor?
    var optionToggleTracker: OptionToggleTracker?
    var pendingRightClickToggle = false
}
