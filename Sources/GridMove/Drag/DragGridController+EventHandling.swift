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
            configuration.dragTriggers.enableMiddleMouseDrag,
            buttonNumber == Int64(configuration.dragTriggers.middleMouseButtonNumber)
        else {
            return Unmanaged.passUnretained(event)
        }

        guard validateAccessibilityAccessForInteraction() else {
            return Unmanaged.passUnretained(event)
        }

        let point = appKitPoint(from: event)
        resetState()
        state.activeButton = .middle
        state.mouseDownPoint = point

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + configuration.dragTriggers.activationDelaySeconds)
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }

            self.state.activationTimer?.cancel()
            self.state.activationTimer = nil

            guard self.state.activeButton == .middle, let point = self.state.mouseDownPoint else {
                return
            }

            guard self.validateAccessibilityAccessForInteraction() else {
                return
            }

            guard let targetWindow = self.windowController.windowUnderCursor(at: point, configuration: configuration) else {
                self.postSyntheticMiddleMouseDown(at: self.windowController.quartzPoint(fromAppKitPoint: point))
                self.resetState()
                return
            }

            self.enterDragMode(button: .middle, targetWindow: targetWindow, point: point, configuration: configuration)
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
            if expectedButton == .middle, state.activationTimer != nil {
                return nil
            }
            return expectedButton == .left ? nil : Unmanaged.passUnretained(event)
        }

        updateDrag(at: appKitPoint(from: event), configuration: configuration)
        return nil
    }

    func handleMouseUp(event: CGEvent, button: DragTriggerButton) -> Unmanaged<CGEvent>? {
        if state.suppressedMouseUpButton == button {
            state.suppressedMouseUpButton = nil
            return nil
        }

        guard state.activeButton == button else {
            return Unmanaged.passUnretained(event)
        }

        if state.activationTimer != nil {
            state.activationTimer?.cancel()
            if button == .middle, let mouseDownPoint = state.mouseDownPoint {
                postSyntheticMiddleMouseClick(
                    downAt: windowController.quartzPoint(fromAppKitPoint: mouseDownPoint),
                    upAt: event.location
                )
            }
            resetState()
            return nil
        }

        if state.active {
            resetState()
            return nil
        }

        resetState()
        return button == .left ? nil : Unmanaged.passUnretained(event)
    }

    func handleOtherMouseUp(event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        guard buttonNumber == Int64(DragTriggerButton.middle.rawValue) else {
            return Unmanaged.passUnretained(event)
        }

        return handleMouseUp(event: event, button: .middle)
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
