import CoreGraphics
import Foundation

extension DragGridController {
    static func preferredMoveOnlyFlashScreen<Screen>(
        windowScreen: Screen?,
        activeScreen: Screen?,
        pointerScreen: Screen?
    ) -> Screen? {
        windowScreen ?? activeScreen ?? pointerScreen
    }

    func enterDragMode(
        button: DragTriggerButton,
        targetWindow: ManagedWindow,
        point: CGPoint,
        configuration: AppConfiguration
    ) {
        guard validateAccessibilityAccessForInteraction() else {
            return
        }

        windowController.focus(targetWindow)
        state.active = true
        state.activeButton = button
        state.targetWindow = targetWindow
        state.currentWindowFrame = targetWindow.frame
        state.optionToggleTracker = OptionToggleTracker(baselineModifiers: currentModifierKeys)
        state.shiftGroupCycleTracker = ShiftGroupCycleTracker(baselineModifiers: currentModifierKeys)
        state.pendingRightClickToggle = false

        let initialMode = Self.preferredInteractionMode(preferLayoutMode: configuration.dragTriggers.preferLayoutMode)
        switch initialMode {
        case .layoutSelection:
            configureLayoutSelectionMode(
                at: point,
                configuration: configuration,
                shouldApplyImmediately: false,
                shouldFlashHighlight: false
            )
        case .moveOnly:
            configureMoveOnlyMode(at: point, configuration: configuration, shouldFlashHighlight: true)
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
            state.resolvedSlots = nextScreen.map {
                layoutEngine.resolveTriggerSlots(
                    on: $0,
                    layouts: LayoutGroupResolver.triggerableLayouts(for: $0, configuration: configuration),
                    triggerGap: configuration.appearance.triggerGap
                )
            } ?? []
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

        guard validateAccessibilityAccessForInteraction() else {
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
            configureMoveOnlyMode(at: point, configuration: configuration, shouldFlashHighlight: true)
        case .moveOnly:
            configureLayoutSelectionMode(
                at: point,
                configuration: configuration,
                shouldApplyImmediately: false,
                shouldFlashHighlight: false
            )
        }
    }

    func configureLayoutSelectionMode(
        at point: CGPoint,
        configuration: AppConfiguration,
        shouldApplyImmediately: Bool,
        shouldFlashHighlight: Bool
    ) {
        state.interactionMode = .layoutSelection
        state.moveAnchor = nil
        state.overlayActivationPoint = point
        state.hoveredLayoutID = nil
        state.lastAppliedLayoutID = nil
        state.shiftGroupCycleTracker = ShiftGroupCycleTracker(baselineModifiers: currentModifierKeys)

        let fallbackScreen = currentWindowFrame()
            .flatMap { frame in
                windowController.screenContaining(point: CGPoint(x: frame.midX, y: frame.midY))
            }
        state.activeScreen = windowController.resolvedScreen(for: point, fallback: fallbackScreen)
        state.resolvedSlots = state.activeScreen.map {
            layoutEngine.resolveTriggerSlots(
                on: $0,
                layouts: LayoutGroupResolver.triggerableLayouts(for: $0, configuration: configuration),
                triggerGap: configuration.appearance.triggerGap
            )
        } ?? []

        if shouldApplyImmediately {
            state.hasDraggedPastThreshold = true
            applyLayoutSelection(at: point, configuration: configuration)
            return
        }

        state.hasDraggedPastThreshold = false

        if shouldFlashHighlight,
           let screen = state.activeScreen,
           let frame = currentWindowFrame()
        {
            overlayController.flashHighlight(
                frame: frame,
                screen: screen,
                slots: state.resolvedSlots,
                configuration: configuration,
                keepsOverlayVisibleAfterFlash: true
            )
            return
        }

        refreshOverlay(configuration: configuration)
    }

    func configureMoveOnlyMode(
        at point: CGPoint,
        configuration: AppConfiguration,
        shouldFlashHighlight: Bool
    ) {
        state.interactionMode = .moveOnly
        state.overlayActivationPoint = point
        state.hoveredLayoutID = nil
        state.lastAppliedLayoutID = nil
        state.hasDraggedPastThreshold = true
        state.shiftGroupCycleTracker = nil

        let windowFrame = currentWindowFrame()
        if let frame = windowFrame {
            state.moveAnchor = MoveAnchor(mousePoint: point, windowOrigin: frame.origin)
        } else {
            state.moveAnchor = nil
        }

        let fallbackScreen = windowFrame.flatMap { frame in
            windowController.screenContaining(point: CGPoint(x: frame.midX, y: frame.midY))
        }
        let pointerScreen = windowController.resolvedScreen(for: point, fallback: fallbackScreen)
        let screen = Self.preferredMoveOnlyFlashScreen(
            windowScreen: fallbackScreen,
            activeScreen: state.activeScreen,
            pointerScreen: pointerScreen
        )
        if shouldFlashHighlight, let screen, let windowFrame {
            overlayController.flashHighlight(frame: windowFrame, screen: screen, configuration: configuration)
        } else {
            overlayController.dismiss()
        }
    }

    func applyLayoutSelection(at point: CGPoint, configuration: AppConfiguration) {
        guard let targetWindow = state.targetWindow else {
            return
        }

        guard validateAccessibilityAccessForInteraction() else {
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

        overlayController.update(
            screen: screen,
            slots: state.resolvedSlots,
            highlightFrame: overlayHighlightFrame(),
            configuration: configuration
        )
    }

    func cycleLayoutGroup(at point: CGPoint) {
        guard state.interactionMode == .layoutSelection else {
            return
        }

        guard let updatedConfiguration = cycleActiveLayoutGroup() else {
            return
        }

        configureLayoutSelectionMode(
            at: point,
            configuration: updatedConfiguration,
            shouldApplyImmediately: false,
            shouldFlashHighlight: false
        )

        guard let screen = state.activeScreen else {
            return
        }

        overlayController.flashGroupLabel(
            text: updatedConfiguration.general.activeLayoutGroup,
            screen: screen,
            slots: state.resolvedSlots,
            highlightFrame: overlayHighlightFrame() ?? currentWindowFrame(),
            configuration: updatedConfiguration,
            keepsOverlayVisibleAfterFlash: true
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

    func overlayHighlightFrame() -> CGRect? {
        if !state.hasDraggedPastThreshold {
            return currentWindowFrame()
        }

        guard let hoveredLayoutID = state.hoveredLayoutID else {
            return nil
        }

        return state.resolvedSlots.first(where: { $0.layoutID == hoveredLayoutID })?.targetFrame
    }
}
