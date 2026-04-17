import Foundation

struct CommandLineInvocation: Equatable {
    var action: CommandLineAction
    var targetWindowID: UInt32?

    static func parse(arguments: [String]) throws -> CommandLineInvocation? {
        let filteredArguments = arguments.filter { !$0.hasPrefix("-psn_") }
        guard !filteredArguments.isEmpty else {
            return nil
        }

        var remainingArguments = filteredArguments[...]
        let action = try CommandLineAction.parse(arguments: &remainingArguments)
        let targetWindowID = try parseWindowID(arguments: &remainingArguments)

        guard remainingArguments.isEmpty else {
            throw CommandLineActionError.unexpectedArguments(Array(remainingArguments))
        }

        return CommandLineInvocation(action: action, targetWindowID: targetWindowID)
    }

    private static func parseWindowID(arguments: inout ArraySlice<String>) throws -> UInt32? {
        guard let firstArgument = arguments.first else {
            return nil
        }

        guard firstArgument == "-window-id" else {
            return nil
        }

        arguments = arguments.dropFirst()
        guard let value = arguments.first else {
            throw CommandLineActionError.missingWindowIdentifier
        }

        arguments = arguments.dropFirst()
        guard let parsedWindowID = UInt32(value) else {
            throw CommandLineActionError.invalidWindowIdentifier(value)
        }

        return parsedWindowID
    }
}

enum CommandLineAction: Equatable {
    case help
    case cycleNext
    case cyclePrevious
    case applyLayout(identifier: String)

    fileprivate static func parse(arguments: inout ArraySlice<String>) throws -> CommandLineAction {
        guard let firstArgument = arguments.first else {
            throw CommandLineActionError.missingAction
        }

        arguments = arguments.dropFirst()

        switch firstArgument {
        case "-help", "--help":
            return .help
        case "-next":
            return .cycleNext
        case "-pre", "-prev":
            return .cyclePrevious
        case "-layout":
            guard let identifier = arguments.first, !identifier.isEmpty else {
                throw CommandLineActionError.missingLayoutIdentifier
            }
            arguments = arguments.dropFirst()
            return .applyLayout(identifier: identifier)
        default:
            throw CommandLineActionError.unknownArgument(firstArgument)
        }
    }

    static let usage = """
    Usage:
      GridMove -next [-window-id <cg-window-id>]
      GridMove -pre [-window-id <cg-window-id>]
      GridMove -layout <layout-index-or-name> [-window-id <cg-window-id>]
      GridMove -help
    """
}

enum CommandLineActionError: Error, Equatable {
    case missingAction
    case unknownArgument(String)
    case missingLayoutIdentifier
    case missingWindowIdentifier
    case invalidWindowIdentifier(String)
    case unexpectedArguments([String])

    var message: String {
        switch self {
        case .missingAction:
            return "Missing action."
        case let .unknownArgument(argument):
            return "Unknown argument: \(argument)"
        case .missingLayoutIdentifier:
            return "Missing layout identifier after -layout."
        case .missingWindowIdentifier:
            return "Missing window identifier after -window-id."
        case let .invalidWindowIdentifier(value):
            return "Invalid window identifier: \(value)"
        case let .unexpectedArguments(arguments):
            return "Unexpected arguments: \(arguments.joined(separator: " "))"
        }
    }
}
