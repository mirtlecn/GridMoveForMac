import CoreGraphics
import Foundation

extension DragGridController {
    private enum MoveOnlyUpdateConstants {
        static let minimumInterval: TimeInterval = 1.0 / 120.0
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
        state.cursorPoint = point
        state.optionToggleTracker = OptionToggleTracker(baselineModifiers: currentModifierKeys)
        state.shiftGroupCycleTracker = ShiftGroupCycleTracker(baselineModifiers: currentModifierKeys)
        state.pendingRightClickToggle = false

        let initialMode = Self.preferredInteractionMode(preferLayoutMode: configuration.dragTriggers.preferLayoutMode)
        switch initialMode {
        case .layoutSelection:
            configureLayoutSelectionMode(
                at: point,
                configuration: configuration,
                shouldApplyImmediately: false
            )
        case .moveOnly:
            configureMoveOnlyMode(at: point, configuration: configuration)
        }
    }

    func updateDrag(at point: CGPoint, configuration: AppConfiguration) {
        state.cursorPoint = point
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
                    triggerGap: Double(configuration.appearance.triggerGap),
                    layoutGap: configuration.appearance.effectiveLayoutGap
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

        updateLayoutSelection(at: point, configuration: configuration)
    }

    func updateMoveOnlyDrag(at point: CGPoint) {
        state.pendingMoveOnlyPoint = point
        let timestamp = testHooks?.currentTimeProvider?() ?? ProcessInfo.processInfo.systemUptime
        applyPendingMoveOnlyDragIfNeeded(at: timestamp)
    }

    func applyPendingMoveOnlyDragIfNeeded(at timestamp: TimeInterval, force: Bool = false) {
        guard validateAccessibilityAccessForInteraction() else {
            return
        }

        guard
            let targetWindow = state.targetWindow,
            let moveAnchor = state.moveAnchor,
            var frame = state.currentWindowFrame,
            let pendingPoint = state.pendingMoveOnlyPoint
        else {
            return
        }

        if !force,
           let lastMoveOnlyUpdateTime = state.lastMoveOnlyUpdateTime,
           timestamp - lastMoveOnlyUpdateTime < MoveOnlyUpdateConstants.minimumInterval
        {
            return
        }

        let nextOrigin = moveAnchor.movedOrigin(for: pendingPoint)
        guard !pointsApproximatelyEqual(nextOrigin, frame.origin) else {
            state.pendingMoveOnlyPoint = nil
            state.lastMoveOnlyUpdateTime = timestamp
            return
        }

        let moveWindow = testHooks?.moveWindow ?? { [windowController] origin, currentFrame, window in
            windowController.moveWindow(to: origin, currentFrame: currentFrame, for: window)
        }
        if moveWindow(nextOrigin, frame, targetWindow) {
            frame.origin = nextOrigin
            updateCurrentWindowFrame(for: targetWindow, fallback: frame)
        }

        state.pendingMoveOnlyPoint = nil
        state.lastMoveOnlyUpdateTime = timestamp
        if let refreshOverlay = testHooks?.refreshOverlay {
            refreshOverlay(configurationProvider())
        } else {
            refreshOverlay(configuration: configurationProvider())
        }
    }

    func toggleInteractionMode(at point: CGPoint, configuration: AppConfiguration) {
        guard state.active else {
            return
        }

        switch state.interactionMode {
        case .layoutSelection:
            configureMoveOnlyMode(at: point, configuration: configuration)
        case .moveOnly:
            configureLayoutSelectionMode(
                at: point,
                configuration: configuration,
                shouldApplyImmediately: false
            )
        }
    }

    func configureLayoutSelectionMode(
        at point: CGPoint,
        configuration: AppConfiguration,
        shouldApplyImmediately: Bool
    ) {
        prepareForModeTransition(at: point, interactionMode: .layoutSelection)
        state.moveAnchor = nil
        state.scrollGroupCycleResetWorkItem?.cancel()
        state.scrollGroupCycleResetWorkItem = nil
        state.scrollGroupCycleTracker = makeScrollGroupCycleTracker()

        let fallbackScreen = currentWindowFrame()
            .flatMap { frame in
                windowController.screenContaining(point: CGPoint(x: frame.midX, y: frame.midY))
            }
        state.activeScreen = windowController.resolvedScreen(for: point, fallback: fallbackScreen)
        state.resolvedSlots = state.activeScreen.map {
            layoutEngine.resolveTriggerSlots(
                on: $0,
                layouts: LayoutGroupResolver.triggerableLayouts(for: $0, configuration: configuration),
                triggerGap: Double(configuration.appearance.triggerGap),
                layoutGap: configuration.appearance.effectiveLayoutGap
            )
        } ?? []

        if shouldApplyImmediately {
            state.hasDraggedPastThreshold = true
            updateLayoutSelection(at: point, configuration: configuration)
            return
        }

        state.hasDraggedPastThreshold = false

        refreshOverlay(configuration: configuration)
    }

    func configureMoveOnlyMode(
        at point: CGPoint,
        configuration: AppConfiguration
    ) {
        prepareForModeTransition(at: point, interactionMode: .moveOnly)
        state.hasDraggedPastThreshold = true
        state.shiftGroupCycleTracker = nil
        state.scrollGroupCycleResetWorkItem?.cancel()
        state.scrollGroupCycleResetWorkItem = nil
        state.scrollGroupCycleTracker = nil
        state.pendingMoveOnlyPoint = nil
        state.lastMoveOnlyUpdateTime = nil

        let windowFrame = currentWindowFrame()
        if let frame = windowFrame {
            state.moveAnchor = MoveAnchor(mousePoint: point, windowOrigin: frame.origin)
        } else {
            state.moveAnchor = nil
        }

        refreshOverlay(configuration: configuration)
    }

    func prepareForModeTransition(at point: CGPoint, interactionMode: DragInteractionMode) {
        syncCurrentWindowFrameFromLiveWindow()
        state.interactionMode = interactionMode
        state.cursorPoint = point
        state.overlayActivationPoint = point
        state.hoveredLayoutID = nil
        state.lastAppliedLayoutID = nil
        state.shiftGroupCycleTracker = ShiftGroupCycleTracker(baselineModifiers: currentModifierKeys)
    }

    func syncCurrentWindowFrameFromLiveWindow() {
        guard let targetWindow = state.targetWindow else {
            return
        }

        updateCurrentWindowFrame(for: targetWindow, fallback: nil)
    }

    func updateCurrentWindowFrame(for targetWindow: ManagedWindow, fallback: CGRect?) {
        let liveWindowFrame = testHooks?.currentWindowFrame?(targetWindow) ?? windowController.currentFrame(for: targetWindow)
        if let liveWindowFrame {
            state.currentWindowFrame = liveWindowFrame
            return
        }

        if let fallback {
            state.currentWindowFrame = fallback
        }
    }

    func updateLayoutSelection(at point: CGPoint, configuration: AppConfiguration) {
        let hoveredSlot = layoutEngine.triggerSlot(containing: point, slots: state.resolvedSlots)
        state.hoveredLayoutID = hoveredSlot?.layoutID

        if configuration.dragTriggers.applyLayoutImmediatelyWhileDragging,
           let hoveredSlot
        {
            applyLayoutSelection(slot: hoveredSlot, configuration: configuration)
        }

        refreshOverlay(configuration: configuration)
    }

    func finalizeLayoutSelection(at point: CGPoint, configuration: AppConfiguration) {
        guard state.interactionMode == .layoutSelection else {
            return
        }

        guard state.hasDraggedPastThreshold else {
            return
        }

        let hoveredSlot = layoutEngine.triggerSlot(containing: point, slots: state.resolvedSlots)
        state.hoveredLayoutID = hoveredSlot?.layoutID

        guard !configuration.dragTriggers.applyLayoutImmediatelyWhileDragging,
              let hoveredSlot
        else {
            return
        }

        applyLayoutSelection(slot: hoveredSlot, configuration: configuration)
    }

    private func applyLayoutSelection(slot: ResolvedTriggerSlot, configuration: AppConfiguration) {
        guard let targetWindow = state.targetWindow else {
            return
        }

        guard validateAccessibilityAccessForInteraction() else {
            return
        }

        guard slot.layoutID != state.lastAppliedLayoutID else {
            return
        }

        windowController.applyLayout(
            layoutID: slot.layoutID,
            to: targetWindow,
            preferredScreen: state.activeScreen,
            configuration: configuration
        )
        state.currentWindowFrame = slot.targetFrame
        state.lastAppliedLayoutID = slot.layoutID
    }

    func refreshOverlay(configuration: AppConfiguration) {
        guard state.active else {
            overlayController.dismiss()
            return
        }

        let highlightFrame = overlayHighlightFrame()

        switch state.interactionMode {
        case .layoutSelection:
            guard let screen = state.activeScreen else {
                overlayController.dismiss()
                return
            }

            overlayController.update(
                screen: screen,
                slots: state.resolvedSlots,
                highlightFrame: highlightFrame,
                hoveredLayoutID: state.hoveredLayoutID,
                configuration: configuration
            )
        case .moveOnly:
            guard let point = state.cursorPoint ?? state.overlayActivationPoint ?? state.mouseDownPoint else {
                overlayController.dismiss()
                return
            }
            let fallbackScreen = currentWindowFrame()
                .flatMap { frame in
                    windowController.screenContaining(point: CGPoint(x: frame.midX, y: frame.midY))
                }
            guard let screen = windowController.resolvedScreen(for: point, fallback: fallbackScreen) else {
                overlayController.dismiss()
                return
            }

            overlayController.update(
                screen: screen,
                slots: [],
                highlightFrame: highlightFrame,
                hoveredLayoutID: nil,
                configuration: configuration
            )
        }
    }

    func cycleLayoutGroup(at point: CGPoint, direction: LayoutGroupCycleDirection = .next) {
        guard state.interactionMode == .layoutSelection else {
            return
        }

        state.cursorPoint = point

        guard let updatedConfiguration = cycleActiveLayoutGroup(direction) else {
            return
        }

        configureLayoutSelectionMode(
            at: point,
            configuration: updatedConfiguration,
            shouldApplyImmediately: false
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
        state.scrollGroupCycleResetWorkItem?.cancel()
        let suppressedMouseUpButton = keepSuppressedMouseUp ? state.suppressedMouseUpButton : nil
        state = DragInteractionState()
        state.suppressedMouseUpButton = suppressedMouseUpButton
        overlayController.dismiss()
    }

    func overlayHighlightFrame() -> CGRect? {
        let actualWindowFrame = currentWindowFrame()

        guard state.interactionMode == .layoutSelection else {
            return actualWindowFrame
        }

        guard state.hasDraggedPastThreshold else {
            return actualWindowFrame
        }

        guard let hoveredLayoutID = state.hoveredLayoutID else {
            return actualWindowFrame
        }

        let previewFrame = state.resolvedSlots.first(where: { $0.layoutID == hoveredLayoutID })?.targetFrame
        return previewFrame ?? actualWindowFrame
    }
}
