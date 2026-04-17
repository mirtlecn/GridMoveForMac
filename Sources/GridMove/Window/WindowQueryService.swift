import AppKit
import ApplicationServices
import Foundation

@MainActor
final class WindowQueryService {
    private let mainDisplayHeightProvider: () -> CGFloat
    private let builtInExcludedBundleIDs = Set(AppConfiguration.builtInExcludedBundleIDs)
    private let builtInExcludedTitles = Set(AppConfiguration.builtInExcludedWindowTitles)

    init(mainDisplayHeightProvider: @escaping () -> CGFloat) {
        self.mainDisplayHeightProvider = mainDisplayHeightProvider
    }

    func focusedWindow(configuration: AppConfiguration) -> ManagedWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        let frontmostApplication = NSWorkspace.shared.frontmostApplication

        if let focusedApplication: AXUIElement = copyAttribute(kAXFocusedApplicationAttribute as CFString, from: systemWide),
           let window = focusedWindow(from: focusedApplication, configuration: configuration) {
            return window
        }

        if let frontmostApplication {
            let frontmostElement = AXUIElementCreateApplication(frontmostApplication.processIdentifier)
            if let window = focusedWindow(from: frontmostElement, configuration: configuration) {
                return window
            }
        }

        return nil
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
        let quartzPoint = Geometry.quartzPoint(fromAppKitPoint: point, mainDisplayHeight: mainDisplayHeight)
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

    private var mainDisplayHeight: CGFloat {
        mainDisplayHeightProvider()
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

    private func focusedWindow(from application: AXUIElement, configuration: AppConfiguration) -> ManagedWindow? {
        guard let focusedWindowElement: AXUIElement = copyAttribute(kAXFocusedWindowAttribute as CFString, from: application) else {
            return nil
        }

        guard let window = managedWindow(from: focusedWindowElement, cgWindowID: nil) else {
            return nil
        }

        if isWindowExcluded(window, configuration: configuration) {
            return nil
        }

        return window
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
