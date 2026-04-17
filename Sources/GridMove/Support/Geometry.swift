import AppKit
import CoreGraphics
import Foundation

enum Geometry {
    static func appKitPoint(fromQuartzPoint point: CGPoint, mainDisplayHeight: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x,
            y: mainDisplayHeight - point.y
        )
    }

    static func quartzPoint(fromAppKitPoint point: CGPoint, mainDisplayHeight: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x,
            y: mainDisplayHeight - point.y
        )
    }

    static func appKitRect(fromQuartzRect rect: CGRect, mainDisplayHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: mainDisplayHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func quartzRect(fromAppKitRect rect: CGRect, mainDisplayHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: mainDisplayHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt(dx * dx + dy * dy)
    }

    static func point(_ point: CGPoint, inside rect: CGRect) -> Bool {
        rect.contains(point)
    }

    static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 8) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= tolerance
            && abs(lhs.origin.y - rhs.origin.y) <= tolerance
            && abs(lhs.size.width - rhs.size.width) <= tolerance
            && abs(lhs.size.height - rhs.size.height) <= tolerance
    }

    static func cgDisplayID(for screen: NSScreen) -> CGDirectDisplayID? {
        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return CGDirectDisplayID(screenNumber.uint32Value)
        }

        if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 {
            return CGDirectDisplayID(screenNumber)
        }

        return nil
    }

    static func screenIdentifier(for screen: NSScreen) -> String {
        if let displayID = cgDisplayID(for: screen) {
            if let uuid = stableDisplayUUID(for: displayID) {
                return uuid
            }

            if let fingerprint = displayFingerprint(for: displayID) {
                return fingerprint
            }
        }

        let frame = screen.frame
        return "\(frame.origin.x),\(frame.origin.y),\(frame.width),\(frame.height)"
    }

    static func stableDisplayUUID(for displayID: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return nil
        }

        return (CFUUIDCreateString(nil, uuid) as String?)?.lowercased()
    }

    static func displayFingerprint(for displayID: CGDirectDisplayID) -> String? {
        displayFingerprint(
            vendorID: CGDisplayVendorNumber(displayID),
            modelID: CGDisplayModelNumber(displayID),
            serialNumber: CGDisplaySerialNumber(displayID)
        )
    }

    static func displayFingerprint(vendorID: UInt32, modelID: UInt32, serialNumber: UInt32) -> String? {
        guard vendorID != 0 || modelID != 0 || serialNumber != 0 else {
            return nil
        }

        return "fallback:\(vendorID)-\(modelID)-\(serialNumber)"
    }
}
