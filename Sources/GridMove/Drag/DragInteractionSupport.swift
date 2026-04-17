@preconcurrency import AppKit
import Foundation

enum DragInteractionMode: Equatable {
    case layoutSelection
    case moveOnly
}

enum LayoutGroupCycleDirection: Equatable {
    case next
    case previous
}

enum DragTriggerButton: Int {
    case left = 0
    case mouseButton = 2
}

enum OptionToggleEventResult: Equatable {
    case ignore
    case consume
    case toggle
}

struct OptionToggleTracker: Equatable {
    private var tracker: SingleModifierToggleTracker

    init(baselineModifiers: Set<ModifierKey>) {
        tracker = SingleModifierToggleTracker(baselineModifiers: baselineModifiers, toggleModifier: .alt)
    }

    var isPending: Bool {
        tracker.isPending
    }

    mutating func register(modifiers: Set<ModifierKey>) -> OptionToggleEventResult {
        tracker.register(modifiers: modifiers)
    }
}

struct ShiftGroupCycleTracker: Equatable {
    private var tracker: SingleModifierToggleTracker

    init(baselineModifiers: Set<ModifierKey>) {
        tracker = SingleModifierToggleTracker(baselineModifiers: baselineModifiers, toggleModifier: .shift)
    }

    mutating func register(modifiers: Set<ModifierKey>) -> OptionToggleEventResult {
        tracker.register(modifiers: modifiers)
    }
}

struct ScrollGroupCycleTracker: Equatable {
    let threshold: Double
    private(set) var accumulatedDistance: Double = 0
    private(set) var hasTriggeredCurrentGesture = false

    mutating func register(distance: Double) -> LayoutGroupCycleDirection? {
        guard distance != 0 else {
            return nil
        }

        guard !hasTriggeredCurrentGesture else {
            return nil
        }

        accumulatedDistance += distance
        guard abs(accumulatedDistance) >= threshold else {
            return nil
        }

        hasTriggeredCurrentGesture = true
        return accumulatedDistance > 0 ? .previous : .next
    }

    mutating func resetGesture() {
        accumulatedDistance = 0
        hasTriggeredCurrentGesture = false
    }
}

private struct SingleModifierToggleTracker: Equatable {
    private(set) var lastModifiers: Set<ModifierKey>
    private(set) var isPending = false
    let toggleModifier: ModifierKey

    init(baselineModifiers: Set<ModifierKey>, toggleModifier: ModifierKey) {
        lastModifiers = baselineModifiers
        self.toggleModifier = toggleModifier
    }

    mutating func register(modifiers: Set<ModifierKey>) -> OptionToggleEventResult {
        guard modifiers != lastModifiers else {
            return .ignore
        }

        let previousModifiers = lastModifiers
        defer {
            lastModifiers = modifiers
        }

        if previousModifiers.isEmpty, modifiers == [toggleModifier] {
            isPending = true
            return .consume
        }

        if previousModifiers == [toggleModifier], modifiers.isEmpty, isPending {
            isPending = false
            return .toggle
        }

        if isPending {
            isPending = false
            if previousModifiers == [toggleModifier] || modifiers == [toggleModifier] {
                return .consume
            }
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
    var activeOtherMouseButtonNumber: Int64?
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
    var shiftGroupCycleTracker: ShiftGroupCycleTracker?
    var scrollGroupCycleTracker: ScrollGroupCycleTracker?
    var scrollGroupCycleResetWorkItem: DispatchWorkItem?
    var pendingRightClickToggle = false
}
