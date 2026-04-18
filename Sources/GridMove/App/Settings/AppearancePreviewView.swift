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
            triggerGap: Double(configuration.appearance.triggerGap),
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
        for slot in resolvedSlots {
            for hitTestFrame in slot.hitTestFrames {
                SettingsPreviewSupport.drawTriggerRegion(
                    rect: SettingsPreviewSupport.localRect(from: hitTestFrame, in: geometry),
                    appearance: configuration.appearance,
                    cornerRadius: 10
                )
            }
        }
    }

    private func drawHighlight(frame: CGRect, geometry: SettingsPreviewGeometry) {
        SettingsPreviewSupport.drawWindowHighlight(
            rect: SettingsPreviewSupport.localRect(from: frame, in: geometry),
            appearance: configuration.appearance,
            cornerRadius: 10
        )
    }
}
