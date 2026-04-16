import Foundation

struct RemoteCommand {
    let invocationID: String
    let action: CommandLineAction
    let targetWindowID: UInt32?
}

struct RemoteCommandReply {
    let success: Bool
    let message: String?
}

protocol RemoteCommandRelaying {
    func send(command: RemoteCommand, timeout: TimeInterval) -> RemoteCommandReply?
}

final class DistributedCommandRelay: RemoteCommandRelaying {
    private static let commandNotification = Notification.Name("GridMove.RemoteCommand")
    private static let replyNotification = Notification.Name("GridMove.RemoteCommandReply")

    private let center = DistributedNotificationCenter.default()
    private var observer: NSObjectProtocol?

    func startListening(handler: @escaping @Sendable (RemoteCommand) -> RemoteCommandReply) {
        stopListening()
        let center = self.center
        observer = center.addObserver(
            forName: Self.commandNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let command = Self.command(from: notification) else {
                return
            }

            let reply = handler(command)
            Self.postReply(reply, for: command.invocationID, center: center)
        }
    }

    func stopListening() {
        if let observer {
            center.removeObserver(observer)
            self.observer = nil
        }
    }

    func send(command: RemoteCommand, timeout: TimeInterval = 1.0) -> RemoteCommandReply? {
        let replyBox = LockedValue<RemoteCommandReply?>(nil)
        let observer = center.addObserver(
            forName: Self.replyNotification,
            object: command.invocationID,
            queue: .main
        ) { notification in
            replyBox.withLock { reply in
                reply = Self.reply(from: notification)
            }
        }

        defer {
            center.removeObserver(observer)
        }

        center.postNotificationName(
            Self.commandNotification,
            object: nil,
            userInfo: Self.userInfo(for: command),
            options: [.deliverImmediately]
        )

        let deadline = Date().addingTimeInterval(timeout)
        while replyBox.withLock({ $0 }) == nil && RunLoop.current.run(mode: .default, before: deadline) && Date() < deadline {
        }

        return replyBox.withLock { $0 }
    }

    private static func postReply(_ reply: RemoteCommandReply, for invocationID: String, center: DistributedNotificationCenter) {
        var userInfo: [AnyHashable: Any] = ["success": reply.success]
        if let message = reply.message {
            userInfo["message"] = message
        }

        center.postNotificationName(
            Self.replyNotification,
            object: invocationID,
            userInfo: userInfo,
            options: [.deliverImmediately]
        )
    }

    private static func userInfo(for command: RemoteCommand) -> [AnyHashable: Any] {
        var result: [AnyHashable: Any] = [
            "invocationID": command.invocationID,
        ]

        switch command.action {
        case .help:
            result["action"] = "help"
        case .cycleNext:
            result["action"] = "cycleNext"
        case .cyclePrevious:
            result["action"] = "cyclePrevious"
        case let .applyLayout(identifier):
            result["action"] = "applyLayout"
            result["layoutIdentifier"] = identifier
        }

        if let targetWindowID = command.targetWindowID {
            result["targetWindowID"] = NSNumber(value: targetWindowID)
        }

        return result
    }

    private static func command(from notification: Notification) -> RemoteCommand? {
        guard
            let userInfo = notification.userInfo,
            let invocationID = userInfo["invocationID"] as? String,
            let actionValue = userInfo["action"] as? String
        else {
            return nil
        }

        let action: CommandLineAction
        switch actionValue {
        case "help":
            action = .help
        case "cycleNext":
            action = .cycleNext
        case "cyclePrevious":
            action = .cyclePrevious
        case "applyLayout":
            guard let identifier = userInfo["layoutIdentifier"] as? String else {
                return nil
            }
            action = .applyLayout(identifier: identifier)
        default:
            return nil
        }

        let targetWindowID = (userInfo["targetWindowID"] as? NSNumber)?.uint32Value
        return RemoteCommand(invocationID: invocationID, action: action, targetWindowID: targetWindowID)
    }

    private static func reply(from notification: Notification) -> RemoteCommandReply? {
        guard let userInfo = notification.userInfo,
              let success = userInfo["success"] as? Bool
        else {
            return nil
        }

        return RemoteCommandReply(
            success: success,
            message: userInfo["message"] as? String
        )
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
