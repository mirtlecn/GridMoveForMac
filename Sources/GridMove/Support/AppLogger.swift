import OSLog

enum AppLogger {
    static let shared = Logger(subsystem: "GridMove", category: "App")
    static let targeting = Logger(subsystem: "GridMove", category: "Targeting")

    static func debugTargeting(_ message: @autoclosure () -> String) {
        let resolvedMessage = message()
        targeting.debug("\(resolvedMessage, privacy: .public)")
    }
}
