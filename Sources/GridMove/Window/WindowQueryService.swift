import AppKit
import ApplicationServices
import Foundation

@MainActor
final class WindowQueryService {
    struct TestHooks {
        var isFullscreenWindow: ((ManagedWindow) -> Bool)?
    }

    private let mainDisplayHeightProvider: () -> CGFloat
    private let builtInExcludedBundleIDs = Set(AppConfiguration.builtInExcludedBundleIDs)
    private let currentProcessIdentifier = getpid()
    private let testHooks: TestHooks?

    init(
        mainDisplayHeightProvider: @escaping () -> CGFloat,
        testHooks: TestHooks? = nil
    ) {
        self.mainDisplayHeightProvider = mainDisplayHeightProvider
        self.testHooks = testHooks
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

    func currentFrame(for window: ManagedWindow) -> CGRect? {
        frame(of: window.element)
    }

    func window(cgWindowID: CGWindowID, configuration: AppConfiguration) -> ManagedWindow? {
        let windowInfos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        guard let matchedWindowInfo = windowInfos.first(where: {
            ($0[kCGWindowNumber as String] as? CGWindowID) == cgWindowID
        }) else {
            return nil
        }

        guard let managedWindow = resolveWindow(from: matchedWindowInfo, point: nil) else {
            return nil
        }

        guard !isWindowExcluded(managedWindow, configuration: configuration) else {
            return nil
        }

        focus(managedWindow)
        return managedWindow
    }

    func windowUnderCursor(at point: CGPoint, configuration: AppConfiguration) -> ManagedWindow? {
        let quartzPoint = Geometry.quartzPoint(fromAppKitPoint: point, mainDisplayHeight: mainDisplayHeight)
        let windowInfos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        for windowInfo in windowInfos {
            guard
                let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                Geometry.point(quartzPoint, inside: bounds)
            else {
                continue
            }

            if exclusionReason(windowInfo: windowInfo) != nil {
                continue
            }

            guard let candidate = resolveWindow(from: windowInfo, point: point) else { continue }

            if exclusionReason(candidate, configuration: configuration) != nil {
                continue
            }

            return candidate
        }

        guard
            let hitElement = elementAtPoint(quartzPoint),
            let hitWindow = resolveWindowByTraversal(from: hitElement),
            exclusionReason(hitWindow, configuration: configuration) == nil
        else {
            return nil
        }

        return hitWindow
    }

    func focus(_ window: ManagedWindow) {
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
        exclusionReason(window, configuration: configuration) != nil
    }

    private func exclusionReason(_ window: ManagedWindow, configuration: AppConfiguration) -> String? {
        if isGridMoveOverlayWindow(window) {
            return "gridmove-overlay-window"
        }

        if isDesktopWindow(window) {
            return "desktop-window"
        }

        if let bundleIdentifier = window.bundleIdentifier {
            if builtInExcludedBundleIDs.contains(bundleIdentifier) {
                return "built-in-excluded-bundle-id=\(bundleIdentifier)"
            }
            if configuration.general.excludedBundleIDs.contains(bundleIdentifier) {
                return "user-excluded-bundle-id=\(bundleIdentifier)"
            }
        }

        if configuration.general.excludedWindowTitles.contains(window.title) {
            return "user-excluded-title=\(window.title)"
        }

        if let appName = window.appName, ["Dock", "Notification Center"].contains(appName) {
            return "excluded-app-name=\(appName)"
        }

        if isFullscreenWindow(window) {
            return "fullscreen-window"
        }

        let canSetPosition = isAttributeSettable(kAXPositionAttribute as CFString, on: window.element)
        let canSetSize = isAttributeSettable(kAXSizeAttribute as CFString, on: window.element)
        if shouldExcludeForOperability(canSetPosition: canSetPosition, canSetSize: canSetSize) {
            return "non-operable-window"
        }

        return nil
    }

    private func exclusionReason(windowInfo: [String: Any]) -> String? {
        guard isGridMoveOverlayWindowInfo(windowInfo) else {
            return nil
        }

        return "gridmove-overlay-cg-window"
    }

    private func isExcludedByIdentityRules(_ window: ManagedWindow, configuration: AppConfiguration) -> Bool {
        if isDesktopWindow(window) {
            return true
        }

        if let bundleIdentifier = window.bundleIdentifier,
           builtInExcludedBundleIDs.contains(bundleIdentifier) || configuration.general.excludedBundleIDs.contains(bundleIdentifier) {
            return true
        }

        if configuration.general.excludedWindowTitles.contains(window.title) {
            return true
        }

        if let appName = window.appName, ["Dock", "Notification Center"].contains(appName) {
            return true
        }

        return false
    }

    func isExcludedByIdentityRulesForTesting(_ window: ManagedWindow, configuration: AppConfiguration) -> Bool {
        isExcludedByIdentityRules(window, configuration: configuration)
    }

    func exclusionReasonForTesting(_ window: ManagedWindow, configuration: AppConfiguration) -> String? {
        exclusionReason(window, configuration: configuration)
    }

    func isFullscreenWindowForTesting(_ window: ManagedWindow) -> Bool {
        isFullscreenWindow(window)
    }

    func shouldExcludeForOperabilityForTesting(canSetPosition: Bool, canSetSize: Bool) -> Bool {
        shouldExcludeForOperability(canSetPosition: canSetPosition, canSetSize: canSetSize)
    }

    func isGridMoveOverlayWindowInfoForTesting(_ windowInfo: [String: Any]) -> Bool {
        isGridMoveOverlayWindowInfo(windowInfo)
    }

    func acceptsMatchForTesting(
        window: ManagedWindow,
        expectedTitle: String?,
        expectedBounds: CGRect?,
        point: CGPoint?
    ) -> Bool {
        let score = matchScore(window, expectedTitle: expectedTitle, expectedBounds: expectedBounds, point: point)
        return isReliableMatch(score: score)
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

    private func isFullscreenWindow(_ window: ManagedWindow) -> Bool {
        if let isFullscreenWindow = testHooks?.isFullscreenWindow {
            return isFullscreenWindow(window)
        }

        return (copyAttribute("AXFullScreen" as CFString, from: window.element) as Bool?) == true
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

            guard score > 0 else { continue }
            guard isReliableMatch(score: score) else { continue }
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

    private func isReliableMatch(score: Int) -> Bool {
        score >= 4
    }

    private func shouldExcludeForOperability(canSetPosition: Bool, canSetSize: Bool) -> Bool {
        !canSetPosition && !canSetSize
    }

    private func isGridMoveOverlayWindow(_ window: ManagedWindow) -> Bool {
        guard
            window.pid == currentProcessIdentifier,
            window.title.isEmpty,
            !window.isStandardWindow
        else {
            return false
        }

        return NSScreen.screens.contains { screen in
            Geometry.approximatelyEqual(screen.frame, window.frame, tolerance: 2)
        }
    }

    private func isGridMoveOverlayWindowInfo(_ windowInfo: [String: Any]) -> Bool {
        guard
            let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
            pid == currentProcessIdentifier,
            let layer = windowInfo[kCGWindowLayer as String] as? Int,
            layer > 0
        else {
            return false
        }

        let windowTitle = (windowInfo[kCGWindowName as String] as? String) ?? ""
        guard windowTitle.isEmpty else {
            return false
        }

        guard let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary) else {
            return false
        }

        return NSScreen.screens.contains { screen in
            let quartzScreenFrame = Geometry.quartzRect(fromAppKitRect: screen.frame, mainDisplayHeight: mainDisplayHeight)
            return Geometry.approximatelyEqual(quartzScreenFrame, bounds, tolerance: 2)
        }
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

    private func setBooleanAttribute(_ attribute: CFString, value: Bool, on element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, attribute, value as CFBoolean) == .success
    }

    private func isAttributeSettable(_ attribute: CFString, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return error == .success && settable.boolValue
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
