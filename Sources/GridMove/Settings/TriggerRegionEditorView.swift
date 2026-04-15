import AppKit

@MainActor
final class TriggerRegionEditorView: NSView {
    private enum ScreenResizeHandle {
        case top
        case bottom
        case left
        case right
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight

        var cursor: NSCursor {
            switch self {
            case .left, .right:
                return .resizeLeftRight
            case .top, .bottom:
                return .resizeUpDown
            case .topLeft, .topRight, .bottomLeft, .bottomRight:
                return .crosshair
            }
        }
    }

    private enum MenuBarResizeHandle {
        case left
        case right

        var cursor: NSCursor { .resizeLeftRight }
    }

    private enum TriggerResizeHandle {
        case screen(ScreenResizeHandle)
        case menuBar(MenuBarResizeHandle)

        var cursor: NSCursor {
            switch self {
            case let .screen(handle):
                return handle.cursor
            case let .menuBar(handle):
                return handle.cursor
            }
        }
    }

    private enum DragState {
        case creatingScreen(startCell: (column: Int, row: Int))
        case creatingMenuBar(startSegment: Int)
        case resizingScreen(handle: ScreenResizeHandle, initialSelection: GridSelection)
        case resizingMenuBar(handle: MenuBarResizeHandle, initialSelection: MenuBarSelection)
    }

    var columns: Int = 12 {
        didSet { needsDisplay = true }
    }

    var rows: Int = 6 {
        didSet { needsDisplay = true }
    }

    var triggerRegion: TriggerRegion = .screen(GridSelection(x: 0, y: 0, w: 1, h: 1)) {
        didSet { needsDisplay = true }
    }

    var selectionColor: NSColor = .controlAccentColor {
        didSet { needsDisplay = true }
    }

    var showsGridBackground = true {
        didSet { needsDisplay = true }
    }

    var showsSelection = true {
        didSet { needsDisplay = true }
    }

    var onTriggerRegionChanged: ((TriggerRegion) -> Void)?

    private var dragState: DragState?
    private var trackingArea: NSTrackingArea?
    private var hasPushedCursor = false
    private let handleTolerance: CGFloat = 14

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    convenience init(columns: Int, rows: Int) {
        self.init(frame: .zero)
        self.columns = columns
        self.rows = rows
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .inVisibleRect,
            .mouseMoved,
            .cursorUpdate,
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if showsGridBackground {
            let background = NSColor.windowBackgroundColor.blended(withFraction: 0.15, of: .black) ?? .windowBackgroundColor
            background.setFill()
            dirtyRect.fill()
        }

        if showsSelection {
            drawSelection()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let handle = resizeHandle(at: point, region: triggerRegion) {
            switch (handle, triggerRegion) {
            case let (.screen(screenHandle), .screen(selection)):
                dragState = .resizingScreen(handle: screenHandle, initialSelection: selection)
            case let (.menuBar(menuBarHandle), .menuBar(selection)):
                dragState = .resizingMenuBar(handle: menuBarHandle, initialSelection: selection)
            default:
                break
            }
            window?.disableCursorRects()
            handle.cursor.push()
            hasPushedCursor = true
            return
        }

        guard let hit = previewGeometry.triggerHit(at: point, clampToPreview: false) else {
            return
        }

        switch hit {
        case let .screen(column, row):
            let nextSelection = GridSelection(x: column, y: row, w: 1, h: 1)
            dragState = .creatingScreen(startCell: (column, row))
            updateTriggerRegion(.screen(nextSelection))
        case let .menuBar(segment):
            let nextSelection = MenuBarSelection(x: segment, w: 1)
            dragState = .creatingMenuBar(startSegment: segment)
            updateTriggerRegion(.menuBar(nextSelection))
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragState else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        switch dragState {
        case let .creatingScreen(startCell):
            guard case let .screen(column, row) = previewGeometry.triggerHit(at: point, clampToPreview: true) else {
                return
            }
            updateTriggerRegion(.screen(screenSelectionBetween(startCell: startCell, endCell: (column, row))))
        case let .creatingMenuBar(startSegment):
            guard case let .menuBar(segment) = previewGeometry.triggerHit(at: point, clampToPreview: true) else {
                return
            }
            updateTriggerRegion(.menuBar(menuBarSelectionBetween(startSegment: startSegment, endSegment: segment)))
        case let .resizingScreen(handle, initialSelection):
            guard case let .screen(column, row) = previewGeometry.triggerHit(at: point, clampToPreview: true) else {
                return
            }
            updateTriggerRegion(.screen(resizeScreenSelection(initialSelection: initialSelection, handle: handle, targetCell: (column, row))))
        case let .resizingMenuBar(handle, initialSelection):
            guard case let .menuBar(segment) = previewGeometry.triggerHit(at: point, clampToPreview: true) else {
                return
            }
            updateTriggerRegion(.menuBar(resizeMenuBarSelection(initialSelection: initialSelection, handle: handle, targetSegment: segment)))
        }
    }

    override func mouseUp(with event: NSEvent) {
        dragState = nil
        if hasPushedCursor {
            window?.enableCursorRects()
            NSCursor.pop()
            hasPushedCursor = false
        }
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        guard dragState == nil else {
            return
        }
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        guard dragState == nil else {
            return
        }
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    private var previewGeometry: GridPreviewGeometry {
        GridPreviewGeometry(
            columns: columns,
            rows: rows,
            bounds: bounds,
            outerPadding: GridPreviewGeometry.defaultOuterPadding
        )
    }

    private func drawSelection() {
        let rect: CGRect
        switch triggerRegion {
        case let .screen(selection):
            rect = previewGeometry.selectionRect(selection)
        case let .menuBar(selection):
            rect = previewGeometry.menuBarSelectionRect(selection)
        }

        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        selectionColor.withAlphaComponent(0.22).setFill()
        path.fill()
        selectionColor.setStroke()
        path.lineWidth = 2.5
        path.stroke()
    }

    private func updateTriggerRegion(_ region: TriggerRegion) {
        triggerRegion = region
        onTriggerRegionChanged?(region)
    }

    private func screenSelectionBetween(
        startCell: (column: Int, row: Int),
        endCell: (column: Int, row: Int)
    ) -> GridSelection {
        let left = min(startCell.column, endCell.column)
        let top = min(startCell.row, endCell.row)
        let right = max(startCell.column, endCell.column)
        let bottom = max(startCell.row, endCell.row)
        return GridSelection(x: left, y: top, w: right - left + 1, h: bottom - top + 1)
    }

    private func menuBarSelectionBetween(startSegment: Int, endSegment: Int) -> MenuBarSelection {
        let left = min(startSegment, endSegment)
        let right = max(startSegment, endSegment)
        return MenuBarSelection(x: left, w: right - left + 1)
    }

    private func resizeScreenSelection(
        initialSelection: GridSelection,
        handle: ScreenResizeHandle,
        targetCell: (column: Int, row: Int)
    ) -> GridSelection {
        var left = initialSelection.x
        var top = initialSelection.y
        var right = initialSelection.x + initialSelection.w - 1
        var bottom = initialSelection.y + initialSelection.h - 1

        switch handle {
        case .left:
            left = min(max(0, targetCell.column), right)
        case .right:
            right = max(min(columns - 1, targetCell.column), left)
        case .top:
            top = min(max(0, targetCell.row), bottom)
        case .bottom:
            bottom = max(min(rows - 1, targetCell.row), top)
        case .topLeft:
            left = min(max(0, targetCell.column), right)
            top = min(max(0, targetCell.row), bottom)
        case .topRight:
            right = max(min(columns - 1, targetCell.column), left)
            top = min(max(0, targetCell.row), bottom)
        case .bottomLeft:
            left = min(max(0, targetCell.column), right)
            bottom = max(min(rows - 1, targetCell.row), top)
        case .bottomRight:
            right = max(min(columns - 1, targetCell.column), left)
            bottom = max(min(rows - 1, targetCell.row), top)
        }

        return GridSelection(x: left, y: top, w: right - left + 1, h: bottom - top + 1)
    }

    private func resizeMenuBarSelection(
        initialSelection: MenuBarSelection,
        handle: MenuBarResizeHandle,
        targetSegment: Int
    ) -> MenuBarSelection {
        var left = initialSelection.x
        var right = initialSelection.x + initialSelection.w - 1

        switch handle {
        case .left:
            left = min(max(0, targetSegment), right)
        case .right:
            right = max(min(rows - 1, targetSegment), left)
        }

        return MenuBarSelection(x: left, w: right - left + 1)
    }

    private func resizeHandle(at point: CGPoint, region: TriggerRegion) -> TriggerResizeHandle? {
        switch region {
        case let .screen(selection):
            return screenResizeHandle(at: point, selection: selection).map { .screen($0) }
        case let .menuBar(selection):
            return menuBarResizeHandle(at: point, selection: selection).map { .menuBar($0) }
        }
    }

    private func screenResizeHandle(at point: CGPoint, selection: GridSelection) -> ScreenResizeHandle? {
        let selectionRect = previewGeometry.selectionRect(selection)

        let topLeft = CGPoint(x: selectionRect.minX, y: selectionRect.minY)
        let topRight = CGPoint(x: selectionRect.maxX, y: selectionRect.minY)
        let bottomLeft = CGPoint(x: selectionRect.minX, y: selectionRect.maxY)
        let bottomRight = CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)

        if isNear(point, topLeft) { return .topLeft }
        if isNear(point, topRight) { return .topRight }
        if isNear(point, bottomLeft) { return .bottomLeft }
        if isNear(point, bottomRight) { return .bottomRight }

        let expandedRect = selectionRect.insetBy(dx: -handleTolerance, dy: -handleTolerance)
        guard expandedRect.contains(point) else {
            return nil
        }

        if abs(point.x - selectionRect.minX) <= handleTolerance { return .left }
        if abs(point.x - selectionRect.maxX) <= handleTolerance { return .right }
        if abs(point.y - selectionRect.minY) <= handleTolerance { return .top }
        if abs(point.y - selectionRect.maxY) <= handleTolerance { return .bottom }
        return nil
    }

    private func menuBarResizeHandle(at point: CGPoint, selection: MenuBarSelection) -> MenuBarResizeHandle? {
        let selectionRect = previewGeometry.menuBarSelectionRect(selection)
        let expandedRect = selectionRect.insetBy(dx: -handleTolerance, dy: -handleTolerance)
        guard expandedRect.contains(point) else {
            return nil
        }

        if abs(point.x - selectionRect.minX) <= handleTolerance { return .left }
        if abs(point.x - selectionRect.maxX) <= handleTolerance { return .right }
        return nil
    }

    private func isNear(_ point: CGPoint, _ target: CGPoint) -> Bool {
        abs(point.x - target.x) <= handleTolerance && abs(point.y - target.y) <= handleTolerance
    }

    private func updateCursor(for point: CGPoint) {
        guard let handle = resizeHandle(at: point, region: triggerRegion) else {
            NSCursor.arrow.set()
            return
        }
        handle.cursor.set()
    }
}
