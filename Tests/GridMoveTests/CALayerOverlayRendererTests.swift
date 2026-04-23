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

    @Test func layoutCursorAddsShapeLayers() async throws {
        let renderer = CALayerOverlayRenderer()
        let screen = try #require(NSScreen.screens.first)

        renderer.show(
            on: screen,
            slots: [],
            highlightFrame: nil,
            hoveredLayoutID: nil,
            configuration: configurationWithoutOverlayRendering(),
            badge: nil,
            cursor: OverlayCursorState(point: CGPoint(x: screen.frame.midX, y: screen.frame.midY), mode: .layoutSelection)
        )

        let rootLayer = try #require(renderer.overlayPanel?.contentView?.layer)
        #expect(rootLayer.sublayers?.compactMap { $0 as? CAShapeLayer }.count == 6)

        renderer.dismiss()
    }

    @Test func moveCursorAddsShapeLayers() async throws {
        let renderer = CALayerOverlayRenderer()
        let screen = try #require(NSScreen.screens.first)

        renderer.show(
            on: screen,
            slots: [],
            highlightFrame: nil,
            hoveredLayoutID: nil,
            configuration: configurationWithoutOverlayRendering(),
            badge: nil,
            cursor: OverlayCursorState(point: CGPoint(x: screen.frame.midX, y: screen.frame.midY), mode: .moveOnly)
        )

        let rootLayer = try #require(renderer.overlayPanel?.contentView?.layer)
        #expect(rootLayer.sublayers?.compactMap { $0 as? CAShapeLayer }.count == 10)

        renderer.dismiss()
    }

    @Test func overlayControllerShowsOverlayWhenOnlyCursorIsPresent() async throws {
        let screen = try #require(NSScreen.screens.first)
        var receivedCursor: OverlayCursorState?
        let controller = OverlayController(
            testHooks: .init(
                showOverlay: { _, _, _, _, _, _, cursor in
                    receivedCursor = cursor
                }
            )
        )
        let cursor = OverlayCursorState(point: CGPoint(x: screen.frame.midX, y: screen.frame.midY), mode: .moveOnly)

        controller.update(
            screen: screen,
            slots: [],
            highlightFrame: nil,
            hoveredLayoutID: nil,
            configuration: configurationWithoutOverlayRendering(),
            cursor: cursor
        )

        #expect(receivedCursor == cursor)
    }

    private func configurationWithoutOverlayRendering() -> AppConfiguration {
        var configuration = AppConfiguration.defaultValue
        configuration.appearance.triggerHighlightMode = .none
        configuration.appearance.renderWindowHighlight = false
        configuration.appearance.highlightStrokeWidth = 0
        configuration.appearance.highlightFillOpacity = 0
        return configuration
    }
}
