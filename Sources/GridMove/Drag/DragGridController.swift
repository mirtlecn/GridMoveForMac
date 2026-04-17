@preconcurrency import AppKit
import Carbon.HIToolbox
import Foundation

enum DragInteractionMode: Equatable {
    case layoutSelection
    case moveOnly
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
        var interactionMode: DragInteractionMode = .layoutSelection
        var activeScreen: NSScreen?
        var hasDraggedPastThreshold = false
        var hoveredLayoutID: String?
        var lastAppliedLayoutID: String?
        var mouseDownPoint: CGPoint?
        var overlayActivationPoint: CGPoint?
        var resolvedSlots: [ResolvedTriggerSlot] = []
        var suppressedMouseUpButton: TriggerButton?
        var targetWindow: ManagedWindow?
        var currentWindowFrame: CGRect?
        var moveAnchor: MoveAnchor?
        var optionToggleTracker: OptionToggleTracker?
        var pendingRightClickToggle = false
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
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.rightMouseUp.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
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

    static func preferredInteractionMode(preferLayoutMode: Bool) -> DragInteractionMode {
        preferLayoutMode ? .layoutSelection : .moveOnly
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
        case .rightMouseDown:
            return handleRightMouseDown(event: event)
        case .rightMouseDragged:
            return handleRightMouseDragged(event: event)
        case .rightMouseUp:
            return handleRightMouseUp(event: event, configuration: configuration)
        case .otherMouseDown:
            return handleOtherMouseDown(event: event, configuration: configuration)
        case .otherMouseDragged:
            return handleMouseDragged(event: event, expectedButton: .middle, configuration: configuration)
        case .otherMouseUp:
            return handleOtherMouseUp(event: event)
        case .flagsChanged:
            return handleFlagsChanged(event: event, configuration: configuration)
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

    private func handleRightMouseDown(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard state.active else {
            return Unmanaged.passUnretained(event)
        }

        state.pendingRightClickToggle = true
        return nil
    }

    private func handleRightMouseDragged(event: CGEvent) -> Unmanaged<CGEvent>? {
        guard state.active || state.pendingRightClickToggle else {
            return Unmanaged.passUnretained(event)
        }

        return nil
    }

    private func handleRightMouseUp(event: CGEvent, configuration: AppConfiguration) -> Unmanaged<CGEvent>? {
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

    private func handleFlagsChanged(event: CGEvent, configuration: AppConfiguration) -> Unmanaged<CGEvent>? {
        guard state.active, var tracker = state.optionToggleTracker else {
            return Unmanaged.passUnretained(event)
        }

        let isOptionPressed = event.flags.contains(.maskAlternate)
        let result = tracker.register(isPressed: isOptionPressed)
        state.optionToggleTracker = tracker

        switch result {
        case .ignore:
            return Unmanaged.passUnretained(event)
        case .consume:
            return nil
        case .toggle:
            toggleInteractionMode(at: appKitPoint(from: event), configuration: configuration)
            return nil
        }
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

    private func updateDrag(at point: CGPoint, configuration: AppConfiguration) {
        switch state.interactionMode {
        case .layoutSelection:
            updateLayoutSelectionDrag(at: point, configuration: configuration)
        case .moveOnly:
            updateMoveOnlyDrag(at: point)
        }
    }

    private func updateLayoutSelectionDrag(at point: CGPoint, configuration: AppConfiguration) {
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

    private func updateMoveOnlyDrag(at point: CGPoint) {
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

    private func toggleInteractionMode(at point: CGPoint, configuration: AppConfiguration) {
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

    private func configureLayoutSelectionMode(
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

    private func configureMoveOnlyMode(at point: CGPoint) {
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

    private func applyLayoutSelection(at point: CGPoint, configuration: AppConfiguration) {
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

    private func refreshOverlay(configuration: AppConfiguration) {
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

    private func currentWindowFrame() -> CGRect? {
        state.currentWindowFrame ?? state.targetWindow?.frame
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

    private var isOptionPressed: Bool {
        NSEvent.modifierFlags.contains(.option)
    }

    private func pointsApproximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, tolerance: CGFloat = 0.5) -> Bool {
        abs(lhs.x - rhs.x) < tolerance && abs(lhs.y - rhs.y) < tolerance
    }

    static func matchesAnyModifierGroup(flags: Set<ModifierKey>, groups: [[ModifierKey]]) -> Bool {
        groups.contains { !$0.isEmpty && Set($0) == flags }
    }

    private func matchesAnyModifierGroup(flags: Set<ModifierKey>, groups: [[ModifierKey]]) -> Bool {
        Self.matchesAnyModifierGroup(flags: flags, groups: groups)
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
