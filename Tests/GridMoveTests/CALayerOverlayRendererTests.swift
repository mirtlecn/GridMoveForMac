import AppKit
import QuartzCore
import Testing
@testable import GridMove

@MainActor
struct CALayerOverlayRendererTests {
    @Test func badgeTextLayerUsesProvidedTargetScreenScale() async throws {
        let renderer = CALayerOverlayRenderer(screenScaleProvider: { _ in 1.5 })
        let screen = try #require(NSScreen.screens.first)

        renderer.show(
            on: screen,
            slots: [],
            highlightFrame: nil,
            hoveredLayoutID: nil,
            configuration: .defaultValue,
            badge: OverlayBadgeState(text: "Test")
        )

        let rootLayer = try #require(renderer.overlayPanel?.contentView?.layer)
        let textLayer = try #require(rootLayer.sublayers?.compactMap { $0 as? CATextLayer }.first)
        #expect(textLayer.contentsScale == 1.5)

        renderer.dismiss()
    }
}
