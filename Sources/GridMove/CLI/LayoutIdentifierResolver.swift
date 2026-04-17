import Foundation

enum CommandLineLayoutResolutionError: Error, Equatable {
    case unknownLayout(String)
    case ambiguousLayoutName(String, matches: [LayoutPreset])

    var message: String {
        switch self {
        case let .unknownLayout(identifier):
            return "Unknown layout: \(identifier)"
        case let .ambiguousLayoutName(identifier, matches):
            let matchList = matches.map { "- \($0.name) [\($0.id)]" }.joined(separator: "\n")
            return """
            Ambiguous layout name: \(identifier)
            Matched layouts:
            \(matchList)
            Please use -layout <layout-id>.
            """
        }
    }
}

enum LayoutIdentifierResolver {
    static func resolveLayout(identifier: String, in configuration: AppConfiguration) throws -> ResolvedLayoutEntry {
        try LayoutGroupResolver.resolveNamedLayout(identifier: identifier, configuration: configuration)
    }

    static func resolveLayout(identifier: String, in layouts: [LayoutPreset]) throws -> LayoutPreset {
        if let layoutByID = layouts.first(where: { $0.id.caseInsensitiveCompare(identifier) == .orderedSame }) {
            return layoutByID
        }

        let matchedLayouts = layouts.filter { $0.name.caseInsensitiveCompare(identifier) == .orderedSame }
        if matchedLayouts.count == 1, let matchedLayout = matchedLayouts.first {
            return matchedLayout
        }
        if !matchedLayouts.isEmpty {
            throw CommandLineLayoutResolutionError.ambiguousLayoutName(identifier, matches: matchedLayouts)
        }

        throw CommandLineLayoutResolutionError.unknownLayout(identifier)
    }
}
