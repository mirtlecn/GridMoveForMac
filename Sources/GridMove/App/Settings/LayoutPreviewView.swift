import AppKit

@MainActor
final class LayoutPreviewView: NSView {
    enum Mode {
        case combined
        case windowLayout
        case triggerRegion
    }

    private let layout: LayoutPreset
    private let appearanceSettings: AppearanceSettings
    var triggerRegionOverride: TriggerRegion? {
        didSet {
            needsDisplay = true
        }
    }
    var mode: Mode {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    init(layout: LayoutPreset, appearance: AppearanceSettings, mode: Mode) {
        self.layout = layout
        self.appearanceSettings = appearance
        self.triggerRegionOverride = layout.triggerRegion
        self.mode = mode
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
        SettingsPreviewSupport.drawGrid(columns: layout.gridColumns, rows: layout.gridRows, in: geometry.usableRect)
        SettingsPreviewSupport.drawMenuBarSegments(segments: layout.gridRows, in: geometry.menuBarRect)

        switch mode {
        case .combined:
            drawTriggerRegion(in: geometry)
            drawWindowLayout(in: geometry)
        case .windowLayout:
            drawWindowLayout(in: geometry)
        case .triggerRegion:
            drawTriggerRegion(in: geometry)
        }
    }

    private func drawWindowLayout(in geometry: SettingsPreviewGeometry) {
        var frame = SettingsPreviewSupport.frame(
            for: layout.windowSelection,
            columns: layout.gridColumns,
            rows: layout.gridRows,
            in: geometry.usableRect
        )
        frame = frame.insetBy(dx: CGFloat(appearanceSettings.effectiveLayoutGap), dy: CGFloat(appearanceSettings.effectiveLayoutGap))

        let fillColor = appearanceSettings.highlightStrokeColor.nsColor.withAlphaComponent(appearanceSettings.highlightFillOpacity + 0.08)
        let strokeColor = appearanceSettings.highlightStrokeColor.nsColor

        let path = NSBezierPath(roundedRect: frame, xRadius: 12, yRadius: 12)
        fillColor.setFill()
        path.fill()
        strokeColor.setStroke()
        path.lineWidth = max(2, appearanceSettings.highlightStrokeWidth)
        path.stroke()
    }

    private func drawTriggerRegion(in geometry: SettingsPreviewGeometry) {
        guard let triggerRegion = triggerRegionOverride else {
            return
        }

        let regionRect: CGRect
        switch triggerRegion {
        case let .screen(selection):
            regionRect = SettingsPreviewSupport.frame(
                for: selection,
                columns: layout.gridColumns,
                rows: layout.gridRows,
                in: geometry.usableRect
            ).insetBy(dx: appearanceSettings.triggerGap, dy: appearanceSettings.triggerGap)
        case let .menuBar(selection):
            regionRect = SettingsPreviewSupport.frame(
                for: selection,
                segments: layout.gridRows,
                in: geometry.menuBarRect
            ).insetBy(dx: appearanceSettings.triggerGap, dy: appearanceSettings.triggerGap)
        }

        let fillColor = appearanceSettings.triggerStrokeColor.nsColor.withAlphaComponent(appearanceSettings.triggerOpacity)
        let strokeColor = appearanceSettings.triggerStrokeColor.nsColor.withAlphaComponent(0.9)

        fillColor.setFill()
        let path = NSBezierPath(roundedRect: regionRect, xRadius: 10, yRadius: 10)
        path.fill()
        strokeColor.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
