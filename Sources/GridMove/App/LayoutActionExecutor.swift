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
                resolvedAction = .applyLayoutByName(name: layout.layout.name)
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
            let currentScreen = screen(for: window)
            guard let entry = LayoutGroupResolver.entry(for: layoutID, configuration: configuration) else {
                return .failure("No layout found for ID \(layoutID).")
            }
            guard let targetScreen = LayoutGroupResolver.targetScreen(for: entry, currentScreen: currentScreen, configuration: configuration) else {
                return .failure("No target display found for layout \(entry.layout.name).")
            }
            windowController.applyLayout(
                layoutID: entry.layout.id,
                to: window,
                preferredScreen: targetScreen,
                configuration: configuration
            )
            return .success
        case let .applyLayoutByName(name):
            let currentScreen = screen(for: window)
            guard let entry = try? LayoutGroupResolver.resolveNamedLayout(identifier: name, configuration: configuration) else {
                return .failure("No layout named \(name).")
            }
            guard let targetScreen = LayoutGroupResolver.targetScreen(for: entry, currentScreen: currentScreen, configuration: configuration) else {
                return .failure("No target display found for layout \(name).")
            }
            windowController.applyLayout(
                layoutID: entry.layout.id,
                to: window,
                preferredScreen: targetScreen,
                configuration: configuration
            )
            return .success
        case let .applyLayoutByIndex(layoutIndex):
            let currentScreen = screen(for: window)
            guard let currentScreen else {
                return .failure("No display found for the target window.")
            }
            guard let entry = LayoutGroupResolver.entry(at: layoutIndex, on: currentScreen, configuration: configuration) else {
                return .failure("No layout found at index \(layoutIndex) for the current display.")
            }
            windowController.applyLayout(
                layoutID: entry.layout.id,
                to: window,
                preferredScreen: currentScreen,
                configuration: configuration
            )
            return .success
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

    private func screen(for window: ManagedWindow) -> NSScreen? {
        windowController.screenContaining(point: CGPoint(x: window.frame.midX, y: window.frame.midY))
    }
}
