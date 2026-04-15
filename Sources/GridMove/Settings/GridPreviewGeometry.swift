import AppKit
import CoreGraphics
import Foundation

struct GridPreviewGeometry {
    static let defaultOuterPadding: CGFloat = 12

    let columns: Int
    let rows: Int
    let bounds: CGRect
    let outerPadding: CGFloat

    var canvasRect: CGRect {
        bounds.insetBy(dx: outerPadding, dy: outerPadding)
    }

    func cellRect(column: Int, row: Int) -> CGRect {
        let cellWidth = canvasRect.width / CGFloat(max(columns, 1))
        let cellHeight = canvasRect.height / CGFloat(max(rows, 1))
        return CGRect(
            x: canvasRect.minX + CGFloat(column) * cellWidth + 3,
            y: canvasRect.maxY - CGFloat(row + 1) * cellHeight + 3,
            width: cellWidth - 6,
            height: cellHeight - 6
        )
    }

    func selectionRect(_ selection: GridSelection) -> CGRect {
        let cellWidth = canvasRect.width / CGFloat(max(columns, 1))
        let cellHeight = canvasRect.height / CGFloat(max(rows, 1))
        return CGRect(
            x: canvasRect.minX + CGFloat(selection.x) * cellWidth + 2,
            y: canvasRect.maxY - CGFloat(selection.y + selection.h) * cellHeight + 2,
            width: CGFloat(selection.w) * cellWidth - 4,
            height: CGFloat(selection.h) * cellHeight - 4
        )
    }

    func cell(at point: CGPoint, clampToCanvas: Bool) -> (column: Int, row: Int)? {
        let sourcePoint: CGPoint
        if clampToCanvas {
            sourcePoint = CGPoint(
                x: min(max(point.x, canvasRect.minX + 0.001), canvasRect.maxX - 0.001),
                y: min(max(point.y, canvasRect.minY + 0.001), canvasRect.maxY - 0.001)
            )
        } else {
            guard canvasRect.contains(point) else {
                return nil
            }
            sourcePoint = point
        }

        let relativeX = sourcePoint.x - canvasRect.minX
        let relativeY = sourcePoint.y - canvasRect.minY
        let cellWidth = canvasRect.width / CGFloat(max(columns, 1))
        let cellHeight = canvasRect.height / CGFloat(max(rows, 1))

        let column = min(columns - 1, max(0, Int(relativeX / cellWidth)))
        let rowFromBottom = min(rows - 1, max(0, Int(relativeY / cellHeight)))
        let row = rows - 1 - rowFromBottom
        return (column, row)
    }
}

enum PreviewDisplayMetrics {
    static var mainDisplayAspectRatio: CGFloat {
        if let frame = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == CGMainDisplayID()
        })?.frame, frame.height > 0 {
            return frame.width / frame.height
        }

        if let frame = NSScreen.main?.frame, frame.height > 0 {
            return frame.width / frame.height
        }

        return 16.0 / 10.0
    }
}
