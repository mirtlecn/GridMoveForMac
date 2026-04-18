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
        SettingsPreviewSupport.drawWindowHighlight(
            rect: frame,
            appearance: appearanceSettings,
            cornerRadius: 12
        )
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
            ).insetBy(dx: CGFloat(appearanceSettings.triggerGap), dy: CGFloat(appearanceSettings.triggerGap))
        case let .menuBar(selection):
            regionRect = SettingsPreviewSupport.frame(
                for: selection,
                segments: layout.gridRows,
                in: geometry.menuBarRect
            ).insetBy(dx: CGFloat(appearanceSettings.triggerGap), dy: CGFloat(appearanceSettings.triggerGap))
        }

        SettingsPreviewSupport.drawTriggerRegion(
            rect: regionRect,
            appearance: appearanceSettings,
            cornerRadius: 10
        )
    }
}
