import Foundation

enum CommandLineLayoutResolutionError: Error, Equatable {
    case unknownLayout(String)
    case ambiguousLayoutName(String, matches: [LayoutPreset])
    case invalidLayoutIndex(String)

    var message: String {
        switch self {
        case let .unknownLayout(identifier):
            return "Unknown layout: \(identifier)"
        case let .ambiguousLayoutName(identifier, matches):
            let matchList = matches.map { "- \($0.name)" }.joined(separator: "\n")
            return """
            Ambiguous layout name: \(identifier)
            Matched layouts:
            \(matchList)
            Please use -layout <layout-index>.
            """
        case let .invalidLayoutIndex(value):
            return "Unknown layout index: \(value)"
        }
    }
}

enum LayoutIdentifierResolver {
    static func resolveLayout(identifier: String, in configuration: AppConfiguration) throws -> ResolvedLayoutEntry {
        if let numericIndex = parseLayoutIndex(from: identifier) {
            guard let entry = LayoutGroupResolver.entry(at: numericIndex, configuration: configuration) else {
                throw CommandLineLayoutResolutionError.invalidLayoutIndex(identifier)
            }
            return entry
        }
        return try LayoutGroupResolver.resolveNamedLayout(identifier: identifier, configuration: configuration)
    }

    static func resolveLayout(identifier: String, in layouts: [LayoutPreset]) throws -> LayoutPreset {
        if let numericIndex = parseLayoutIndex(from: identifier) {
            guard numericIndex >= 1, numericIndex <= layouts.count else {
                throw CommandLineLayoutResolutionError.invalidLayoutIndex(identifier)
            }
            return layouts[numericIndex - 1]
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

    private static func parseLayoutIndex(from identifier: String) -> Int? {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else {
            return nil
        }

        let digits = CharacterSet.decimalDigits
        guard trimmedIdentifier.unicodeScalars.allSatisfy(digits.contains) else {
            return nil
        }

        return Int(trimmedIdentifier)
    }
}
