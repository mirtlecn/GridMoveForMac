import CoreGraphics
import Foundation

enum SyntheticEventMarker {
    static let middleMouseReplayTag: Int64 = 0x47524D4D

    static func markMiddleMouseReplay(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: middleMouseReplayTag)
    }

    static func isMiddleMouseReplay(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == middleMouseReplayTag
    }
}
