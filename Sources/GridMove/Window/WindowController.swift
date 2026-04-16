import AppKit
import ApplicationServices
import Foundation

struct ManagedWindow {
    let element: AXUIElement
    let pid: pid_t
    let bundleIdentifier: String?
    let appName: String?
    let title: String
    let role: String
    let subrole: String
    let frame: CGRect
    let identity: String
    let cgWindowID: CGWindowID?

    var isStandardWindow: Bool {
        subrole == kAXStandardWindowSubrole as String
    }
}

@MainActor
final class WindowController {
    private let layoutEngine: LayoutEngine
    private let logger = AppLogger.shared

    private let builtInExcludedBundleIDs: Set<String> = [
        AppConfiguration.builtInExcludedBundleIDs[0],
        AppConfiguration.builtInExcludedBundleIDs[1],
        AppConfiguration.builtInExcludedBundleIDs[2],
    ]

    private let builtInExcludedTitles: Set<String> = [
        AppConfiguration.builtInExcludedWindowTitles[0],
        AppConfiguration.builtInExcludedWindowTitles[1],
        AppConfiguration.builtInExcludedWindowTitles[2],
        AppConfiguration.builtInExcludedWindowTitles[3],
    ]

    init(layoutEngine: LayoutEngine) {
        self.layoutEngine = layoutEngine
    }

    func appKitPoint(fromQuartzPoint point: CGPoint) -> CGPoint {
        Geometry.appKitPoint(fromQuartzPoint: point, mainDisplayHeight: mainDisplayHeight)
    }

    func quartzPoint(fromAppKitPoint point: CGPoint) -> CGPoint {
        Geometry.quartzPoint(fromAppKitPoint: point, mainDisplayHeight: mainDisplayHeight)
    }

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func focusedWindow(configuration: AppConfiguration) -> ManagedWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        guard
            let focusedApplication: AXUIElement = copyAttribute(kAXFocusedApplicationAttribute as CFString, from: systemWide),
            let focusedWindow: AXUIElement = copyAttribute(kAXFocusedWindowAttribute as CFString, from: focusedApplication),
            let window = managedWindow(from: focusedWindow, cgWindowID: nil),
            !isWindowExcluded(window, configuration: configuration)
        else {
            AppLogger.debugTargeting("focusedWindow -> none")
            return nil
        }
        AppLogger.debugTargeting("focusedWindow -> \(window.debugDescription)")
        return window
    }

    func windowForLayoutAction(configuration: AppConfiguration) -> ManagedWindow? {
        if let focusedWindow = focusedWindow(configuration: configuration) {
            AppLogger.debugTargeting("windowForLayoutAction -> focused \(focusedWindow.debugDescription)")
            return focusedWindow
        }

        let mouseLocation = NSEvent.mouseLocation
        guard let window = windowUnderCursor(at: mouseLocation, configuration: configuration) else {
            AppLogger.debugTargeting("windowForLayoutAction -> none under cursor at \(mouseLocation.debugDescription)")
            return nil
        }

        focus(window)
        AppLogger.debugTargeting("windowForLayoutAction -> cursor \(window.debugDescription)")
        return window
    }

    func window(cgWindowID: CGWindowID, configuration: AppConfiguration) -> ManagedWindow? {
        let windowInfos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        guard let matchedWindowInfo = windowInfos.first(where: {
            ($0[kCGWindowNumber as String] as? CGWindowID) == cgWindowID
        }) else {
            AppLogger.debugTargeting("window(cgWindowID: \(cgWindowID)) -> no matching CG window info")
            return nil
        }

        guard let managedWindow = resolveWindow(from: matchedWindowInfo, point: nil) else {
            AppLogger.debugTargeting("window(cgWindowID: \(cgWindowID)) -> failed to resolve AX window")
            return nil
        }

        guard !isWindowExcluded(managedWindow, configuration: configuration) else {
            AppLogger.debugTargeting("window(cgWindowID: \(cgWindowID)) -> excluded \(managedWindow.debugDescription)")
            return nil
        }

        focus(managedWindow)
        AppLogger.debugTargeting("window(cgWindowID: \(cgWindowID)) -> \(managedWindow.debugDescription)")
        return managedWindow
    }

    func windowUnderCursor(at point: CGPoint, configuration: AppConfiguration) -> ManagedWindow? {
        let quartzPoint = quartzPoint(fromAppKitPoint: point)
        let windowInfos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var fallbackCandidate: ManagedWindow?

        for windowInfo in windowInfos {
            guard
                let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                Geometry.point(quartzPoint, inside: bounds)
            else {
                continue
            }

            guard let candidate = resolveWindow(from: windowInfo, point: point) else {
                continue
            }

            if isWindowExcluded(candidate, configuration: configuration) {
                continue
            }

            if candidate.isStandardWindow {
                return candidate
            }

            if fallbackCandidate == nil {
                fallbackCandidate = candidate
            }
        }

        if let fallbackCandidate {
            return fallbackCandidate
        }

        guard
            let hitElement = elementAtPoint(quartzPoint),
            let hitWindow = resolveWindowByTraversal(from: hitElement),
            !isWindowExcluded(hitWindow, configuration: configuration)
        else {
            return nil
        }

        return hitWindow
    }

    func focus(_ window: ManagedWindow) {
        AppLogger.debugTargeting("focus -> \(window.debugDescription)")
        if let runningApplication = NSRunningApplication(processIdentifier: window.pid) {
            runningApplication.activate()
        }

        _ = setBooleanAttribute(kAXMainAttribute as CFString, value: true, on: window.element)
        _ = setBooleanAttribute(kAXFocusedAttribute as CFString, value: true, on: window.element)
    }

    func applyLayout(
        layoutID: String,
        to window: ManagedWindow,
        preferredScreen: NSScreen?,
        configuration: AppConfiguration
    ) {
        guard
            let preset = layoutEngine.layoutPreset(for: layoutID, in: configuration),
            let targetScreen = preferredScreen ?? screenContaining(point: CGPoint(x: window.frame.midX, y: window.frame.midY))
        else {
            return
        }

        let currentScreen = screenContaining(point: CGPoint(x: window.frame.midX, y: window.frame.midY))
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

    func screenContaining(point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    func resolvedScreen(for point: CGPoint, fallback: NSScreen?) -> NSScreen? {
        screenContaining(point: point) ?? fallback
    }

    private var mainDisplayHeight: CGFloat {
        let mainDisplayID = CGMainDisplayID()
        if let mainScreen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == mainDisplayID
        }) {
            return mainScreen.frame.height
        }

        return NSScreen.main?.frame.height ?? 0
    }

    private func isWindowExcluded(_ window: ManagedWindow, configuration: AppConfiguration) -> Bool {
        if isDesktopWindow(window) {
            return true
        }

        if let bundleIdentifier = window.bundleIdentifier,
           builtInExcludedBundleIDs.contains(bundleIdentifier) || configuration.general.excludedBundleIDs.contains(bundleIdentifier) {
            return true
        }

        if builtInExcludedTitles.contains(window.title) || configuration.general.excludedWindowTitles.contains(window.title) {
            return true
        }

        if let appName = window.appName, ["Dock", "Notification Center"].contains(appName) {
            return true
        }

        return !isOperable(window)
    }

    private func isDesktopWindow(_ window: ManagedWindow) -> Bool {
        window.bundleIdentifier == "com.apple.finder" && window.title.isEmpty
    }

    private func isOperable(_ window: ManagedWindow) -> Bool {
        isAttributeSettable(kAXPositionAttribute as CFString, on: window.element)
            && isAttributeSettable(kAXSizeAttribute as CFString, on: window.element)
    }

    private func elementAtPoint(_ point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var result: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &result)
        guard error == .success else {
            return nil
        }
        return result
    }

    private func resolveWindow(from windowInfo: [String: Any], point: CGPoint?) -> ManagedWindow? {
        guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
            return nil
        }

        let cgWindowID = windowInfo[kCGWindowNumber as String] as? CGWindowID
        let title = windowInfo[kCGWindowName as String] as? String
        let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary
        let bounds = boundsDictionary
            .flatMap { CGRect(dictionaryRepresentation: $0) }
            .map { Geometry.appKitRect(fromQuartzRect: $0, mainDisplayHeight: mainDisplayHeight) }

        let appElement = AXUIElementCreateApplication(pid)
        guard let axWindows: [AXUIElement] = copyAttribute(kAXWindowsAttribute as CFString, from: appElement) else {
            return nil
        }

        var bestMatch: (window: ManagedWindow, score: Int)?
        for axWindow in axWindows {
            guard let managedWindow = managedWindow(from: axWindow, cgWindowID: cgWindowID) else {
                continue
            }

            let score = matchScore(
                managedWindow,
                expectedTitle: title,
                expectedBounds: bounds,
                point: point
            )

            guard score > 0 else {
                continue
            }

            if bestMatch == nil || score > bestMatch?.score ?? 0 {
                bestMatch = (managedWindow, score)
            }
        }

        return bestMatch?.window
    }

    private func resolveWindowByTraversal(from element: AXUIElement) -> ManagedWindow? {
        if let windowElement: AXUIElement = copyAttribute(kAXWindowAttribute as CFString, from: element),
           let window = managedWindow(from: windowElement, cgWindowID: nil) {
            return window
        }

        var currentElement: AXUIElement? = element
        while let unwrappedElement = currentElement {
            let role: String? = copyAttribute(kAXRoleAttribute as CFString, from: unwrappedElement)
            if role == kAXWindowRole as String {
                return managedWindow(from: unwrappedElement, cgWindowID: nil)
            }
            currentElement = copyAttribute(kAXParentAttribute as CFString, from: unwrappedElement)
        }

        return nil
    }

    private func matchScore(
        _ window: ManagedWindow,
        expectedTitle: String?,
        expectedBounds: CGRect?,
        point: CGPoint?
    ) -> Int {
        if let point {
            guard window.frame.contains(point) else {
                return 0
            }
        }

        var score = 1
        if let expectedTitle, !expectedTitle.isEmpty, expectedTitle == window.title {
            score += 3
        }
        if let expectedBounds {
            if Geometry.approximatelyEqual(expectedBounds, window.frame) {
                score += 3
            } else if expectedBounds.intersects(window.frame) {
                score += 1
            }
        }
        if window.isStandardWindow {
            score += 1
        }
        return score
    }

    private func managedWindow(from element: AXUIElement, cgWindowID: CGWindowID?) -> ManagedWindow? {
        var pid = pid_t()
        guard AXUIElementGetPid(element, &pid) == .success else {
            return nil
        }

        guard
            let frame = frame(of: element),
            let role: String = copyAttribute(kAXRoleAttribute as CFString, from: element)
        else {
            return nil
        }

        let subrole: String = copyAttribute(kAXSubroleAttribute as CFString, from: element) ?? ""
        let title: String = copyAttribute(kAXTitleAttribute as CFString, from: element) ?? ""
        let runningApplication = NSRunningApplication(processIdentifier: pid)
        let identity = "\(pid)-\(CFHash(element))"

        return ManagedWindow(
            element: element,
            pid: pid,
            bundleIdentifier: runningApplication?.bundleIdentifier,
            appName: runningApplication?.localizedName,
            title: title,
            role: role,
            subrole: subrole,
            frame: frame,
            identity: identity,
            cgWindowID: cgWindowID
        )
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
        let positionResult = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        let sizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        return positionResult == .success && sizeResult == .success
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

        let positionResult = AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, positionValue)
        return positionResult == .success
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

    private func isAttributeSettable(_ attribute: CFString, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return error == .success && settable.boolValue
    }

    private func setBooleanAttribute(_ attribute: CFString, value: Bool, on element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, attribute, value as CFBoolean) == .success
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue: AXValue = copyAttribute(kAXPositionAttribute as CFString, from: element),
            let sizeValue: AXValue = copyAttribute(kAXSizeAttribute as CFString, from: element)
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

    private func copyAttribute<T>(_ attribute: CFString, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success, let value else {
            return nil
        }
        return value as? T
    }
}

extension ManagedWindow {
    var debugDescription: String {
        let resolvedAppName = appName ?? "UnknownApp"
        let resolvedBundleID = bundleIdentifier ?? "UnknownBundle"
        let resolvedWindowID = cgWindowID.map(String.init) ?? "nil"
        let sanitizedTitle = title.isEmpty ? "<empty>" : title
        return "app=\(resolvedAppName) bundle=\(resolvedBundleID) title=\(sanitizedTitle) pid=\(pid) windowID=\(resolvedWindowID) identity=\(identity)"
    }
}

private extension CGPoint {
    var debugDescription: String {
        "(\(Int(x.rounded())), \(Int(y.rounded())))"
    }
}
