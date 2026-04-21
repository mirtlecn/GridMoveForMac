import AppKit
import CoreGraphics
import Foundation

extension DragGridController {
    private enum DragMoveUpdateConstants {
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

        if !state.hasDraggedPastThreshold {
            updateActiveScreenAndResolvedSlots(at: point, configuration: configuration)

            guard let activationPoint = state.overlayActivationPoint else {
                return
            }

            if Geometry.distance(from: point, to: activationPoint) < configuration.dragTriggers.activationMoveThreshold {
                refreshOverlay(configuration: configuration)
                return
            }
            state.hasDraggedPastThreshold = true
        }

        if shouldMoveWindowDuringActiveDrag(configuration: configuration) {
            queuePendingDragMove(at: point)
            _ = applyPendingDragMoveIfNeeded(at: currentDragMoveTimestamp())
        }

        updateActiveScreenAndResolvedSlots(at: point, configuration: configuration)
        updateLayoutSelection(at: point, configuration: configuration)
    }

    func updateMoveOnlyDrag(at point: CGPoint) {
        queuePendingDragMove(at: point)
        let didMoveWindow = applyPendingDragMoveIfNeeded(at: currentDragMoveTimestamp())
        if didMoveWindow {
            if let refreshOverlay = testHooks?.refreshOverlay {
                refreshOverlay(configurationProvider())
            } else {
                refreshOverlay(configuration: configurationProvider())
            }
        }
    }

    @discardableResult
    func applyPendingDragMoveIfNeeded(at timestamp: TimeInterval, force: Bool = false) -> Bool {
        guard validateAccessibilityAccessForInteraction() else {
            return false
        }

        guard
            let targetWindow = state.targetWindow,
            let moveAnchor = state.moveAnchor,
            var frame = state.currentWindowFrame,
            let pendingPoint = state.pendingDragMovePoint
        else {
            return false
        }

        if !force,
           let lastDragMoveUpdateTime = state.lastDragMoveUpdateTime,
           timestamp - lastDragMoveUpdateTime < DragMoveUpdateConstants.minimumInterval
        {
            return false
        }

        let nextOrigin = moveAnchor.movedOrigin(for: pendingPoint)
        guard !pointsApproximatelyEqual(nextOrigin, frame.origin) else {
            state.pendingDragMovePoint = nil
            state.lastDragMoveUpdateTime = timestamp
            return false
        }

        let moveWindow = testHooks?.moveWindow ?? { [windowController] origin, currentFrame, window in
            windowController.moveWindow(to: origin, currentFrame: currentFrame, for: window)
        }
        let didMoveWindow = moveWindow(nextOrigin, frame, targetWindow)
        if didMoveWindow {
            frame.origin = nextOrigin
            updateCurrentWindowFrame(for: targetWindow, fallback: frame)
        }

        state.pendingDragMovePoint = nil
        state.lastDragMoveUpdateTime = timestamp
        return didMoveWindow
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
        state.scrollGroupCycleResetWorkItem?.cancel()
        state.scrollGroupCycleResetWorkItem = nil
        state.scrollGroupCycleTracker = makeScrollGroupCycleTracker()

        let windowFrame = currentWindowFrame()
        if let frame = windowFrame {
            state.moveAnchor = MoveAnchor(mousePoint: point, windowOrigin: frame.origin)
        } else {
            state.moveAnchor = nil
        }
        state.pendingDragMovePoint = nil
        state.lastDragMoveUpdateTime = nil

        let fallbackScreen = windowFrame
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
        state.pendingDragMovePoint = nil
        state.lastDragMoveUpdateTime = nil

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

    func applyLayoutIndexAndExit(layoutIndex: Int, configuration: AppConfiguration) {
        guard let targetWindow = state.targetWindow else {
            exitInteractionAfterKeyboardShortcut()
            return
        }

        defer {
            exitInteractionAfterKeyboardShortcut()
        }

        guard let resolvedEntry = LayoutGroupResolver.entry(at: layoutIndex, configuration: configuration) else {
            return
        }

        let currentScreen = keyboardActionCurrentScreen(for: targetWindow)
        guard let targetScreen = LayoutGroupResolver.targetScreen(
            for: resolvedEntry,
            currentScreen: currentScreen,
            configuration: configuration
        ) else {
            return
        }

        let applyLayout = testHooks?.applyLayout ?? { [windowController] layoutID, window, preferredScreen, configuration in
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: preferredScreen,
                configuration: configuration
            )
        }
        applyLayout(resolvedEntry.layout.id, targetWindow, targetScreen, configuration)
    }

    func closeActiveWindowAndExit() {
        guard let targetWindow = state.targetWindow else {
            exitInteractionAfterKeyboardShortcut()
            return
        }

        let closeWindow = testHooks?.closeWindow ?? { [windowController] window in
            windowController.close(window)
        }
        _ = closeWindow(targetWindow)
        exitInteractionAfterKeyboardShortcut()
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

        let applyLayout = testHooks?.applyLayout ?? { [windowController] layoutID, window, preferredScreen, configuration in
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: preferredScreen,
                configuration: configuration
            )
        }
        applyLayout(slot.layoutID, targetWindow, state.activeScreen, configuration)
        state.currentWindowFrame = slot.targetFrame
        state.lastAppliedLayoutID = slot.layoutID
    }

    func refreshOverlay(configuration: AppConfiguration) {
        guard state.active else {
            overlayController.dismiss()
            return
        }

        let highlightFrame = overlayHighlightFrame(configuration: configuration)

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

    func exitInteractionAfterKeyboardShortcut() {
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

    func overlayHighlightFrame(configuration: AppConfiguration) -> CGRect? {
        let actualWindowFrame = currentWindowFrame()

        guard state.interactionMode == .layoutSelection else {
            return actualWindowFrame
        }

        guard state.hasDraggedPastThreshold else {
            return actualWindowFrame
        }

        guard let hoveredLayoutID = state.hoveredLayoutID else {
            if !configuration.dragTriggers.applyLayoutImmediatelyWhileDragging {
                return nil
            }
            return actualWindowFrame
        }

        let previewFrame = state.resolvedSlots.first(where: { $0.layoutID == hoveredLayoutID })?.targetFrame
        return previewFrame ?? actualWindowFrame
    }

    func updateActiveScreenAndResolvedSlots(at point: CGPoint, configuration: AppConfiguration) {
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
    }

    func queuePendingDragMove(at point: CGPoint) {
        state.pendingDragMovePoint = point
    }

    func currentDragMoveTimestamp() -> TimeInterval {
        testHooks?.currentTimeProvider?() ?? ProcessInfo.processInfo.systemUptime
    }

    func shouldMoveWindowDuringActiveDrag(configuration: AppConfiguration) -> Bool {
        switch state.interactionMode {
        case .moveOnly:
            return true
        case .layoutSelection:
            return state.hasDraggedPastThreshold && !configuration.dragTriggers.applyLayoutImmediatelyWhileDragging
        }
    }

    private func keyboardActionCurrentScreen(for targetWindow: ManagedWindow) -> NSScreen? {
        if let activeScreen = state.activeScreen {
            return activeScreen
        }

        if let frame = currentWindowFrame() {
            return windowController.screenContaining(point: CGPoint(x: frame.midX, y: frame.midY))
        }

        return windowController.screenContaining(point: CGPoint(x: targetWindow.frame.midX, y: targetWindow.frame.midY))
    }
}
