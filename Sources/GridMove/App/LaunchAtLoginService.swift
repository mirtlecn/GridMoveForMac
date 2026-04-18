import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
}

protocol LaunchAtLoginServiceProtocol {
    func status() -> LaunchAtLoginStatus
    func register() throws -> LaunchAtLoginStatus
    func unregister() throws -> LaunchAtLoginStatus
}

struct SMAppLaunchAtLoginService: LaunchAtLoginServiceProtocol {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    func status() -> LaunchAtLoginStatus {
        switch service.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return .disabled
        @unknown default:
            return .disabled
        }
    }

    func register() throws -> LaunchAtLoginStatus {
        try service.register()
        return status()
    }

    func unregister() throws -> LaunchAtLoginStatus {
        try service.unregister()
        return status()
    }
}
