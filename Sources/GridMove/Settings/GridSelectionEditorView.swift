import AppKit

struct CellSelection: Equatable {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

@MainActor
final class GridSelectionEditorView: NSView {
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

    var drawsSelectionFill = true
    var onSelectionChanged: ((CellSelection) -> Void)?

    private var dragStartCell: (column: Int, row: Int)?

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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let background = NSColor.windowBackgroundColor.blended(withFraction: 0.15, of: .black) ?? .windowBackgroundColor
        background.setFill()
        dirtyRect.fill()

        drawOuterFrame()
        drawCells()
        drawSelection()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let cell = cell(at: point) else {
            return
        }

        dragStartCell = cell
        let nextSelection = CellSelection(x: cell.column, y: cell.row, w: 1, h: 1)
        selection = nextSelection
        onSelectionChanged?(nextSelection)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartCell else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        guard let currentCell = cell(at: point) else {
            return
        }

        let left = min(dragStartCell.column, currentCell.column)
        let top = min(dragStartCell.row, currentCell.row)
        let right = max(dragStartCell.column, currentCell.column)
        let bottom = max(dragStartCell.row, currentCell.row)
        let nextSelection = CellSelection(
            x: left,
            y: top,
            w: right - left + 1,
            h: bottom - top + 1
        )
        selection = nextSelection
        onSelectionChanged?(nextSelection)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartCell = nil
    }

    private func drawOuterFrame() {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        NSColor.separatorColor.withAlphaComponent(0.45).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawCells() {
        guard columns > 0, rows > 0 else {
            return
        }

        let baseFill = NSColor.controlBackgroundColor.blended(withFraction: 0.2, of: .black) ?? .controlBackgroundColor
        let alternateFill = NSColor.controlBackgroundColor.blended(withFraction: 0.08, of: .white) ?? .controlBackgroundColor
        let borderColor = NSColor.gridColor.withAlphaComponent(0.28)

        for row in 0 ..< rows {
            for column in 0 ..< columns {
                let rect = rect(forCellAtColumn: column, row: row)
                let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
                ((row + column).isMultiple(of: 2) ? baseFill : alternateFill).setFill()
                path.fill()
                borderColor.setStroke()
                path.lineWidth = 0.8
                path.stroke()
            }
        }
    }

    private func drawSelection() {
        guard let selection else {
            return
        }

        let rect = rect(for: selection)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        if drawsSelectionFill {
            selectionColor.withAlphaComponent(0.22).setFill()
            path.fill()
        }
        selectionColor.setStroke()
        path.lineWidth = 2.5
        path.stroke()
    }

    private func cell(at point: CGPoint) -> (column: Int, row: Int)? {
        guard bounds.contains(point), columns > 0, rows > 0 else {
            return nil
        }

        let cellWidth = bounds.width / CGFloat(columns)
        let cellHeight = bounds.height / CGFloat(rows)
        let column = min(columns - 1, max(0, Int(point.x / cellWidth)))
        let rowFromBottom = min(rows - 1, max(0, Int(point.y / cellHeight)))
        let row = rows - 1 - rowFromBottom
        return (column, row)
    }

    private func rect(for selection: CellSelection) -> CGRect {
        let cellWidth = bounds.width / CGFloat(max(columns, 1))
        let cellHeight = bounds.height / CGFloat(max(rows, 1))
        return CGRect(
            x: CGFloat(selection.x) * cellWidth + 2,
            y: bounds.height - CGFloat(selection.y + selection.h) * cellHeight + 2,
            width: CGFloat(selection.w) * cellWidth - 4,
            height: CGFloat(selection.h) * cellHeight - 4
        )
    }

    private func rect(forCellAtColumn column: Int, row: Int) -> CGRect {
        let cellWidth = bounds.width / CGFloat(max(columns, 1))
        let cellHeight = bounds.height / CGFloat(max(rows, 1))
        return CGRect(
            x: CGFloat(column) * cellWidth + 3,
            y: bounds.height - CGFloat(row + 1) * cellHeight + 3,
            width: cellWidth - 6,
            height: cellHeight - 6
        )
    }
}
