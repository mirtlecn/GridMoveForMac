import AppKit
import Foundation

enum LayoutActionExecutionResult {
    case success
    case failure(String)
}

@MainActor
final class LayoutActionExecutor {
    private let layoutEngine: LayoutEngine
    private let windowController: WindowController
    private let configurationProvider: () -> AppConfiguration

    init(
        layoutEngine: LayoutEngine,
        windowController: WindowController,
        configurationProvider: @escaping () -> AppConfiguration
    ) {
        self.layoutEngine = layoutEngine
        self.windowController = windowController
        self.configurationProvider = configurationProvider
    }

    func execute(commandAction: CommandLineAction, targetWindowID: UInt32?) -> LayoutActionExecutionResult {
        let configuration = configurationProvider()

        guard configuration.general.isEnabled else {
            return .failure("GridMove is disabled. Enable app first.")
        }

        guard windowController.isAccessibilityTrusted(prompt: false) else {
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
                let layout = try LayoutIdentifierResolver.resolveLayout(identifier: identifier, in: configuration.layouts)
                resolvedAction = .applyLayout(layoutID: layout.id)
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

        guard let window = targetWindow(targetWindowID: targetWindowID, configuration: configuration) else {
            if let targetWindowID {
                return .failure("No target window found for window ID \(targetWindowID).")
            }

            return .failure("No focused target window found.")
        }

        switch hotkeyAction {
        case let .applyLayout(layoutID):
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: nil,
                configuration: configuration
            )
            return .success
        case .cycleNext:
            guard let layoutID = layoutEngine.nextLayoutID(for: window.identity, layouts: configuration.layouts) else {
                return .failure("No layout available for cycling.")
            }
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: nil,
                configuration: configuration
            )
            return .success
        case .cyclePrevious:
            guard let layoutID = layoutEngine.previousLayoutID(for: window.identity, layouts: configuration.layouts) else {
                return .failure("No layout available for cycling.")
            }
            windowController.applyLayout(
                layoutID: layoutID,
                to: window,
                preferredScreen: nil,
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
}
