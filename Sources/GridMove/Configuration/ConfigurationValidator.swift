import Foundation

enum ConfigurationFileError: Error, Equatable {
    case invalidLayoutReference(Int)
    case missingActiveLayoutGroup(String)
    case duplicateLayoutGroupName
    case overlappingMonitorBindings(String)
    case embeddedLayoutGroupsNotSupported
}

enum ConfigurationValidator {
    static func validate(_ configuration: AppConfiguration) throws {
        guard configuration.layoutGroups.contains(where: { $0.name == configuration.general.activeLayoutGroup }) else {
            throw ConfigurationFileError.missingActiveLayoutGroup(configuration.general.activeLayoutGroup)
        }

        let groupNames = configuration.layoutGroups.map(\.name)
        guard Set(groupNames).count == groupNames.count else {
            throw ConfigurationFileError.duplicateLayoutGroupName
        }

        for group in configuration.layoutGroups {
            var explicitDisplayIDs: Set<String> = []
            var hasMainSet = false
            var hasAllSet = false

            for set in group.sets {
                switch set.monitor {
                case .all:
                    guard !hasAllSet else {
                        throw ConfigurationFileError.overlappingMonitorBindings(group.name)
                    }
                    hasAllSet = true
                case .main:
                    guard !hasMainSet else {
                        throw ConfigurationFileError.overlappingMonitorBindings(group.name)
                    }
                    hasMainSet = true
                case let .displays(displayIDs):
                    for displayID in displayIDs {
                        let canonicalDisplayID = configuration.monitors[displayID] ?? displayID
                        guard !explicitDisplayIDs.contains(canonicalDisplayID) else {
                            throw ConfigurationFileError.overlappingMonitorBindings(group.name)
                        }
                        explicitDisplayIDs.insert(canonicalDisplayID)
                    }
                }
            }
        }
    }
}
