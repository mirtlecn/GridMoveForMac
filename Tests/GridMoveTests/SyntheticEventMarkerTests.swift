import CoreGraphics
import Foundation
import Testing
@testable import GridMove

@Test func syntheticMouseButtonReplayMarkerRoundTrips() async throws {
    let source = try #require(CGEventSource(stateID: .hidSystemState))
    let event = try #require(
        CGEvent(
            mouseEventSource: source,
            mouseType: .otherMouseDown,
            mouseCursorPosition: CGPoint(x: 120, y: 240),
            mouseButton: .center
        )
    )

    #expect(!SyntheticEventMarker.isMouseButtonReplay(event))

    SyntheticEventMarker.markMouseButtonReplay(event)

    #expect(SyntheticEventMarker.isMouseButtonReplay(event))
}
