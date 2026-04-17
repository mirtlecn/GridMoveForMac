import AppKit
import Foundation

enum LayoutActionExecutionResult {
    case success
    case failure(String)
}

private enum ApplyLayoutSelection {
    case layoutID(String)
    case layoutName(String)
    case layoutIndex(Int)

    func resolveEntry(configuration: AppConfiguration) throws -> ResolvedLayoutEntry? {
        switch self {
        case let .layoutID(layoutID):
            return LayoutGroupResolver.entry(for: layoutID, configuration: configuration)
        case let .layoutName(name):
            return try LayoutGroupResolver.resolveNamedLayout(identifier: name, configuration: configuration)
        case let .layoutIndex(layoutIndex):
            return LayoutGroupResolver.entry(at: layoutIndex, configuration: configuration)
        }
    }

    var missingEntryMessage: String {
        switch self {
        case let .layoutID(layoutID):
            return "No layout found for ID \(layoutID)."
        case let .layoutName(name):
            return "No layout found for name \(name)."
        case let .layoutIndex(layoutIndex):
            return "No layout found at index \(layoutIndex) in the current layout group."
        }
    }

    func missingTargetDisplayMessage(for entry: ResolvedLayoutEntry) -> String {
        switch self {
        case .layoutID:
            return "No target display found for layout \(entry.layout.name)."
        case let .layoutName(name):
            return "No target display found for layout \(name)."
        case let .layoutIndex(layoutIndex):
            return "No target display found for layout index \(layoutIndex)."
        }
    }
}

@MainActor
final class LayoutActionExecutor {
    private let layoutEngine: LayoutEngine
    private let windowController: WindowController
    private let configurationProvider: () -> AppConfiguration
    private let accessibilityAccessValidator: () -> Bool

    init(
        layoutEngine: LayoutEngine,
        windowController: WindowController,
        configurationProvider: @escaping () -> AppConfiguration,
        accessibilityAccessValidator: @escaping () -> Bool
    ) {
        self.layoutEngine = layoutEngine
        self.windowController = windowController
        self.configurationProvider = configurationProvider
        self.accessibilityAccessValidator = accessibilityAccessValidator
    }

    func execute(commandAction: CommandLineAction, targetWindowID: UInt32?) -> LayoutActionExecutionResult {
        let configuration = configurationProvider()

        guard configuration.general.isEnabled else {
            return .failure("GridMove is disabled. Enable app first.")
        }

        guard accessibilityAccessValidator() else {
            return .failure("Accessibility access is required.")
        }

        let resolvedAction: HotkeyAction
        switch commandAction {
        case .help:
            return .success
        case .cycleNext:
            resolvedAction = .cycleNext
        case .cyclePrevious:
            resolvedAction = .cyclePrevious
        case let .applyLayout(identifier):
            do {
                let layout = try LayoutIdentifierResolver.resolveLayout(identifier: identifier, in: configuration)
                resolvedAction = .applyLayoutByID(layoutID: layout.layout.id)
            } catch let error as CommandLineLayoutResolutionError {
                return .failure(error.message)
            } catch {
                return .failure("Failed to resolve layout: \(error.localizedDescription)")
            }
        }

        return execute(hotkeyAction: resolvedAction, targetWindowID: targetWindowID, configuration: configuration)
    }

    func execute(hotkeyAction: HotkeyAction, targetWindowID: UInt32? = nil) -> LayoutActionExecutionResult {
        execute(hotkeyAction: hotkeyAction, targetWindowID: targetWindowID, configuration: configurationProvider())
    }

    func executeFocusedWindowAction(_ hotkeyAction: HotkeyAction, configuration: AppConfiguration) -> LayoutActionExecutionResult {
        execute(hotkeyAction: hotkeyAction, targetWindowID: nil, configuration: configuration)
    }

    private func execute(
        hotkeyAction: HotkeyAction,
        targetWindowID: UInt32?,
        configuration: AppConfiguration
    ) -> LayoutActionExecutionResult {
        guard configuration.general.isEnabled else {
            return .failure("GridMove is disabled. Enable app first.")
        }

        guard accessibilityAccessValidator() else {
            return .failure("Accessibility access is required.")
        }

        guard let window = targetWindow(targetWindowID: targetWindowID, configuration: configuration) else {
            if let targetWindowID {
                return .failure("No target window found for window ID \(targetWindowID).")
            }

            return .failure("No focused target window found.")
        }

        switch hotkeyAction {
        case let .applyLayoutByID(layoutID):
            return executeApplyLayout(
                selection: .layoutID(layoutID),
                to: window,
                configuration: configuration
            )
        case let .applyLayoutByName(name):
            return executeApplyLayout(
                selection: .layoutName(name),
                to: window,
                configuration: configuration
            )
        case let .applyLayoutByIndex(layoutIndex):
            return executeApplyLayout(
                selection: .layoutIndex(layoutIndex),
                to: window,
                configuration: configuration
            )
        case .cycleNext:
            guard let currentScreen = screen(for: window) else {
                return .failure("No display found for the target window.")
            }
            let layouts = LayoutGroupResolver.resolvedLayouts(for: currentScreen, configuration: configuration)
            guard let layoutID = layoutEngine.nextLayoutID(for: window.identity, layouts: layouts) else {
                return .failure("No layout available for cycling.")
            }
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: currentScreen,
                configuration: configuration
            )
            return .success
        case .cyclePrevious:
            guard let currentScreen = screen(for: window) else {
                return .failure("No display found for the target window.")
            }
            let layouts = LayoutGroupResolver.resolvedLayouts(for: currentScreen, configuration: configuration)
            guard let layoutID = layoutEngine.previousLayoutID(for: window.identity, layouts: layouts) else {
                return .failure("No layout available for cycling.")
            }
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: currentScreen,
                configuration: configuration
            )
            return .success
        }
    }

    private func targetWindow(targetWindowID: UInt32?, configuration: AppConfiguration) -> ManagedWindow? {
        if let targetWindowID {
            return windowController.window(cgWindowID: targetWindowID, configuration: configuration)
        }

        return windowController.windowForLayoutAction(configuration: configuration)
    }

    private func executeApplyLayout(
        selection: ApplyLayoutSelection,
        to window: ManagedWindow,
        configuration: AppConfiguration
    ) -> LayoutActionExecutionResult {
        let currentScreen = screen(for: window)
        let entry: ResolvedLayoutEntry
        do {
            guard let resolvedEntry = try selection.resolveEntry(configuration: configuration) else {
                return .failure(selection.missingEntryMessage)
            }
            entry = resolvedEntry
        } catch let error as CommandLineLayoutResolutionError {
            return .failure(error.message)
        } catch {
            return .failure("Failed to resolve layout: \(error.localizedDescription)")
        }

        guard let targetScreen = LayoutGroupResolver.targetScreen(
            for: entry,
            currentScreen: currentScreen,
            configuration: configuration
        ) else {
            return .failure(selection.missingTargetDisplayMessage(for: entry))
        }

        windowController.applyLayout(
            layoutID: entry.layout.id,
            to: window,
            preferredScreen: targetScreen,
            configuration: configuration
        )
        return .success
    }

    private func screen(for window: ManagedWindow) -> NSScreen? {
        windowController.screenContaining(point: CGPoint(x: window.frame.midX, y: window.frame.midY))
    }
}
