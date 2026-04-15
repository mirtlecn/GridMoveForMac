import Foundation

enum CommandLineAction: Equatable {
    case help
    case cycleNext
    case cyclePrevious
    case applyLayout(identifier: String)

    static func parse(arguments: [String]) throws -> CommandLineAction? {
        let filteredArguments = arguments.filter { !$0.hasPrefix("-psn_") }
        guard let firstArgument = filteredArguments.first else {
            return nil
        }

        switch firstArgument {
        case "-help", "--help":
            return .help
        case "-next":
            guard filteredArguments.count == 1 else {
                throw CommandLineActionError.unexpectedArguments(filteredArguments.dropFirst().map(\.self))
            }
            return .cycleNext
        case "-pre", "-prev":
            guard filteredArguments.count == 1 else {
                throw CommandLineActionError.unexpectedArguments(filteredArguments.dropFirst().map(\.self))
            }
            return .cyclePrevious
        case "-layout":
            guard filteredArguments.count >= 2 else {
                throw CommandLineActionError.missingLayoutIdentifier
            }

            let identifier = filteredArguments[1]
            guard !identifier.isEmpty else {
                throw CommandLineActionError.missingLayoutIdentifier
            }

            guard filteredArguments.count == 2 else {
                throw CommandLineActionError.unexpectedArguments(filteredArguments.dropFirst(2).map(\.self))
            }

            return .applyLayout(identifier: identifier)
        default:
            throw CommandLineActionError.unknownArgument(firstArgument)
        }
    }

    static let usage = """
    Usage:
      GridMove -next
      GridMove -pre
      GridMove -layout <layout-name-or-id>
      GridMove -help
    """
}

enum CommandLineActionError: Error, Equatable {
    case unknownArgument(String)
    case missingLayoutIdentifier
    case unexpectedArguments([String])

    var message: String {
        switch self {
        case let .unknownArgument(argument):
            return "Unknown argument: \(argument)"
        case .missingLayoutIdentifier:
            return "Missing layout identifier after -layout."
        case let .unexpectedArguments(arguments):
            return "Unexpected arguments: \(arguments.joined(separator: " "))"
        }
    }
}
