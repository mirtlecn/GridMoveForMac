import CoreGraphics
import Foundation

extension DragGridController {
    func enterDragMode(
        button: DragTriggerButton,
        targetWindow: ManagedWindow,
        point: CGPoint,
        configuration: AppConfiguration
    ) {
        windowController.focus(targetWindow)
        state.active = true
        state.activeButton = button
        state.targetWindow = targetWindow
        state.currentWindowFrame = targetWindow.frame
        state.optionToggleTracker = OptionToggleTracker(baselinePressed: isOptionPressed)
        state.pendingRightClickToggle = false

        let initialMode = Self.preferredInteractionMode(preferLayoutMode: configuration.dragTriggers.preferLayoutMode)
        switch initialMode {
        case .layoutSelection:
            configureLayoutSelectionMode(at: point, configuration: configuration, shouldApplyImmediately: false)
        case .moveOnly:
            configureMoveOnlyMode(at: point)
        }
    }

    func updateDrag(at point: CGPoint, configuration: AppConfiguration) {
        switch state.interactionMode {
        case .layoutSelection:
            updateLayoutSelectionDrag(at: point, configuration: configuration)
        case .moveOnly:
            updateMoveOnlyDrag(at: point)
        }
    }

    func updateLayoutSelectionDrag(at point: CGPoint, configuration: AppConfiguration) {
        guard state.targetWindow != nil else {
            return
        }

        let nextScreen = windowController.resolvedScreen(for: point, fallback: state.activeScreen)
        if nextScreen.map(Geometry.screenIdentifier(for:)) != state.activeScreen.map(Geometry.screenIdentifier(for:)) {
            state.activeScreen = nextScreen
            state.resolvedSlots = nextScreen.map { layoutEngine.resolveTriggerSlots(on: $0, configuration: configuration) } ?? []
            state.hoveredLayoutID = nil
            state.lastAppliedLayoutID = nil
        }

        if !state.hasDraggedPastThreshold {
            guard let activationPoint = state.overlayActivationPoint else {
                return
            }

            if Geometry.distance(from: point, to: activationPoint) < configuration.dragTriggers.activationMoveThreshold {
                refreshOverlay(configuration: configuration)
                return
            }
            state.hasDraggedPastThreshold = true
        }

        applyLayoutSelection(at: point, configuration: configuration)
    }

    func updateMoveOnlyDrag(at point: CGPoint) {
        guard
            let targetWindow = state.targetWindow,
            let moveAnchor = state.moveAnchor,
            var frame = state.currentWindowFrame
        else {
            return
        }

        let nextOrigin = moveAnchor.movedOrigin(for: point)
        guard !pointsApproximatelyEqual(nextOrigin, frame.origin) else {
            return
        }

        if windowController.moveWindow(to: nextOrigin, currentFrame: frame, for: targetWindow) {
            frame.origin = nextOrigin
            state.currentWindowFrame = frame
        }
    }

    func toggleInteractionMode(at point: CGPoint, configuration: AppConfiguration) {
        guard state.active else {
            return
        }

        switch state.interactionMode {
        case .layoutSelection:
            configureMoveOnlyMode(at: point)
        case .moveOnly:
            configureLayoutSelectionMode(at: point, configuration: configuration, shouldApplyImmediately: false)
        }
    }

    func configureLayoutSelectionMode(
        at point: CGPoint,
        configuration: AppConfiguration,
        shouldApplyImmediately: Bool
    ) {
        state.interactionMode = .layoutSelection
        state.moveAnchor = nil
        state.overlayActivationPoint = point
        state.hoveredLayoutID = nil
        state.lastAppliedLayoutID = nil

        let fallbackScreen = currentWindowFrame()
            .flatMap { frame in
                windowController.screenContaining(point: CGPoint(x: frame.midX, y: frame.midY))
            }
        state.activeScreen = windowController.resolvedScreen(for: point, fallback: fallbackScreen)
        state.resolvedSlots = state.activeScreen.map { layoutEngine.resolveTriggerSlots(on: $0, configuration: configuration) } ?? []

        if shouldApplyImmediately {
            state.hasDraggedPastThreshold = true
            applyLayoutSelection(at: point, configuration: configuration)
            return
        }

        state.hasDraggedPastThreshold = false
        refreshOverlay(configuration: configuration)
    }

    func configureMoveOnlyMode(at point: CGPoint) {
        state.interactionMode = .moveOnly
        state.overlayActivationPoint = point
        state.hoveredLayoutID = nil
        state.lastAppliedLayoutID = nil
        state.hasDraggedPastThreshold = true

        if let frame = currentWindowFrame() {
            state.moveAnchor = MoveAnchor(mousePoint: point, windowOrigin: frame.origin)
        } else {
            state.moveAnchor = nil
        }

        overlayController.dismiss()
    }

    func applyLayoutSelection(at point: CGPoint, configuration: AppConfiguration) {
        guard let targetWindow = state.targetWindow else {
            return
        }

        let hoveredSlot = layoutEngine.triggerSlot(containing: point, slots: state.resolvedSlots)
        state.hoveredLayoutID = hoveredSlot?.layoutID
        if let hoveredSlot, hoveredSlot.layoutID != state.lastAppliedLayoutID {
            windowController.applyLayout(
                layoutID: hoveredSlot.layoutID,
                to: targetWindow,
                preferredScreen: state.activeScreen,
                configuration: configuration
            )
            state.currentWindowFrame = hoveredSlot.targetFrame
            state.lastAppliedLayoutID = hoveredSlot.layoutID
        }
        refreshOverlay(configuration: configuration)
    }

    func refreshOverlay(configuration: AppConfiguration) {
        guard state.interactionMode == .layoutSelection else {
            overlayController.dismiss()
            return
        }

        guard let screen = state.activeScreen else {
            overlayController.dismiss()
            return
        }

        let highlightFrame: CGRect?
        if !state.hasDraggedPastThreshold {
            highlightFrame = currentWindowFrame()
        } else if let hoveredLayoutID = state.hoveredLayoutID {
            highlightFrame = state.resolvedSlots.first(where: { $0.layoutID == hoveredLayoutID })?.targetFrame
        } else {
            highlightFrame = nil
        }

        overlayController.update(
            screen: screen,
            slots: state.resolvedSlots,
            highlightFrame: highlightFrame,
            configuration: configuration
        )
    }

    func cancelAndSuppressActiveMouseUp() {
        if let activeButton = state.activeButton {
            state.suppressedMouseUpButton = activeButton
        }
        resetState(keepSuppressedMouseUp: true)
    }

    func resetState(keepSuppressedMouseUp: Bool = false) {
        state.activationTimer?.cancel()
        let suppressedMouseUpButton = keepSuppressedMouseUp ? state.suppressedMouseUpButton : nil
        state = DragInteractionState()
        state.suppressedMouseUpButton = suppressedMouseUpButton
        overlayController.dismiss()
    }
}
