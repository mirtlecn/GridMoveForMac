import AppKit

@MainActor
final class AppearancePreviewView: NSView {
    private let configuration: AppConfiguration
    private let resolvedSlots: [ResolvedTriggerSlot]
    private let highlightFrame: CGRect?

    override var isFlipped: Bool { true }

    init(configuration: AppConfiguration = .defaultValue) {
        self.configuration = configuration

        let engine = LayoutEngine()
        self.resolvedSlots = engine.resolveTriggerSlots(
            screenFrame: SettingsPreviewSupport.referenceScreenFrame,
            usableFrame: SettingsPreviewSupport.referenceUsableFrame,
            layouts: configuration.layouts.filter { $0.triggerRegion != nil },
            triggerGap: configuration.appearance.triggerGap,
            layoutGap: configuration.appearance.effectiveLayoutGap
        )
        self.highlightFrame = resolvedSlots.first(where: { $0.layoutID == "layout-4" })?.targetFrame
            ?? resolvedSlots.first?.targetFrame
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let geometry = SettingsPreviewSupport.makeGeometry(in: bounds)
        SettingsPreviewSupport.drawDisplayChrome(in: geometry)
        SettingsPreviewSupport.drawGrid(
            columns: SettingsPreviewSupport.defaultPreviewColumns,
            rows: SettingsPreviewSupport.defaultPreviewRows,
            in: geometry.usableRect
        )
        SettingsPreviewSupport.drawMenuBarSegments(
            segments: SettingsPreviewSupport.defaultPreviewRows,
            in: geometry.menuBarRect
        )

        if configuration.appearance.renderTriggerAreas {
            drawTriggerSlots(in: geometry)
        }

        if configuration.appearance.renderWindowHighlight, let highlightFrame {
            drawHighlight(frame: highlightFrame, geometry: geometry)
        }
    }

    private func drawTriggerSlots(in geometry: SettingsPreviewGeometry) {
        let color = configuration.appearance.triggerStrokeColor.nsColor
        color.setStroke()

        for slot in resolvedSlots {
            for hitTestFrame in slot.hitTestFrames {
                let path = NSBezierPath(
                    roundedRect: SettingsPreviewSupport.localRect(from: hitTestFrame, in: geometry),
                    xRadius: 10,
                    yRadius: 10
                )
                path.lineWidth = 2
                path.stroke()
            }
        }
    }

    private func drawHighlight(frame: CGRect, geometry: SettingsPreviewGeometry) {
        let rect = SettingsPreviewSupport.localRect(from: frame, in: geometry)
        let color = configuration.appearance.highlightStrokeColor.nsColor
        color.withAlphaComponent(configuration.appearance.highlightFillOpacity).setFill()
        color.setStroke()

        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        path.lineWidth = configuration.appearance.highlightStrokeWidth
        path.fill()
        path.stroke()
    }
}
