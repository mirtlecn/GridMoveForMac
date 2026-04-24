import AppKit

@MainActor
final class LayoutPreviewView: NSView {
    enum Mode {
        case combined
        case windowLayout
        case triggerRegion
    }

    enum InteractionMode: Equatable {
        case none
        case windowSelection
        case triggerScreenSelection
        case triggerMenuBarSelection
    }

    enum InteractiveCursorRegion: Equatable {
        case none
        case usableRect
        case menuBarRect
    }

    private enum DragAnchor {
        case gridCell(SettingsPreviewGridCell)
        case menuBarSegment(Int)
    }

    private let layout: LayoutPreset
    private let appearanceSettings: AppearanceSettings
    var onWindowSelectionCommitted: ((GridSelection) -> Void)?
    var onTriggerRegionCommitted: ((TriggerRegion) -> Void)?
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
    var interactionMode: InteractionMode = .none {
        didSet {
            guard interactionMode != oldValue else {
                return
            }
            cancelInteraction()
            window?.invalidateCursorRects(for: self)
        }
    }

    private var draftWindowSelection: GridSelection?
    private var draftTriggerRegion: TriggerRegion?
    private var dragAnchor: DragAnchor?
    private var didPushDragCursor = false

    private var interactionBounds: CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return CGRect(x: 0, y: 0, width: 420, height: 260)
        }
        return bounds
    }

    override var isFlipped: Bool {
        true
    }

    init(layout: LayoutPreset, appearance: AppearanceSettings, mode: Mode) {
        self.layout = layout
        self.appearanceSettings = appearance
        self.triggerRegionOverride = layout.triggerRegions.first
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
            drawAllTriggerRegions(in: geometry)
            drawWindowLayout(in: geometry)
        case .windowLayout:
            drawWindowLayout(in: geometry)
        case .triggerRegion:
            drawTriggerRegion(in: geometry)
        }
    }

    override func resetCursorRects() {
        discardCursorRects()

        guard let interactiveCursorRect else {
            return
        }

        addCursorRect(interactiveCursorRect, cursor: .openHand)
    }

    private func drawWindowLayout(in geometry: SettingsPreviewGeometry) {
        var frame = SettingsPreviewSupport.frame(
            for: displayedWindowSelection,
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

    private func drawAllTriggerRegions(in geometry: SettingsPreviewGeometry) {
        for region in layout.triggerRegions {
            drawRegion(region, in: geometry)
        }
    }

    private func drawTriggerRegion(in geometry: SettingsPreviewGeometry) {
        guard let triggerRegion = displayedTriggerRegion else {
            return
        }
        drawRegion(triggerRegion, in: geometry)
    }

    private func drawRegion(_ triggerRegion: TriggerRegion, in geometry: SettingsPreviewGeometry) {
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

    override func mouseDown(with event: NSEvent) {
        beginInteraction(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        updateInteraction(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        endInteraction(at: convert(event.locationInWindow, from: nil))
    }

    private var displayedWindowSelection: GridSelection {
        draftWindowSelection ?? layout.windowSelection
    }

    private var displayedTriggerRegion: TriggerRegion? {
        draftTriggerRegion ?? triggerRegionOverride
    }

    private var interactiveCursorRegion: InteractiveCursorRegion {
        switch interactionMode {
        case .none:
            return .none
        case .windowSelection, .triggerScreenSelection:
            return .usableRect
        case .triggerMenuBarSelection:
            return .menuBarRect
        }
    }

    private var interactiveCursorRect: CGRect? {
        let geometry = SettingsPreviewSupport.makeGeometry(in: interactionBounds)
        return switch interactiveCursorRegion {
        case .none:
            nil
        case .usableRect:
            geometry.usableRect
        case .menuBarRect:
            geometry.menuBarRect
        }
    }

    private func beginInteraction(at point: CGPoint) {
        let geometry = SettingsPreviewSupport.makeGeometry(in: interactionBounds)

        switch interactionMode {
        case .none:
            cancelInteraction()
        case .windowSelection:
            guard let gridCell = SettingsPreviewSupport.gridCell(
                containing: point,
                in: geometry.usableRect,
                columns: layout.gridColumns,
                rows: layout.gridRows
            ) else {
                cancelInteraction()
                return
            }
            dragAnchor = .gridCell(gridCell)
            draftWindowSelection = SettingsPreviewSupport.normalizedGridSelection(
                from: gridCell,
                to: gridCell,
                columns: layout.gridColumns,
                rows: layout.gridRows
            )
            beginDragCursor()
            needsDisplay = true
        case .triggerScreenSelection:
            guard let gridCell = SettingsPreviewSupport.gridCell(
                containing: point,
                in: geometry.usableRect,
                columns: layout.gridColumns,
                rows: layout.gridRows
            ) else {
                cancelInteraction()
                return
            }
            dragAnchor = .gridCell(gridCell)
            draftTriggerRegion = .screen(
                SettingsPreviewSupport.normalizedGridSelection(
                    from: gridCell,
                    to: gridCell,
                    columns: layout.gridColumns,
                    rows: layout.gridRows
                )
            )
            beginDragCursor()
            needsDisplay = true
        case .triggerMenuBarSelection:
            guard let segment = SettingsPreviewSupport.menuBarSegment(
                containing: point,
                in: geometry.menuBarRect,
                segments: layout.gridRows
            ) else {
                cancelInteraction()
                return
            }
            dragAnchor = .menuBarSegment(segment)
            draftTriggerRegion = .menuBar(
                SettingsPreviewSupport.normalizedMenuBarSelection(
                    from: segment,
                    to: segment,
                    segments: layout.gridRows
                )
            )
            beginDragCursor()
            needsDisplay = true
        }
    }

    private func updateInteraction(at point: CGPoint) {
        guard let dragAnchor else {
            return
        }

        let geometry = SettingsPreviewSupport.makeGeometry(in: interactionBounds)
        switch (interactionMode, dragAnchor) {
        case let (.windowSelection, .gridCell(anchorCell)):
            guard let gridCell = SettingsPreviewSupport.gridCell(
                containing: point,
                in: geometry.usableRect,
                columns: layout.gridColumns,
                rows: layout.gridRows,
                clampingToBounds: true
            ) else {
                return
            }
            draftWindowSelection = SettingsPreviewSupport.normalizedGridSelection(
                from: anchorCell,
                to: gridCell,
                columns: layout.gridColumns,
                rows: layout.gridRows
            )
            needsDisplay = true
        case let (.triggerScreenSelection, .gridCell(anchorCell)):
            guard let gridCell = SettingsPreviewSupport.gridCell(
                containing: point,
                in: geometry.usableRect,
                columns: layout.gridColumns,
                rows: layout.gridRows,
                clampingToBounds: true
            ) else {
                return
            }
            draftTriggerRegion = .screen(
                SettingsPreviewSupport.normalizedGridSelection(
                    from: anchorCell,
                    to: gridCell,
                    columns: layout.gridColumns,
                    rows: layout.gridRows
                )
            )
            needsDisplay = true
        case let (.triggerMenuBarSelection, .menuBarSegment(anchorSegment)):
            guard let segment = SettingsPreviewSupport.menuBarSegment(
                containing: point,
                in: geometry.menuBarRect,
                segments: layout.gridRows,
                clampingToBounds: true
            ) else {
                return
            }
            draftTriggerRegion = .menuBar(
                SettingsPreviewSupport.normalizedMenuBarSelection(
                    from: anchorSegment,
                    to: segment,
                    segments: layout.gridRows
                )
            )
            needsDisplay = true
        default:
            cancelInteraction()
        }
    }

    private func endInteraction(at point: CGPoint) {
        updateInteraction(at: point)

        switch interactionMode {
        case .windowSelection:
            if let draftWindowSelection {
                onWindowSelectionCommitted?(draftWindowSelection)
            }
        case .triggerScreenSelection, .triggerMenuBarSelection:
            if let draftTriggerRegion {
                onTriggerRegionCommitted?(draftTriggerRegion)
            }
        case .none:
            break
        }

        cancelInteraction()
    }

    private func cancelInteraction() {
        endDragCursor()
        dragAnchor = nil
        draftWindowSelection = nil
        draftTriggerRegion = nil
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    private func beginDragCursor() {
        guard !didPushDragCursor else {
            return
        }
        NSCursor.closedHand.push()
        didPushDragCursor = true
    }

    private func endDragCursor() {
        guard didPushDragCursor else {
            return
        }
        NSCursor.pop()
        didPushDragCursor = false
    }
}

extension LayoutPreviewView {
    var interactionModeForTesting: InteractionMode {
        interactionMode
    }

    var displayedWindowSelectionForTesting: GridSelection {
        displayedWindowSelection
    }

    var displayedTriggerRegionForTesting: TriggerRegion? {
        displayedTriggerRegion
    }

    var interactiveCursorRegionForTesting: InteractiveCursorRegion {
        interactiveCursorRegion
    }

    func simulateGridDragForTesting(from start: SettingsPreviewGridCell, to end: SettingsPreviewGridCell) {
        let geometry = SettingsPreviewSupport.makeGeometry(in: interactionBounds)
        beginInteraction(
            at: SettingsPreviewSupport.frame(
                for: GridSelection(x: start.column, y: start.row, w: 1, h: 1),
                columns: layout.gridColumns,
                rows: layout.gridRows,
                in: geometry.usableRect
            ).center
        )
        endInteraction(
            at: SettingsPreviewSupport.frame(
                for: GridSelection(x: end.column, y: end.row, w: 1, h: 1),
                columns: layout.gridColumns,
                rows: layout.gridRows,
                in: geometry.usableRect
            ).center
        )
    }

    func simulateMenuBarDragForTesting(from startSegment: Int, to endSegment: Int) {
        let geometry = SettingsPreviewSupport.makeGeometry(in: interactionBounds)
        beginInteraction(
            at: SettingsPreviewSupport.frame(
                for: MenuBarSelection(x: startSegment, w: 1),
                segments: layout.gridRows,
                in: geometry.menuBarRect
            ).center
        )
        endInteraction(
            at: SettingsPreviewSupport.frame(
                for: MenuBarSelection(x: endSegment, w: 1),
                segments: layout.gridRows,
                in: geometry.menuBarRect
            ).center
        )
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
