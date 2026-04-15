import AppKit

struct CellSelection: Equatable {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

@MainActor
final class GridSelectionEditorView: NSView {
    private enum ResizeHandle {
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

    private enum DragState {
        case creating(startCell: (column: Int, row: Int))
        case resizing(handle: ResizeHandle, initialSelection: CellSelection)
    }

    var columns: Int = 12 {
        didSet { needsDisplay = true }
    }

    var rows: Int = 6 {
        didSet { needsDisplay = true }
    }

    var selection: CellSelection? {
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

    var onSelectionChanged: ((CellSelection) -> Void)?

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

    override var acceptsFirstResponder: Bool {
        true
    }

    override var isFlipped: Bool {
        true
    }

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
            drawOuterFrame()
            drawCells()
        }

        if showsSelection {
            drawSelection()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let selection, let handle = resizeHandle(at: point, selection: selection) {
            dragState = .resizing(handle: handle, initialSelection: selection)
            window?.disableCursorRects()
            handle.cursor.push()
            hasPushedCursor = true
            return
        }

        guard let cell = previewGeometry.cell(at: point, clampToCanvas: false) else {
            return
        }

        let nextSelection = CellSelection(x: cell.column, y: cell.row, w: 1, h: 1)
        dragState = .creating(startCell: cell)
        updateSelection(nextSelection)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragState else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        guard let currentCell = previewGeometry.cell(at: point, clampToCanvas: true) else {
            return
        }

        switch dragState {
        case let .creating(startCell):
            updateSelection(selectionBetween(startCell: startCell, endCell: currentCell))
        case let .resizing(handle, initialSelection):
            updateSelection(selectionByResizing(initialSelection: initialSelection, handle: handle, targetCell: currentCell))
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

    private func drawOuterFrame() {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 16, yRadius: 16)
        NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawCells() {
        guard columns > 0, rows > 0 else {
            return
        }

        let baseFill = NSColor.controlBackgroundColor.blended(withFraction: 0.2, of: .black) ?? .controlBackgroundColor
        let alternateFill = NSColor.controlBackgroundColor.blended(withFraction: 0.08, of: .white) ?? .controlBackgroundColor

        for row in 0 ..< rows {
            for column in 0 ..< columns {
                let rect = previewGeometry.cellRect(column: column, row: row)
                let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
                ((row + column).isMultiple(of: 2) ? baseFill : alternateFill).setFill()
                path.fill()
            }
        }

        let framePath = NSBezierPath(roundedRect: previewGeometry.canvasRect, xRadius: 16, yRadius: 16)
        NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
        framePath.lineWidth = 1
        framePath.stroke()
    }

    private func drawSelection() {
        guard let selection else {
            return
        }

        let rect = previewGeometry.selectionRect(
            GridSelection(x: selection.x, y: selection.y, w: selection.w, h: selection.h)
        )
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        selectionColor.withAlphaComponent(0.22).setFill()
        path.fill()
        selectionColor.setStroke()
        path.lineWidth = 2.5
        path.stroke()
    }

    private func updateSelection(_ selection: CellSelection) {
        self.selection = selection
        onSelectionChanged?(selection)
    }

    private func selectionBetween(
        startCell: (column: Int, row: Int),
        endCell: (column: Int, row: Int)
    ) -> CellSelection {
        let left = min(startCell.column, endCell.column)
        let top = min(startCell.row, endCell.row)
        let right = max(startCell.column, endCell.column)
        let bottom = max(startCell.row, endCell.row)

        return CellSelection(
            x: left,
            y: top,
            w: right - left + 1,
            h: bottom - top + 1
        )
    }

    private func selectionByResizing(
        initialSelection: CellSelection,
        handle: ResizeHandle,
        targetCell: (column: Int, row: Int)
    ) -> CellSelection {
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

        return CellSelection(
            x: left,
            y: top,
            w: right - left + 1,
            h: bottom - top + 1
        )
    }

    private func resizeHandle(at point: CGPoint, selection: CellSelection) -> ResizeHandle? {
        let selectionRect = previewGeometry.selectionRect(
            GridSelection(x: selection.x, y: selection.y, w: selection.w, h: selection.h)
        )

        let topLeft = CGPoint(x: selectionRect.minX, y: selectionRect.maxY)
        let topRight = CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)
        let bottomLeft = CGPoint(x: selectionRect.minX, y: selectionRect.minY)
        let bottomRight = CGPoint(x: selectionRect.maxX, y: selectionRect.minY)

        if isNear(point, topLeft) { return .topLeft }
        if isNear(point, topRight) { return .topRight }
        if isNear(point, bottomLeft) { return .bottomLeft }
        if isNear(point, bottomRight) { return .bottomRight }

        let expandedRect = selectionRect.insetBy(dx: -handleTolerance, dy: -handleTolerance)
        guard expandedRect.contains(point) else {
            return nil
        }

        if abs(point.x - selectionRect.minX) <= handleTolerance {
            return .left
        }
        if abs(point.x - selectionRect.maxX) <= handleTolerance {
            return .right
        }
        if abs(point.y - selectionRect.maxY) <= handleTolerance {
            return .top
        }
        if abs(point.y - selectionRect.minY) <= handleTolerance {
            return .bottom
        }

        return nil
    }

    private func isNear(_ point: CGPoint, _ target: CGPoint) -> Bool {
        abs(point.x - target.x) <= handleTolerance && abs(point.y - target.y) <= handleTolerance
    }

    private func updateCursor(for point: CGPoint) {
        guard let selection, let handle = resizeHandle(at: point, selection: selection) else {
            NSCursor.arrow.set()
            return
        }
        handle.cursor.set()
    }
}
