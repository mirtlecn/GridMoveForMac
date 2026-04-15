import CoreGraphics
import Testing
@testable import GridMove

@Test func gridPreviewGeometryMapsTopLeftCellCorrectly() async throws {
    let geometry = GridPreviewGeometry(
        columns: 12,
        rows: 6,
        bounds: CGRect(x: 0, y: 0, width: 1200, height: 600),
        outerPadding: 12
    )

    let topLeftRect = geometry.cellRect(column: 0, row: 0)
    let topLeftCell = geometry.cell(at: CGPoint(x: topLeftRect.midX, y: topLeftRect.midY), clampToCanvas: false)

    #expect(topLeftCell?.column == 0)
    #expect(topLeftCell?.row == 0)
}

@Test func gridPreviewGeometryMapsBottomRightCellCorrectly() async throws {
    let geometry = GridPreviewGeometry(
        columns: 12,
        rows: 6,
        bounds: CGRect(x: 0, y: 0, width: 1200, height: 600),
        outerPadding: 12
    )

    let bottomRightRect = geometry.cellRect(column: 11, row: 5)
    let bottomRightCell = geometry.cell(at: CGPoint(x: bottomRightRect.midX, y: bottomRightRect.midY), clampToCanvas: false)

    #expect(bottomRightCell?.column == 11)
    #expect(bottomRightCell?.row == 5)
}

@Test func gridPreviewGeometryClampsPointsOutsideCanvasToNearestCell() async throws {
    let geometry = GridPreviewGeometry(
        columns: 12,
        rows: 6,
        bounds: CGRect(x: 0, y: 0, width: 1200, height: 600),
        outerPadding: 12
    )

    let topLeftCell = geometry.cell(at: CGPoint(x: -100, y: 900), clampToCanvas: true)
    let bottomRightCell = geometry.cell(at: CGPoint(x: 9000, y: -100), clampToCanvas: true)

    #expect(topLeftCell?.column == 0)
    #expect(topLeftCell?.row == 0)
    #expect(bottomRightCell?.column == 11)
    #expect(bottomRightCell?.row == 5)
}

@Test func gridPreviewGeometrySelectionRectKeepsTopOrigin() async throws {
    let geometry = GridPreviewGeometry(
        columns: 12,
        rows: 6,
        bounds: CGRect(x: 0, y: 0, width: 1200, height: 600),
        outerPadding: 12
    )

    let selectionRect = geometry.selectionRect(GridSelection(x: 5, y: 0, w: 2, h: 2))

    #expect(selectionRect.maxY > geometry.canvasRect.midY)
}
