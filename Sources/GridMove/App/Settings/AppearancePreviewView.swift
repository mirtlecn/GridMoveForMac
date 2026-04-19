import AppKit

@MainActor
final class AppearancePreviewView: NSView {
    private enum PreviewSampleLayout {
        static let windowLayoutID = "preview-window-layout"
        static let triggerLayoutID = "preview-trigger-layout"
    }

    private var configuration: AppConfiguration = .defaultValue
    private var resolvedSlots: [ResolvedTriggerSlot] = []
    private var highlightFrame: CGRect?

    override var isFlipped: Bool { true }

    init(configuration: AppConfiguration = .defaultValue) {
        super.init(frame: .zero)
        updateConfiguration(configuration)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func updateConfiguration(_ configuration: AppConfiguration) {
        self.configuration = configuration

        let engine = LayoutEngine()
        let previewWindowLayout = Self.sampleWindowLayout()
        let previewTriggerLayout = Self.sampleTriggerLayout()
        resolvedSlots = engine.resolveTriggerSlots(
            screenFrame: SettingsPreviewSupport.referenceScreenFrame,
            usableFrame: SettingsPreviewSupport.referenceUsableFrame,
            layouts: [previewTriggerLayout],
            triggerGap: Double(configuration.appearance.triggerGap),
            layoutGap: configuration.appearance.effectiveLayoutGap
        )
        highlightFrame = engine.frame(
            for: previewWindowLayout,
            in: SettingsPreviewSupport.referenceUsableFrame,
            layoutGap: configuration.appearance.effectiveLayoutGap
        )
        needsDisplay = true
    }

    var configurationForTesting: AppConfiguration {
        configuration
    }

    var resolvedSlotsForTesting: [ResolvedTriggerSlot] {
        resolvedSlots
    }

    var highlightFrameForTesting: CGRect? {
        highlightFrame
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

    private static func sampleWindowLayout() -> LayoutPreset {
        LayoutPreset(
            id: PreviewSampleLayout.windowLayoutID,
            name: "Preview window",
            gridColumns: SettingsPreviewSupport.defaultPreviewColumns,
            gridRows: SettingsPreviewSupport.defaultPreviewRows,
            windowSelection: GridSelection(x: 3, y: 1, w: 6, h: 4),
            triggerRegion: nil,
            includeInLayoutIndex: false,
            includeInMenu: false
        )
    }

    private static func sampleTriggerLayout() -> LayoutPreset {
        LayoutPreset(
            id: PreviewSampleLayout.triggerLayoutID,
            name: "Preview trigger",
            gridColumns: SettingsPreviewSupport.defaultPreviewColumns,
            gridRows: SettingsPreviewSupport.defaultPreviewRows,
            windowSelection: GridSelection(x: 3, y: 1, w: 6, h: 4),
            triggerRegion: .screen(GridSelection(x: 5, y: 0, w: 2, h: 6)),
            includeInLayoutIndex: false,
            includeInMenu: false
        )
    }
}
