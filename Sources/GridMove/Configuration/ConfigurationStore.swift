import Foundation

enum ConfigurationLoadSource: Equatable {
    case persistedConfiguration
    case lastKnownGood
    case builtInDefault
}

struct ConfigurationLoadDiagnostic: Equatable {
    let fileURL: URL
    let message: String
    let line: Int?
    let column: Int?
    let codingPath: [String]

    var codingPathDescription: String? {
        let path = codingPath.joined(separator: ".")
        return path.isEmpty ? nil : path
    }
}

struct LayoutFileDiagnostic: Equatable {
    let fileURL: URL
    let message: String
    let line: Int?
    let column: Int?
    let codingPath: [String]

    var codingPathDescription: String? {
        let path = codingPath.joined(separator: ".")
        return path.isEmpty ? nil : path
    }
}

final class ConfigurationStore {
    struct LoadResult {
        let configuration: AppConfiguration
        let source: ConfigurationLoadSource
        let diagnostic: ConfigurationLoadDiagnostic?
        let skippedLayoutDiagnostics: [LayoutFileDiagnostic]
    }

    private struct LoadedSnapshot {
        let configuration: AppConfiguration
        let skippedLayoutDiagnostics: [LayoutFileDiagnostic]
    }

    private struct DiagnosticComponents {
        let message: String
        let line: Int?
        let column: Int?
        let codingPath: [String]
    }

    private struct LayoutFileMatch {
        let index: Int
        let fileURL: URL
    }

    private struct ConfigurationSnapshotLoadError: Error {
        let diagnostic: ConfigurationLoadDiagnostic
        let skippedLayoutDiagnostics: [LayoutFileDiagnostic]
    }

    private let fileManager: FileManager
    let directoryURL: URL
    let fileURL: URL
    let layoutDirectoryURL: URL
    let lastKnownGoodFileURL: URL
    let lastKnownGoodLayoutDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let baseURL = baseDirectoryURL
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("GridMove", isDirectory: true)
        directoryURL = baseURL
        fileURL = baseURL.appendingPathComponent("config.json")
        layoutDirectoryURL = baseURL.appendingPathComponent("layout", isDirectory: true)
        lastKnownGoodFileURL = baseURL.appendingPathComponent("config.last-known-good.json")
        lastKnownGoodLayoutDirectoryURL = baseURL.appendingPathComponent("layout.last-known-good", isDirectory: true)
    }

    func load() throws -> AppConfiguration {
        try loadWithStatus().configuration
    }

    func loadWithStatus() throws -> LoadResult {
        try ensureBaseDirectoryExists()

        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let snapshot = try loadConfigurationSnapshot(
                    configurationFileURL: fileURL,
                    layoutDirectoryURL: layoutDirectoryURL,
                    failureDiagnosticFileURL: fileURL
                )
                return LoadResult(
                    configuration: snapshot.configuration,
                    source: .persistedConfiguration,
                    diagnostic: nil,
                    skippedLayoutDiagnostics: snapshot.skippedLayoutDiagnostics
                )
            } catch let error as ConfigurationSnapshotLoadError {
                AppLogger.shared.error("Failed to load configuration from \(self.fileURL.path, privacy: .public): \(error.diagnostic.message, privacy: .public)")

                if fileManager.fileExists(atPath: lastKnownGoodFileURL.path) {
                    do {
                        let recoverySnapshot = try loadConfigurationSnapshot(
                            configurationFileURL: lastKnownGoodFileURL,
                            layoutDirectoryURL: lastKnownGoodLayoutDirectoryURL,
                            failureDiagnosticFileURL: lastKnownGoodFileURL
                        )
                        return LoadResult(
                            configuration: recoverySnapshot.configuration,
                            source: .lastKnownGood,
                            diagnostic: error.diagnostic,
                            skippedLayoutDiagnostics: error.skippedLayoutDiagnostics
                        )
                    } catch {
                        AppLogger.shared.error("Failed to load last-known-good configuration from \(self.lastKnownGoodFileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }

                return LoadResult(
                    configuration: .defaultValue,
                    source: .builtInDefault,
                    diagnostic: error.diagnostic,
                    skippedLayoutDiagnostics: error.skippedLayoutDiagnostics
                )
            }
        }

        let configuration = AppConfiguration.defaultValue
        try save(configuration)
        return LoadResult(
            configuration: configuration,
            source: .persistedConfiguration,
            diagnostic: nil,
            skippedLayoutDiagnostics: []
        )
    }

    func save(_ configuration: AppConfiguration) throws {
        try ensureBaseDirectoryExists()
        let snapshot = try ConfigurationSchemaConverter.makePersistedConfigurationSnapshot(from: configuration)
        try writeSnapshot(
            snapshot,
            configurationFileURL: fileURL,
            layoutDirectoryURL: layoutDirectoryURL
        )
        do {
            try writeSnapshot(
                snapshot,
                configurationFileURL: lastKnownGoodFileURL,
                layoutDirectoryURL: lastKnownGoodLayoutDirectoryURL
            )
        } catch {
            AppLogger.shared.error("Failed to update last-known-good configuration at \(self.lastKnownGoodFileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func ensureBaseDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func loadConfigurationSnapshot(
        configurationFileURL: URL,
        layoutDirectoryURL: URL,
        failureDiagnosticFileURL: URL
    ) throws -> LoadedSnapshot {
        let configurationData = try Data(contentsOf: configurationFileURL)
        let configurationFile: ConfigurationFile
        do {
            configurationFile = try decodeConfigurationFile(from: configurationData)
        } catch {
            throw ConfigurationSnapshotLoadError(
                diagnostic: makeConfigurationLoadDiagnostic(
                    for: error,
                    fileURL: configurationFileURL,
                    data: configurationData
                ),
                skippedLayoutDiagnostics: []
            )
        }

        let layoutLoadResult = loadLayoutGroups(from: layoutDirectoryURL)

        do {
            let configuration = try ConfigurationSchemaConverter.makeAppConfiguration(
                from: configurationFile,
                layoutGroups: layoutLoadResult.layoutGroups
            )
            return LoadedSnapshot(
                configuration: configuration,
                skippedLayoutDiagnostics: layoutLoadResult.skippedLayoutDiagnostics
            )
        } catch {
            throw ConfigurationSnapshotLoadError(
                diagnostic: makeConfigurationLoadDiagnostic(
                    for: error,
                    fileURL: failureDiagnosticFileURL,
                    data: Data()
                ),
                skippedLayoutDiagnostics: layoutLoadResult.skippedLayoutDiagnostics
            )
        }
    }

    private func loadLayoutGroups(from directoryURL: URL) -> (layoutGroups: [LayoutGroupConfiguration], skippedLayoutDiagnostics: [LayoutFileDiagnostic]) {
        let layoutFiles = managedLayoutFiles(in: directoryURL)
        var decodedLayoutGroups: [LayoutGroupConfiguration] = []
        var skippedDiagnostics: [LayoutFileDiagnostic] = []

        for layoutFile in layoutFiles {
            do {
                let data = try Data(contentsOf: layoutFile.fileURL)
                let layoutGroup: LayoutGroupConfiguration
                do {
                    layoutGroup = try decodeLayoutGroup(from: data)
                } catch {
                    let diagnostic = makeLayoutFileDiagnostic(
                        for: error,
                        fileURL: layoutFile.fileURL,
                        data: data
                    )
                    skippedDiagnostics.append(diagnostic)
                    AppLogger.shared.error("Skipped invalid layout file \(layoutFile.fileURL.lastPathComponent, privacy: .public): \(diagnostic.message, privacy: .public)")
                    continue
                }
                decodedLayoutGroups.append(layoutGroup)
            } catch {
                let diagnostic = makeLayoutFileDiagnostic(
                    for: error,
                    fileURL: layoutFile.fileURL,
                    data: Data()
                )
                skippedDiagnostics.append(diagnostic)
                AppLogger.shared.error("Skipped invalid layout file \(layoutFile.fileURL.lastPathComponent, privacy: .public): \(diagnostic.message, privacy: .public)")
            }
        }

        return (decodedLayoutGroups, skippedDiagnostics)
    }

    private func writeSnapshot(
        _ snapshot: PersistedConfigurationSnapshot,
        configurationFileURL: URL,
        layoutDirectoryURL: URL
    ) throws {
        let encoder = makeEncoder()
        let configurationData = try encoder.encode(snapshot.configurationFile)
        let layoutFiles = try snapshot.layoutGroups.enumerated().map { offset, layoutGroup in
            let fileURL = layoutDirectoryURL.appendingPathComponent("\(offset + 1).grid.json")
            return (fileURL: fileURL, data: try encoder.encode(layoutGroup))
        }

        try fileManager.createDirectory(at: layoutDirectoryURL, withIntermediateDirectories: true)
        let layoutBackupDirectoryURL = directoryURL
            .appendingPathComponent(".layout-backup-\(UUID().uuidString)", isDirectory: true)
        let configurationBackupURL = directoryURL
            .appendingPathComponent(".config-backup-\(UUID().uuidString)")
        let existingManagedFiles = managedLayoutFiles(in: layoutDirectoryURL)
        let hadExistingConfiguration = fileManager.fileExists(atPath: configurationFileURL.path)

        try fileManager.createDirectory(at: layoutBackupDirectoryURL, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: layoutBackupDirectoryURL)
            try? fileManager.removeItem(at: configurationBackupURL)
        }

        for existingFile in existingManagedFiles {
            try fileManager.copyItem(
                at: existingFile.fileURL,
                to: layoutBackupDirectoryURL.appendingPathComponent(existingFile.fileURL.lastPathComponent)
            )
        }
        if hadExistingConfiguration {
            try fileManager.copyItem(at: configurationFileURL, to: configurationBackupURL)
        }

        do {
            for layoutFile in layoutFiles {
                try layoutFile.data.write(to: layoutFile.fileURL, options: .atomic)
            }

            let desiredFileNames = Set(layoutFiles.map { $0.fileURL.lastPathComponent })
            for existingFile in existingManagedFiles where !desiredFileNames.contains(existingFile.fileURL.lastPathComponent) {
                try fileManager.removeItem(at: existingFile.fileURL)
            }

            try configurationData.write(to: configurationFileURL, options: .atomic)
        } catch {
            do {
                try restoreManagedLayoutFiles(
                    from: layoutBackupDirectoryURL,
                    to: layoutDirectoryURL
                )
            } catch {
                AppLogger.shared.error("Failed to restore managed layout files after save failure: \(error.localizedDescription, privacy: .public)")
            }
            do {
                try restoreConfigurationFile(
                    from: hadExistingConfiguration ? configurationBackupURL : nil,
                    to: configurationFileURL
                )
            } catch {
                AppLogger.shared.error("Failed to restore config.json after save failure: \(error.localizedDescription, privacy: .public)")
            }
            throw error
        }
    }

    private func restoreManagedLayoutFiles(from backupDirectoryURL: URL, to layoutDirectoryURL: URL) throws {
        try fileManager.createDirectory(at: layoutDirectoryURL, withIntermediateDirectories: true)
        for existingManagedFile in managedLayoutFiles(in: layoutDirectoryURL) {
            try fileManager.removeItem(at: existingManagedFile.fileURL)
        }

        let backupItems = try fileManager.contentsOfDirectory(
            at: backupDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for backupItem in backupItems {
            try fileManager.copyItem(
                at: backupItem,
                to: layoutDirectoryURL.appendingPathComponent(backupItem.lastPathComponent)
            )
        }
    }

    private func restoreConfigurationFile(from backupURL: URL?, to configurationFileURL: URL) throws {
        if fileManager.fileExists(atPath: configurationFileURL.path) {
            try fileManager.removeItem(at: configurationFileURL)
        }

        guard let backupURL else {
            return
        }

        try fileManager.copyItem(at: backupURL, to: configurationFileURL)
    }

    private func decodeConfigurationFile(from data: Data) throws -> ConfigurationFile {
        try makeDecoder().decode(ConfigurationFile.self, from: data)
    }

    private func decodeLayoutGroup(from data: Data) throws -> LayoutGroupConfiguration {
        try makeDecoder().decode(LayoutGroupConfiguration.self, from: data)
    }

    private func managedLayoutFiles(in directoryURL: URL) -> [LayoutFileMatch] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return fileURLs.compactMap { fileURL in
            guard
                let index = managedLayoutFileIndex(for: fileURL.lastPathComponent)
            else {
                return nil
            }
            return LayoutFileMatch(index: index, fileURL: fileURL)
        }
        .sorted { lhs, rhs in
            if lhs.index == rhs.index {
                return lhs.fileURL.lastPathComponent < rhs.fileURL.lastPathComponent
            }
            return lhs.index < rhs.index
        }
    }

    private func managedLayoutFileIndex(for fileName: String) -> Int? {
        let pattern = #"^([1-9][0-9]*)\.grid\.json$"#
        guard
            let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(
                in: fileName,
                range: NSRange(fileName.startIndex..., in: fileName)
            ),
            let range = Range(match.range(at: 1), in: fileName)
        else {
            return nil
        }

        return Int(fileName[range])
    }

    private func makeConfigurationLoadDiagnostic(
        for error: Error,
        fileURL: URL,
        data: Data
    ) -> ConfigurationLoadDiagnostic {
        let components = diagnosticComponents(for: error, data: data)
        return ConfigurationLoadDiagnostic(
            fileURL: fileURL,
            message: components.message,
            line: components.line,
            column: components.column,
            codingPath: components.codingPath
        )
    }

    private func makeLayoutFileDiagnostic(
        for error: Error,
        fileURL: URL,
        data: Data
    ) -> LayoutFileDiagnostic {
        let components = diagnosticComponents(for: error, data: data)
        return LayoutFileDiagnostic(
            fileURL: fileURL,
            message: components.message,
            line: components.line,
            column: components.column,
            codingPath: components.codingPath
        )
    }

    private func diagnosticComponents(for error: Error, data: Data) -> DiagnosticComponents {
        if let decodingError = error as? DecodingError {
            return diagnosticComponents(from: decodingError, data: data)
        }

        let nsError = error as NSError
        let message = diagnosticMessage(for: error)
        let location = diagnosticLocation(from: nsError, data: data)
        return DiagnosticComponents(
            message: message,
            line: location?.line,
            column: location?.column,
            codingPath: []
        )
    }

    private func diagnosticComponents(from error: DecodingError, data: Data) -> DiagnosticComponents {
        switch error {
        case let .dataCorrupted(context):
            let underlyingError = context.underlyingError as NSError?
            let location = diagnosticLocation(from: underlyingError, data: data)
            return DiagnosticComponents(
                message: diagnosticMessage(forDataCorruption: context, underlyingError: underlyingError),
                line: location?.line,
                column: location?.column,
                codingPath: context.codingPath.map(\.stringValue)
            )
        case let .keyNotFound(key, context):
            return DiagnosticComponents(
                message: "Missing required key '\(key.stringValue)'.",
                line: nil,
                column: nil,
                codingPath: (context.codingPath + [key]).map(\.stringValue)
            )
        case let .typeMismatch(_, context):
            return DiagnosticComponents(
                message: context.debugDescription,
                line: nil,
                column: nil,
                codingPath: context.codingPath.map(\.stringValue)
            )
        case let .valueNotFound(_, context):
            return DiagnosticComponents(
                message: context.debugDescription,
                line: nil,
                column: nil,
                codingPath: context.codingPath.map(\.stringValue)
            )
        @unknown default:
            return DiagnosticComponents(
                message: diagnosticMessage(for: error),
                line: nil,
                column: nil,
                codingPath: []
            )
        }
    }

    private func diagnosticMessage(for error: Error) -> String {
        switch error {
        case let configurationError as ConfigurationFileError:
            switch configurationError {
            case let .invalidLayoutReference(layoutIndex):
                return "Hotkey layout index must be greater than zero, got \(layoutIndex)."
            case let .missingActiveLayoutGroup(groupName):
                return "general.activeLayoutGroup references missing layout group '\(groupName)'."
            case .duplicateLayoutGroupName:
                return "layoutGroups contains duplicate group names."
            case let .overlappingMonitorBindings(groupName):
                return "layout group '\(groupName)' contains overlapping monitor bindings."
            case .embeddedLayoutGroupsNotSupported:
                return "config.json must not contain embedded layoutGroups. Move them into layout/*.grid.json."
            }
        default:
            return error.localizedDescription
        }
    }

    private func diagnosticMessage(
        forDataCorruption context: DecodingError.Context,
        underlyingError: NSError?
    ) -> String {
        if let debugDescription = underlyingError?.userInfo["NSDebugDescription"] as? String {
            return debugDescription
        }
        return context.debugDescription
    }

    private func diagnosticLocation(from error: NSError?, data: Data) -> (line: Int, column: Int)? {
        guard let error else {
            return nil
        }

        if let byteOffset = error.userInfo["NSJSONSerializationErrorIndex"] as? Int {
            return location(forByteOffset: byteOffset, in: data)
        }

        if let debugDescription = error.userInfo["NSDebugDescription"] as? String {
            if let location = parseLineAndColumn(from: debugDescription) {
                return location
            }
            if debugDescription.localizedCaseInsensitiveContains("unexpected end of file") {
                return location(forByteOffset: data.count, in: data)
            }
        }

        if error.localizedDescription.localizedCaseInsensitiveContains("unexpected end of file") {
            return location(forByteOffset: data.count, in: data)
        }

        return nil
    }

    private func location(forByteOffset byteOffset: Int, in data: Data) -> (line: Int, column: Int) {
        let clampedOffset = max(0, min(byteOffset, data.count))
        var line = 1
        var column = 1

        for byte in data.prefix(clampedOffset) {
            if byte == 0x0A {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        return (line, column)
    }

    private func parseLineAndColumn(from description: String) -> (line: Int, column: Int)? {
        guard
            let expression = try? NSRegularExpression(pattern: #"line (\d+), column (\d+)"#),
            let match = expression.firstMatch(
                in: description,
                range: NSRange(description.startIndex..., in: description)
            ),
            let lineRange = Range(match.range(at: 1), in: description),
            let columnRange = Range(match.range(at: 2), in: description),
            let line = Int(description[lineRange]),
            let column = Int(description[columnRange])
        else {
            return nil
        }

        return (line, column)
    }

    private func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
