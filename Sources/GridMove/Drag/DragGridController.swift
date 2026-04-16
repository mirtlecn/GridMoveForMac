@preconcurrency import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class DragGridController {
    private enum TriggerButton: Int {
        case left = 0
        case middle = 2
    }

    private struct State {
        var active = false
        var activeButton: TriggerButton?
        var activationTimer: DispatchSourceTimer?
        var activeScreen: NSScreen?
        var hasDraggedPastThreshold = false
        var hoveredLayoutID: String?
        var lastAppliedLayoutID: String?
        var mouseDownPoint: CGPoint?
        var overlayActivationPoint: CGPoint?
        var resolvedSlots: [ResolvedTriggerSlot] = []
        var suppressedMouseUpButton: TriggerButton?
        var targetWindow: ManagedWindow?
    }

    private let layoutEngine: LayoutEngine
    private let windowController: WindowController
    private let overlayController: OverlayController
    private let configurationProvider: () -> AppConfiguration
    private let accessibilityTrustedProvider: () -> Bool
    private let onAccessibilityRevoked: () -> Void

    private var state = State()
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var pendingAccessibilityRevocation = false

    var isEnabled = true

    init(
        layoutEngine: LayoutEngine,
        windowController: WindowController,
        overlayController: OverlayController,
        configurationProvider: @escaping () -> AppConfiguration,
        accessibilityTrustedProvider: @escaping () -> Bool,
        onAccessibilityRevoked: @escaping () -> Void
    ) {
        self.layoutEngine = layoutEngine
        self.windowController = windowController
        self.overlayController = overlayController
        self.configurationProvider = configurationProvider
        self.accessibilityTrustedProvider = accessibilityTrustedProvider
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
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)
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

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
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
        case .otherMouseDown:
            return handleOtherMouseDown(event: event, configuration: configuration)
        case .otherMouseDragged:
            return handleMouseDragged(event: event, expectedButton: .middle, configuration: configuration)
        case .otherMouseUp:
            return handleOtherMouseUp(event: event)
        case .keyDown:
            return handleKeyDown(event: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleLeftMouseDown(event: CGEvent, configuration: AppConfiguration) -> Unmanaged<CGEvent>? {
        guard isEnabled, configuration.dragTriggers.enableModifierLeftMouseDrag else {
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

    private func handleOtherMouseDown(event: CGEvent, configuration: AppConfiguration) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        guard
            isEnabled,
            configuration.dragTriggers.enableMiddleMouseDrag,
            buttonNumber == Int64(configuration.dragTriggers.middleMouseButtonNumber)
        else {
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

    private func handleMouseDragged(
        event: CGEvent,
        expectedButton: TriggerButton,
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

    private func handleMouseUp(event: CGEvent, button: TriggerButton) -> Unmanaged<CGEvent>? {
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

    private func handleOtherMouseUp(event: CGEvent) -> Unmanaged<CGEvent>? {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        guard buttonNumber == Int64(TriggerButton.middle.rawValue) else {
            return Unmanaged.passUnretained(event)
        }

        return handleMouseUp(event: event, button: .middle)
    }

    private func handleKeyDown(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Escape) else {
            return Unmanaged.passUnretained(event)
        }

        guard state.active || state.activationTimer != nil else {
            return Unmanaged.passUnretained(event)
        }

        cancelAndSuppressActiveMouseUp()
        return nil
    }

    private func enterDragMode(
        button: TriggerButton,
        targetWindow: ManagedWindow,
        point: CGPoint,
        configuration: AppConfiguration
    ) {
        windowController.focus(targetWindow)
        state.active = true
        state.activeButton = button
        state.targetWindow = targetWindow
        state.overlayActivationPoint = point
        state.hasDraggedPastThreshold = false
        state.hoveredLayoutID = nil
        state.lastAppliedLayoutID = nil

        let fallbackScreen = windowController.screenContaining(point: CGPoint(x: targetWindow.frame.midX, y: targetWindow.frame.midY))
        state.activeScreen = windowController.resolvedScreen(for: point, fallback: fallbackScreen)
        state.resolvedSlots = state.activeScreen.map { layoutEngine.resolveTriggerSlots(on: $0, configuration: configuration) } ?? []
        refreshOverlay(configuration: configuration)
    }

    private func updateDrag(at point: CGPoint, configuration: AppConfiguration) {
        guard let targetWindow = state.targetWindow else {
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

        let hoveredSlot = layoutEngine.triggerSlot(containing: point, slots: state.resolvedSlots)
        state.hoveredLayoutID = hoveredSlot?.layoutID
        if let hoveredSlot, hoveredSlot.layoutID != state.lastAppliedLayoutID {
            windowController.applyLayout(
                layoutID: hoveredSlot.layoutID,
                to: targetWindow,
                preferredScreen: state.activeScreen,
                configuration: configuration
            )
            state.lastAppliedLayoutID = hoveredSlot.layoutID
        }
        refreshOverlay(configuration: configuration)
    }

    private func refreshOverlay(configuration: AppConfiguration) {
        guard let screen = state.activeScreen else {
            overlayController.dismiss()
            return
        }

        let highlightFrame: CGRect?
        if !state.hasDraggedPastThreshold {
            highlightFrame = state.targetWindow?.frame
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

    private func cancelAndSuppressActiveMouseUp() {
        if let activeButton = state.activeButton {
            state.suppressedMouseUpButton = activeButton
        }
        resetState(keepSuppressedMouseUp: true)
    }

    private func resetState(keepSuppressedMouseUp: Bool = false) {
        state.activationTimer?.cancel()
        let suppressedMouseUpButton = keepSuppressedMouseUp ? state.suppressedMouseUpButton : nil
        state = State()
        state.suppressedMouseUpButton = suppressedMouseUpButton
        overlayController.dismiss()
    }

    private func postSyntheticMiddleMouseDown(at point: CGPoint) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }

        guard let syntheticEvent = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: point, mouseButton: .center) else {
            return
        }

        SyntheticEventMarker.markMiddleMouseReplay(syntheticEvent)
        syntheticEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(TriggerButton.middle.rawValue))
        syntheticEvent.post(tap: .cghidEventTap)
    }

    private func postSyntheticMiddleMouseClick(downAt downPoint: CGPoint, upAt upPoint: CGPoint) {
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
        downEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(TriggerButton.middle.rawValue))
        upEvent.setIntegerValueField(.mouseEventButtonNumber, value: Int64(TriggerButton.middle.rawValue))
        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
    }

    private func normalizedModifiers(from flags: CGEventFlags) -> Set<ModifierKey> {
        var result: Set<ModifierKey> = []
        if flags.contains(.maskControl) { result.insert(.ctrl) }
        if flags.contains(.maskCommand) { result.insert(.cmd) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskAlternate) { result.insert(.alt) }
        return result
    }

    private func appKitPoint(from event: CGEvent) -> CGPoint {
        event.unflippedLocation
    }

    private func matchesAnyModifierGroup(flags: Set<ModifierKey>, groups: [[ModifierKey]]) -> Bool {
        groups.contains { Set($0) == flags }
    }

    private func ensureAccessibilityIsStillGranted() -> Bool {
        guard accessibilityTrustedProvider() else {
            resetState()
            stop()
            scheduleAccessibilityRevocationHandling()
            return false
        }
        return true
    }

    private func scheduleAccessibilityRevocationHandling() {
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
