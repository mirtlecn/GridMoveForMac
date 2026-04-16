import Foundation

@MainActor
final class CommandLineRunner {
    private let commandRelay: RemoteCommandRelaying

    init(commandRelay: RemoteCommandRelaying = DistributedCommandRelay()) {
        self.commandRelay = commandRelay
    }

    func run(invocation: CommandLineInvocation) -> Int32 {
        if invocation.action == .help {
            writeToStandardOutput(CommandLineAction.usage + "\n")
            return EXIT_SUCCESS
        }

        let command = RemoteCommand(
            invocationID: UUID().uuidString,
            action: invocation.action,
            targetWindowID: invocation.targetWindowID
        )

        guard let reply = commandRelay.send(command: command, timeout: 1.0) else {
            writeToStandardError("GridMove is not running. Start GridMove first.\n")
            return EXIT_FAILURE
        }

        if reply.success {
            return EXIT_SUCCESS
        }

        writeToStandardError((reply.message ?? "GridMove command failed.") + "\n")
        return EXIT_FAILURE
    }

    private func writeToStandardOutput(_ message: String) {
        FileHandle.standardOutput.write(Data(message.utf8))
    }

    private func writeToStandardError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}
