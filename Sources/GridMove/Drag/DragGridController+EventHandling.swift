import Carbon.HIToolbox
import CoreGraphics
import Foundation

extension DragGridController {
    func handleLeftMouseDown(event: CGEvent, configuration: AppConfiguration) -> Unmanaged<CGEvent>? {
        guard isEnabled, configuration.dragTriggers.enableModifierLeftMouseDrag else {
            return Unmanaged.passUnretained(event)
        }

        guard validateAccessibilityAccessForInteraction() else {
            return Unmanaged.passUnretained(event)
        }

        let flags = normalizedModifiers(from: event.flags)
        guard matchesAnyModifierGroup(flags: flags, groups: configuration.dragTriggers.modifierGroups) else {
            return Unmanaged.passUnretained(event)
        }

        let point = appKitPoint(from: event)
        guard let targetWindow = windowController.windowUnderCursor(at: point, configuration: configuration) else {
            resetState()
            return Unmanaged.passUnretained(event)
        }

        state.activeButton = .left
        state.mouseDownPoint = point
        enterDragMode(button: .left, targetWindow: targetWindow, point: point, configuration: configuration)
        return nil
    }

    func handleRightMouseDown(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard state.active else {
            return Unmanaged.passUnretained(event)
        }

        state.pendingRightClickToggle = true
        return nil
    }

    func handleRightMouseDragged(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard state.active || state.pendingRightClickToggle else {
            return Unmanaged.passUnretained(event)
        }

        return nil
    }

    func handleRightMouseUp(event: CGEvent, configuration: AppConfiguration) -> Unmanaged<CGEvent>? {
        guard state.pendingRightClickToggle else {
            return Unmanaged.passUnretained(event)
        }

        state.pendingRightClickToggle = false
        guard state.active else {
            return nil
        }

        toggleInteractionMode(at: appKitPoint(from: event), configuration: configuration)
        return nil
    }

    func handleOtherMouseDown(event: CGEvent, configuration: AppConfiguration) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        guard
            isEnabled,
            configuration.dragTriggers.enableMouseButtonDrag,
            buttonNumber == configuredOtherMouseButtonNumber(for: configuration)
        else {
            return Unmanaged.passUnretained(event)
        }

        guard validateAccessibilityAccessForInteraction() else {
            return Unmanaged.passUnretained(event)
        }

        let point = appKitPoint(from: event)
        resetState()
        state.activeButton = .mouseButton
        state.activeOtherMouseButtonNumber = buttonNumber
        state.mouseDownPoint = point

        if configuration.dragTriggers.activationDelayMilliseconds == 0 {
            handleOtherMouseActivation(configuration: configuration)
            return nil
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(configuration.dragTriggers.activationDelayMilliseconds))
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            self.state.activationTimer?.cancel()
            self.state.activationTimer = nil

            self.handleOtherMouseActivation(configuration: configuration)
        }
        state.activationTimer = timer
        timer.resume()
        return nil
    }

    func handleMouseDragged(
        event: CGEvent,
        expectedButton: DragTriggerButton,
        configuration: AppConfiguration
    ) -> Unmanaged<CGEvent>? {
        guard state.activeButton == expectedButton else {
            return Unmanaged.passUnretained(event)
        }

        guard state.active else {
            if expectedButton == .mouseButton, state.activationTimer != nil {
                return nil
            }
            return expectedButton == .left ? nil : Unmanaged.passUnretained(event)
        }

        updateDrag(at: appKitPoint(from: event), configuration: configuration)
        return nil
    }

    func handleMouseUp(
        event: CGEvent,
        button: DragTriggerButton,
        configuration: AppConfiguration
    ) -> Unmanaged<CGEvent>? {
        if state.suppressedMouseUpButton == button {
            state.suppressedMouseUpButton = nil
            return nil
        }

        guard state.activeButton == button else {
            return Unmanaged.passUnretained(event)
        }

        if state.activationTimer != nil {
            state.activationTimer?.cancel()
            if button == .mouseButton,
               let mouseDownPoint = state.mouseDownPoint,
               let activeOtherMouseButtonNumber = state.activeOtherMouseButtonNumber
            {
                postSyntheticOtherMouseClick(
                    downAt: windowController.quartzPoint(fromAppKitPoint: mouseDownPoint),
                    upAt: event.location,
                    buttonNumber: activeOtherMouseButtonNumber
                )
            }
            resetState()
            return nil
        }

        if state.active {
            if shouldMoveWindowDuringActiveDrag(configuration: configuration) {
                _ = applyPendingDragMoveIfNeeded(at: currentDragMoveTimestamp(), force: true)
            }
            finalizeLayoutSelection(at: appKitPoint(from: event), configuration: configuration)
            resetState()
            return nil
        }

        resetState()
        return button == .left ? nil : Unmanaged.passUnretained(event)
    }

    func handleOtherMouseUp(event: CGEvent, configuration: AppConfiguration) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let configuredButtonNumber = configuredOtherMouseButtonNumber(for: configuration)
        let expectedButtonNumber = state.activeOtherMouseButtonNumber ?? configuredButtonNumber
        guard buttonNumber == expectedButtonNumber else {
            return Unmanaged.passUnretained(event)
        }

        return handleMouseUp(event: event, button: .mouseButton, configuration: configuration)
    }

    func handleOtherMouseActivation(configuration: AppConfiguration) {
        guard
            state.activeButton == .mouseButton,
            let point = state.mouseDownPoint
        else {
            return
        }

        guard validateAccessibilityAccessForInteraction() else {
            return
        }

        guard let targetWindow = windowController.windowUnderCursor(at: point, configuration: configuration) else {
            state.suppressedMouseUpButton = .mouseButton
            resetState(keepSuppressedMouseUp: true)
            return
        }

        enterDragMode(button: .mouseButton, targetWindow: targetWindow, point: point, configuration: configuration)
    }

    func handleScrollWheel(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard state.active, state.interactionMode == .layoutSelection else {
            return Unmanaged.passUnretained(event)
        }

        let distance = verticalScrollDistance(from: event)
        guard distance != 0 else {
            return nil
        }

        var tracker = state.scrollGroupCycleTracker ?? makeScrollGroupCycleTracker()
        let direction = tracker.register(distance: distance)
        state.scrollGroupCycleTracker = tracker
        scheduleScrollGroupCycleReset()

        if let direction {
            cycleLayoutGroup(at: appKitPoint(from: event), direction: direction)
            state.scrollGroupCycleTracker = tracker
        }

        return nil
    }

    func handleFlagsChanged(event: CGEvent, configuration: AppConfiguration) -> Unmanaged<CGEvent>? {
        guard state.active else {
            return Unmanaged.passUnretained(event)
        }

        let modifiers = normalizedModifiers(from: event.flags)
        var consumedEvent = false

        if state.interactionMode == .layoutSelection, var shiftTracker = state.shiftGroupCycleTracker {
            let shiftResult = shiftTracker.register(modifiers: modifiers)
            state.shiftGroupCycleTracker = shiftTracker

            switch shiftResult {
            case .ignore:
                break
            case .consume:
                consumedEvent = true
            case .toggle:
                cycleLayoutGroup(at: appKitPoint(from: event))
                return nil
            }
        }

        if var optionTracker = state.optionToggleTracker {
            let optionResult = optionTracker.register(modifiers: modifiers)
            state.optionToggleTracker = optionTracker

            switch optionResult {
            case .ignore:
                break
            case .consume:
                consumedEvent = true
            case .toggle:
                toggleInteractionMode(at: appKitPoint(from: event), configuration: configuration)
                return nil
            }
        }

        return consumedEvent ? nil : Unmanaged.passUnretained(event)
    }

    func handleKeyDown(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Escape) else {
            return Unmanaged.passUnretained(event)
        }

        guard state.active || state.activationTimer != nil else {
            return Unmanaged.passUnretained(event)
        }

        cancelAndSuppressActiveMouseUp()
        return nil
    }
}
