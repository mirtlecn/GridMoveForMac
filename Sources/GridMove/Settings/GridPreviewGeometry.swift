import AppKit
import CoreGraphics
import Foundation

enum GridPreviewHit {
    case screen(column: Int, row: Int)
    case menuBar(segment: Int)
}

struct GridPreviewGeometry {
    static let defaultOuterPadding: CGFloat = 12

    let columns: Int
    let rows: Int
    let bounds: CGRect
    let outerPadding: CGFloat

    private var contentRect: CGRect {
        bounds.insetBy(dx: outerPadding, dy: outerPadding)
    }

    var menuBarRect: CGRect {
        CGRect(
            x: contentRect.minX,
            y: contentRect.minY,
            width: contentRect.width,
            height: menuBarHeight
        )
    }

    var canvasRect: CGRect {
        CGRect(
            x: contentRect.minX,
            y: menuBarRect.maxY + menuBarSpacing,
            width: contentRect.width,
            height: screenHeight
        )
    }

    func cellRect(column: Int, row: Int) -> CGRect {
        let cellWidth = canvasRect.width / CGFloat(max(columns, 1))
        let cellHeight = canvasRect.height / CGFloat(max(rows, 1))
        return CGRect(
            x: canvasRect.minX + CGFloat(column) * cellWidth + 3,
            y: canvasRect.minY + CGFloat(row) * cellHeight + 3,
            width: cellWidth - 6,
            height: cellHeight - 6
        )
    }

    func selectionRect(_ selection: GridSelection) -> CGRect {
        let cellWidth = canvasRect.width / CGFloat(max(columns, 1))
        let cellHeight = canvasRect.height / CGFloat(max(rows, 1))
        return CGRect(
            x: canvasRect.minX + CGFloat(selection.x) * cellWidth + 2,
            y: canvasRect.minY + CGFloat(selection.y) * cellHeight + 2,
            width: CGFloat(selection.w) * cellWidth - 4,
            height: CGFloat(selection.h) * cellHeight - 4
        )
    }

    func menuBarSegmentRect(segment: Int) -> CGRect {
        let segmentWidth = menuBarRect.width / CGFloat(max(rows, 1))
        return CGRect(
            x: menuBarRect.minX + CGFloat(segment) * segmentWidth + 3,
            y: menuBarRect.minY + 3,
            width: segmentWidth - 6,
            height: menuBarRect.height - 6
        )
    }

    func menuBarSelectionRect(_ selection: MenuBarSelection) -> CGRect {
        let segmentWidth = menuBarRect.width / CGFloat(max(rows, 1))
        return CGRect(
            x: menuBarRect.minX + CGFloat(selection.x) * segmentWidth + 2,
            y: menuBarRect.minY + 2,
            width: CGFloat(selection.w) * segmentWidth - 4,
            height: menuBarRect.height - 4
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
        let row = min(rows - 1, max(0, Int(relativeY / cellHeight)))
        return (column, row)
    }

    func menuBarSegment(at point: CGPoint, clampToMenuBar: Bool) -> Int? {
        let sourcePoint: CGPoint
        if clampToMenuBar {
            sourcePoint = CGPoint(
                x: min(max(point.x, menuBarRect.minX + 0.001), menuBarRect.maxX - 0.001),
                y: min(max(point.y, menuBarRect.minY + 0.001), menuBarRect.maxY - 0.001)
            )
        } else {
            guard menuBarRect.contains(point) else {
                return nil
            }
            sourcePoint = point
        }

        let relativeX = sourcePoint.x - menuBarRect.minX
        let segmentWidth = menuBarRect.width / CGFloat(max(rows, 1))
        return min(rows - 1, max(0, Int(relativeX / segmentWidth)))
    }

    func triggerHit(at point: CGPoint, clampToPreview: Bool) -> GridPreviewHit? {
        if let segment = menuBarSegment(at: point, clampToMenuBar: clampToPreview && point.y <= canvasRect.minY) {
            return .menuBar(segment: segment)
        }

        if let cell = cell(at: point, clampToCanvas: clampToPreview) {
            return .screen(column: cell.column, row: cell.row)
        }

        return nil
    }

    private var screenHeight: CGFloat {
        contentRect.height / (1 + PreviewDisplayMetrics.menuBarHeightRatio + PreviewDisplayMetrics.menuBarSpacingRatio)
    }

    private var menuBarHeight: CGFloat {
        screenHeight * PreviewDisplayMetrics.menuBarHeightRatio
    }

    private var menuBarSpacing: CGFloat {
        screenHeight * PreviewDisplayMetrics.menuBarSpacingRatio
    }
}

enum PreviewDisplayMetrics {
    static let menuBarHeightRatio: CGFloat = 0.065
    static let menuBarSpacingRatio: CGFloat = 0.03

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

    static var totalPreviewAspectRatio: CGFloat {
        mainDisplayAspectRatio / (1 + menuBarHeightRatio + menuBarSpacingRatio)
    }
}
