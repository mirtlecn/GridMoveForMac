import CoreGraphics
import Foundation

enum SyntheticEventMarker {
    static let mouseButtonReplayTag: Int64 = 0x47524D4D

    static func markMouseButtonReplay(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: mouseButtonReplayTag)
    }

    static func isMouseButtonReplay(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == mouseButtonReplayTag
    }
}
