import AppKit
import ApplicationServices
import Foundation

@MainActor
final class WindowFrameApplier {
    private let layoutEngine: LayoutEngine
    private let mainDisplayHeightProvider: () -> CGFloat
    private let screenContainingProvider: (CGPoint) -> NSScreen?
    private let logger = AppLogger.shared

    init(
        layoutEngine: LayoutEngine,
        mainDisplayHeightProvider: @escaping () -> CGFloat,
        screenContainingProvider: @escaping (CGPoint) -> NSScreen?
    ) {
        self.layoutEngine = layoutEngine
        self.mainDisplayHeightProvider = mainDisplayHeightProvider
        self.screenContainingProvider = screenContainingProvider
    }

    func applyLayout(
        layoutID: String,
        to window: ManagedWindow,
        preferredScreen: NSScreen?,
        configuration: AppConfiguration
    ) {
        guard
            let preset = layoutEngine.layoutPreset(for: layoutID, in: configuration.layouts),
            let targetScreen = preferredScreen ?? screenContainingProvider(CGPoint(x: window.frame.midX, y: window.frame.midY))
        else {
            return
        }

        let currentScreen = screenContainingProvider(CGPoint(x: window.frame.midX, y: window.frame.midY))
        let crossesScreenBoundary = currentScreen.map(Geometry.screenIdentifier(for:)) != Geometry.screenIdentifier(for: targetScreen)
        let targetFrame = layoutEngine.frame(for: preset, on: targetScreen)
        let applyFrame = { [weak self] in
            guard let self else {
                return
            }

            if self.setFrame(targetFrame, for: window, targetScreen: targetScreen, crossesScreenBoundary: crossesScreenBoundary) {
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
            guard primeWindowOnTargetScreen(targetScreen, for: window) else {
                return false
            }
            let firstPassSucceeded = applyFrameValues(positionValue: positionValue, sizeValue: sizeValue, to: window.element)
            scheduleCrossScreenSettle(positionValue: positionValue, sizeValue: sizeValue, for: window.element)
            return firstPassSucceeded
        }

        return applyFrameValues(positionValue: positionValue, sizeValue: sizeValue, to: window.element)
    }

    private func applyFrameValues(positionValue: AXValue, sizeValue: AXValue, to element: AXUIElement) -> Bool {
        let positionResult = applyPositionValue(positionValue, to: element)
        let sizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        return positionResult && sizeResult == .success
    }

    private func scheduleCrossScreenSettle(positionValue: AXValue, sizeValue: AXValue, for element: AXUIElement) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self else {
                return
            }

            _ = self.applyFrameValues(positionValue: positionValue, sizeValue: sizeValue, to: element)
        }
    }

    private func primeWindowOnTargetScreen(_ screen: NSScreen, for window: ManagedWindow) -> Bool {
        let handoffFrame = handoffFrame(for: window, on: screen)
        let quartzFrame = Geometry.quartzRect(fromAppKitRect: handoffFrame, mainDisplayHeight: mainDisplayHeight)
        var point = CGPoint(x: quartzFrame.origin.x, y: quartzFrame.origin.y)
        guard let positionValue = AXValueCreate(.cgPoint, &point) else {
            return false
        }

        return applyPositionValue(positionValue, to: window.element)
    }

    private func handoffFrame(for window: ManagedWindow, on screen: NSScreen) -> CGRect {
        let visibleFrame = screen.visibleFrame.insetBy(dx: 24, dy: 24)
        let width = min(window.frame.width, visibleFrame.width)
        let height = min(window.frame.height, visibleFrame.height)
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
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue) == .success
    }

    private func copyAttribute<T>(_ attribute: CFString, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success, let value else {
            return nil
        }
        return value as? T
    }
}
