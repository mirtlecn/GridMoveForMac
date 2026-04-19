import AppKit
import Foundation

struct OverlayBadgeState {
    let text: String
}

enum OverlayRendererKind: String, Codable, CaseIterable {
    case legacy
    case calayer
    case metal
}

@MainActor
protocol OverlayRenderer: AnyObject {
    var overlayPanel: NSPanel? { get }

    func show(
        on screen: NSScreen,
        slots: [ResolvedTriggerSlot],
        highlightFrame: CGRect?,
        hoveredLayoutID: String?,
        configuration: AppConfiguration,
        badge: OverlayBadgeState?
    )

    func dismiss()
}
