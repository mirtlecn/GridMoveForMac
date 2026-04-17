@preconcurrency import AppKit
import CoreGraphics
import Foundation

extension DragGridController {
    func postSyntheticMiddleMouseDown(at point: CGPoint) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        guard let syntheticEvent = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: point, mouseButton: .center) else {
            return
        }

        SyntheticEventMarker.markMiddleMouseReplay(syntheticEvent)
        syntheticEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(DragTriggerButton.middle.rawValue))
        syntheticEvent.post(tap: .cghidEventTap)
    }

    func postSyntheticMiddleMouseClick(downAt downPoint: CGPoint, upAt upPoint: CGPoint) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        guard
            let downEvent = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: downPoint, mouseButton: .center),
            let upEvent = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: upPoint, mouseButton: .center)
        else {
            return
        }

        SyntheticEventMarker.markMiddleMouseReplay(downEvent)
        SyntheticEventMarker.markMiddleMouseReplay(upEvent)
        downEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(DragTriggerButton.middle.rawValue))
        upEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(DragTriggerButton.middle.rawValue))
        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
    }

    func currentWindowFrame() -> CGRect? {
        state.currentWindowFrame ?? state.targetWindow?.frame
    }

    func normalizedModifiers(from flags: CGEventFlags) -> Set<ModifierKey> {
        var result: Set<ModifierKey> = []
        if flags.contains(.maskControl) { result.insert(.ctrl) }
        if flags.contains(.maskCommand) { result.insert(.cmd) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskAlternate) { result.insert(.alt) }
        return result
    }

    func appKitPoint(from event: CGEvent) -> CGPoint {
        event.unflippedLocation
    }

    var isOptionPressed: Bool {
        NSEvent.modifierFlags.contains(.option)
    }

    func pointsApproximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, tolerance: CGFloat = 0.5) -> Bool {
        abs(lhs.x - rhs.x) < tolerance && abs(lhs.y - rhs.y) < tolerance
    }

    static func matchesAnyModifierGroup(flags: Set<ModifierKey>, groups: [[ModifierKey]]) -> Bool {
        groups.contains { !$0.isEmpty && Set($0) == flags }
    }

    func matchesAnyModifierGroup(flags: Set<ModifierKey>, groups: [[ModifierKey]]) -> Bool {
        Self.matchesAnyModifierGroup(flags: flags, groups: groups)
    }

    func ensureAccessibilityIsStillGranted() -> Bool {
        guard accessibilityTrustedProvider() else {
            resetState()
            scheduleAccessibilityRevocationHandling()
            return false
        }
        return true
    }

    func validateAccessibilityAccessForInteraction() -> Bool {
        guard accessibilityAccessValidator() else {
            resetState()
            scheduleAccessibilityRevocationHandling()
            return false
        }

        return true
    }

    func scheduleAccessibilityRevocationHandling() {
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
