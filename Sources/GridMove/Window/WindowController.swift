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
    private lazy var queryService = WindowQueryService(
        mainDisplayHeightProvider: { [weak self] in self?.mainDisplayHeight ?? 0 }
    )
    private lazy var frameApplier = WindowFrameApplier(
        layoutEngine: layoutEngine,
        mainDisplayHeightProvider: { [weak self] in self?.mainDisplayHeight ?? 0 },
        screenContainingProvider: { [weak self] point in self?.screenContaining(point: point) }
    )

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
        queryService.focusedWindow(configuration: configuration)
    }

    func windowForLayoutAction(configuration: AppConfiguration) -> ManagedWindow? {
        focusedWindow(configuration: configuration)
    }

    func window(cgWindowID: CGWindowID, configuration: AppConfiguration) -> ManagedWindow? {
        queryService.window(cgWindowID: cgWindowID, configuration: configuration)
    }

    func windowUnderCursor(at point: CGPoint, configuration: AppConfiguration) -> ManagedWindow? {
        queryService.windowUnderCursor(at: point, configuration: configuration)
    }

    func currentFrame(for window: ManagedWindow) -> CGRect? {
        queryService.currentFrame(for: window)
    }

    func focus(_ window: ManagedWindow) {
        queryService.focus(window)
    }

    func applyLayout(
        layoutID: String,
        to window: ManagedWindow,
        preferredScreen: NSScreen?,
        configuration: AppConfiguration
    ) {
        frameApplier.applyLayout(
            layoutID: layoutID,
            to: window,
            preferredScreen: preferredScreen,
            configuration: configuration
        )
    }

    func moveWindow(to origin: CGPoint, currentFrame: CGRect, for window: ManagedWindow) -> Bool {
        frameApplier.moveWindow(to: origin, currentFrame: currentFrame, for: window)
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
            Geometry.cgDisplayID(for: $0) == mainDisplayID
        }) {
            return mainScreen.frame.height
        }

        return NSScreen.main?.frame.height ?? 0
    }
}
