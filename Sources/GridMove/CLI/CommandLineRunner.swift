import AppKit
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

@MainActor
final class CommandLineRunner {
    private let configurationStore: ConfigurationStore
    private let layoutEngine: LayoutEngine
    private let windowController: WindowController

    init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        layoutEngine: LayoutEngine = LayoutEngine(),
        windowController: WindowController? = nil
    ) {
        self.configurationStore = configurationStore
        self.layoutEngine = layoutEngine
        self.windowController = windowController ?? WindowController(layoutEngine: layoutEngine)
    }

    func run(action: CommandLineAction) -> Int32 {
        let configuration: AppConfiguration
        do {
            configuration = try configurationStore.load()
        } catch {
            writeToStandardError("Failed to load configuration: \(error.localizedDescription)\n")
            return EXIT_FAILURE
        }

        switch action {
        case .help:
            writeToStandardOutput(CommandLineAction.usage + "\n")
            return EXIT_SUCCESS
        case .cycleNext, .cyclePrevious, .applyLayout:
            break
        }

        guard configuration.general.isEnabled else {
            writeToStandardError("GridMove is disabled. Enable it from the menu bar or Settings.\n")
            return EXIT_FAILURE
        }

        guard windowController.isAccessibilityTrusted(prompt: false) else {
            writeToStandardError("Accessibility access is required.\n")
            return EXIT_FAILURE
        }

        guard let window = windowController.windowForLayoutAction(configuration: configuration) else {
            writeToStandardError("No target window found.\n")
            return EXIT_FAILURE
        }

        let layoutID: String
        switch action {
        case .cycleNext:
            guard let nextLayoutID = layoutEngine.nextLayoutID(for: window.identity, layouts: configuration.layouts) else {
                writeToStandardError("No layout available for cycling.\n")
                return EXIT_FAILURE
            }
            layoutID = nextLayoutID
        case .cyclePrevious:
            guard let previousLayoutID = layoutEngine.previousLayoutID(for: window.identity, layouts: configuration.layouts) else {
                writeToStandardError("No layout available for cycling.\n")
                return EXIT_FAILURE
            }
            layoutID = previousLayoutID
        case let .applyLayout(identifier):
            let layout: LayoutPreset
            do {
                layout = try resolveLayout(identifier: identifier, in: configuration.layouts)
            } catch let error as CommandLineLayoutResolutionError {
                writeToStandardError(error.message + "\n")
                return EXIT_FAILURE
            } catch {
                writeToStandardError("Failed to resolve layout: \(error.localizedDescription)\n")
                return EXIT_FAILURE
            }
            layoutID = layout.id
        case .help:
            return EXIT_SUCCESS
        }

        windowController.applyLayout(
            layoutID: layoutID,
            to: window,
            preferredScreen: nil,
            configuration: configuration
        )

        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        return EXIT_SUCCESS
    }

    func resolveLayout(identifier: String, in layouts: [LayoutPreset]) throws -> LayoutPreset {
        if let layoutByID = layouts.first(where: { $0.id.caseInsensitiveCompare(identifier) == .orderedSame }) {
            return layoutByID
        }

        let matchedLayouts = layouts.filter { $0.name.caseInsensitiveCompare(identifier) == .orderedSame }
        if let matchedLayout = matchedLayouts.onlyElement {
            return matchedLayout
        }
        if !matchedLayouts.isEmpty {
            throw CommandLineLayoutResolutionError.ambiguousLayoutName(identifier, matches: matchedLayouts)
        }

        throw CommandLineLayoutResolutionError.unknownLayout(identifier)
    }

    private func writeToStandardOutput(_ message: String) {
        FileHandle.standardOutput.write(Data(message.utf8))
    }

    private func writeToStandardError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}

private extension Collection {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
