import AppKit
import ApplicationServices
import Foundation

@MainActor
final class WindowFrameApplier {
    struct TestHooks {
        var currentFrameProvider: ((ManagedWindow) -> CGRect?)?
        var applyPositionValue: ((AXValue, AXUIElement) -> Bool)?
        var applyFrameValues: ((AXValue, AXValue, AXUIElement) -> Bool)?
        var scheduleCrossScreenSettle: ((DispatchWorkItem) -> Void)?
    }

    private let layoutEngine: LayoutEngine
    private let mainDisplayHeightProvider: () -> CGFloat
    private let screenContainingProvider: (CGPoint) -> NSScreen?
    private let testHooks: TestHooks?
    private let logger = AppLogger.shared
    // Cross-screen apply can leave delayed settle work behind. Track the latest request per
    // window so older settle work cannot override a newer layout choice.
    private var latestLayoutRequestIDs: [String: UUID] = [:]
    private var pendingCrossScreenSettleWorkItems: [String: DispatchWorkItem] = [:]

    init(
        layoutEngine: LayoutEngine,
        mainDisplayHeightProvider: @escaping () -> CGFloat,
        screenContainingProvider: @escaping (CGPoint) -> NSScreen?,
        testHooks: TestHooks? = nil
    ) {
        self.layoutEngine = layoutEngine
        self.mainDisplayHeightProvider = mainDisplayHeightProvider
        self.screenContainingProvider = screenContainingProvider
        self.testHooks = testHooks
    }

    func applyLayout(
        layoutID: String,
        to window: ManagedWindow,
        preferredScreen: NSScreen?,
        configuration: AppConfiguration
    ) {
        let requestID = registerLayoutRequest(for: window.identity)
        let currentFrame = currentFrame(for: window) ?? window.frame
        guard
            let preset = layoutEngine.layoutPreset(for: layoutID, in: configuration.layouts),
            let targetScreen = preferredScreen ?? screenContainingProvider(CGPoint(x: currentFrame.midX, y: currentFrame.midY))
        else {
            return
        }

        let currentScreen = screenContainingProvider(CGPoint(x: currentFrame.midX, y: currentFrame.midY))
        let crossesScreenBoundary = currentScreen.map(Geometry.screenIdentifier(for:)) != Geometry.screenIdentifier(for: targetScreen)
        let targetFrame = layoutEngine.frame(for: preset, on: targetScreen)
        let applyFrame = { [weak self] in
            guard let self else {
                return
            }

            guard self.isLatestLayoutRequest(requestID, for: window.identity) else {
                return
            }

            if self.setFrame(
                targetFrame,
                for: window,
                requestID: requestID,
                currentFrame: currentFrame,
                targetScreen: targetScreen,
                crossesScreenBoundary: crossesScreenBoundary
            ) {
                self.layoutEngine.recordLayoutID(layoutID, for: window.identity)
            }
        }

        if isFullscreen(window) {
            guard exitFullscreen(window) else {
                logger.error("Failed to exit fullscreen before applying layout.")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                applyFrame()
            }
            return
        }

        applyFrame()
    }

    func moveWindow(to origin: CGPoint, currentFrame: CGRect, for window: ManagedWindow) -> Bool {
        let nextFrame = CGRect(origin: origin, size: currentFrame.size)
        let quartzFrame = Geometry.quartzRect(fromAppKitRect: nextFrame, mainDisplayHeight: mainDisplayHeight)
        var point = CGPoint(x: quartzFrame.origin.x, y: quartzFrame.origin.y)
        guard let positionValue = AXValueCreate(.cgPoint, &point) else {
            return false
        }

        return applyPositionValue(positionValue, to: window.element)
    }

    private var mainDisplayHeight: CGFloat {
        mainDisplayHeightProvider()
    }

    private func isFullscreen(_ window: ManagedWindow) -> Bool {
        (copyAttribute("AXFullScreen" as CFString, from: window.element) as Bool?) == true
    }

    private func exitFullscreen(_ window: ManagedWindow) -> Bool {
        setBooleanAttribute("AXFullScreen" as CFString, value: false, on: window.element)
    }

    private func setFrame(
        _ frame: CGRect,
        for window: ManagedWindow,
        requestID: UUID,
        currentFrame: CGRect,
        targetScreen: NSScreen,
        crossesScreenBoundary: Bool
    ) -> Bool {
        let quartzFrame = Geometry.quartzRect(fromAppKitRect: frame, mainDisplayHeight: mainDisplayHeight)
        var point = CGPoint(x: quartzFrame.origin.x, y: quartzFrame.origin.y)
        var size = CGSize(width: quartzFrame.size.width, height: quartzFrame.size.height)
        let positionValue = AXValueCreate(.cgPoint, &point)
        let sizeValue = AXValueCreate(.cgSize, &size)

        guard
            let positionValue,
            let sizeValue
        else {
            return false
        }

        if crossesScreenBoundary {
            guard primeWindowOnTargetScreen(targetScreen, currentFrame: currentFrame, for: window) else {
                return false
            }
            let firstPassSucceeded = applyFrameValues(positionValue: positionValue, sizeValue: sizeValue, to: window.element)
            scheduleCrossScreenSettle(
                positionValue: positionValue,
                sizeValue: sizeValue,
                for: window,
                requestID: requestID
            )
            return firstPassSucceeded
        }

        return applyFrameValues(positionValue: positionValue, sizeValue: sizeValue, to: window.element)
    }

    private func applyFrameValues(positionValue: AXValue, sizeValue: AXValue, to element: AXUIElement) -> Bool {
        if let applyFrameValues = testHooks?.applyFrameValues {
            return applyFrameValues(positionValue, sizeValue, element)
        }

        let positionResult = applyPositionValue(positionValue, to: element)
        let sizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        return positionResult && sizeResult == .success
    }

    private func scheduleCrossScreenSettle(
        positionValue: AXValue,
        sizeValue: AXValue,
        for window: ManagedWindow,
        requestID: UUID
    ) {
        pendingCrossScreenSettleWorkItems[window.identity]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            defer {
                if self.isLatestLayoutRequest(requestID, for: window.identity) {
                    self.pendingCrossScreenSettleWorkItems[window.identity] = nil
                }
            }

            guard self.isLatestLayoutRequest(requestID, for: window.identity) else {
                return
            }

            _ = self.applyFrameValues(positionValue: positionValue, sizeValue: sizeValue, to: window.element)
        }
        pendingCrossScreenSettleWorkItems[window.identity] = workItem
        if let scheduleCrossScreenSettle = testHooks?.scheduleCrossScreenSettle {
            scheduleCrossScreenSettle(workItem)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: workItem)
        }
    }

    private func primeWindowOnTargetScreen(_ screen: NSScreen, currentFrame: CGRect, for window: ManagedWindow) -> Bool {
        let handoffFrame = handoffFrame(for: currentFrame, on: screen)
        let quartzFrame = Geometry.quartzRect(fromAppKitRect: handoffFrame, mainDisplayHeight: mainDisplayHeight)
        var point = CGPoint(x: quartzFrame.origin.x, y: quartzFrame.origin.y)
        guard let positionValue = AXValueCreate(.cgPoint, &point) else {
            return false
        }

        return applyPositionValue(positionValue, to: window.element)
    }

    private func handoffFrame(for currentFrame: CGRect, on screen: NSScreen) -> CGRect {
        let visibleFrame = screen.visibleFrame.insetBy(dx: 24, dy: 24)
        let width = min(currentFrame.width, visibleFrame.width)
        let height = min(currentFrame.height, visibleFrame.height)
        return CGRect(
            x: visibleFrame.minX,
            y: visibleFrame.maxY - height,
            width: width,
            height: height
        ).integral
    }

    private func setBooleanAttribute(_ attribute: CFString, value: Bool, on element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, attribute, value as CFBoolean) == .success
    }

    private func applyPositionValue(_ positionValue: AXValue, to element: AXUIElement) -> Bool {
        if let applyPositionValue = testHooks?.applyPositionValue {
            return applyPositionValue(positionValue, element)
        }

        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue) == .success
    }

    private func copyAttribute<T>(_ attribute: CFString, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success, let value else {
            return nil
        }
        return value as? T
    }

    private func currentFrame(for window: ManagedWindow) -> CGRect? {
        if let currentFrameProvider = testHooks?.currentFrameProvider {
            return currentFrameProvider(window)
        }

        guard
            let positionValue: AXValue = copyAttribute(kAXPositionAttribute as CFString, from: window.element),
            let sizeValue: AXValue = copyAttribute(kAXSizeAttribute as CFString, from: window.element)
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue, .cgPoint, &point),
            AXValueGetValue(sizeValue, .cgSize, &size)
        else {
            return nil
        }

        let quartzFrame = CGRect(origin: point, size: size)
        return Geometry.appKitRect(fromQuartzRect: quartzFrame, mainDisplayHeight: mainDisplayHeight)
    }

    private func registerLayoutRequest(for windowIdentity: String) -> UUID {
        pendingCrossScreenSettleWorkItems[windowIdentity]?.cancel()
        pendingCrossScreenSettleWorkItems[windowIdentity] = nil

        let requestID = UUID()
        latestLayoutRequestIDs[windowIdentity] = requestID
        return requestID
    }

    private func isLatestLayoutRequest(_ requestID: UUID, for windowIdentity: String) -> Bool {
        latestLayoutRequestIDs[windowIdentity] == requestID
    }

}
