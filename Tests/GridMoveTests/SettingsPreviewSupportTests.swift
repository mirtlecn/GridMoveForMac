import AppKit
import Testing
@testable import GridMove

struct SettingsPreviewSupportTests {
    @Test func gridCellHitTestingReturnsExpectedIndicesAndCanClamp() async throws {
        let rect = CGRect(x: 10, y: 20, width: 120, height: 60)

        #expect(
            SettingsPreviewSupport.gridCell(
                containing: CGPoint(x: 39, y: 39),
                in: rect,
                columns: 6,
                rows: 3
            ) == SettingsPreviewGridCell(column: 1, row: 0)
        )
        #expect(
            SettingsPreviewSupport.gridCell(
                containing: CGPoint(x: 5, y: 10),
                in: rect,
                columns: 6,
                rows: 3
            ) == nil
        )
        #expect(
            SettingsPreviewSupport.gridCell(
                containing: CGPoint(x: 500, y: 500),
                in: rect,
                columns: 6,
                rows: 3,
                clampingToBounds: true
            ) == SettingsPreviewGridCell(column: 5, row: 2)
        )
    }

    @Test func menuBarSegmentHitTestingReturnsExpectedIndicesAndCanClamp() async throws {
        let rect = CGRect(x: 0, y: 0, width: 90, height: 10)

        #expect(
            SettingsPreviewSupport.menuBarSegment(
                containing: CGPoint(x: 44, y: 5),
                in: rect,
                segments: 6
            ) == 2
        )
        #expect(
            SettingsPreviewSupport.menuBarSegment(
                containing: CGPoint(x: -1, y: 5),
                in: rect,
                segments: 6
            ) == nil
        )
        #expect(
            SettingsPreviewSupport.menuBarSegment(
                containing: CGPoint(x: -100, y: -100),
                in: rect,
                segments: 6,
                clampingToBounds: true
            ) == 0
        )
    }

    @Test func normalizedGridSelectionHandlesReverseDrag() async throws {
        let selection = SettingsPreviewSupport.normalizedGridSelection(
            from: SettingsPreviewGridCell(column: 4, row: 3),
            to: SettingsPreviewGridCell(column: 1, row: 1),
            columns: 6,
            rows: 5
        )

        #expect(selection == GridSelection(x: 1, y: 1, w: 4, h: 3))
    }

    @Test func normalizedMenuBarSelectionOnlyProducesStartAndWidth() async throws {
        let selection = SettingsPreviewSupport.normalizedMenuBarSelection(
            from: 5,
            to: 2,
            segments: 6
        )

        #expect(selection == MenuBarSelection(x: 2, w: 4))
    }
}
