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

final class ConfigurationStore {
    struct LoadResult {
        let configuration: AppConfiguration
        let source: ConfigurationLoadSource
        let diagnostic: ConfigurationLoadDiagnostic?
    }

    private let fileManager: FileManager
    let directoryURL: URL
    let fileURL: URL
    let lastKnownGoodFileURL: URL

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
        lastKnownGoodFileURL = baseURL.appendingPathComponent("config.last-known-good.json")
    }

    func load() throws -> AppConfiguration {
        try loadWithStatus().configuration
    }

    func loadWithStatus() throws -> LoadResult {
        try ensureDirectoryExists()

        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                return LoadResult(
                    configuration: try decodeConfiguration(from: data),
                    source: .persistedConfiguration,
                    diagnostic: nil
                )
            } catch {
                let data = (try? Data(contentsOf: fileURL)) ?? Data()
                let diagnostic = makeDiagnostic(for: error, fileURL: fileURL, data: data)
                AppLogger.shared.error("Failed to load configuration from \(self.fileURL.path, privacy: .public): \(diagnostic.message, privacy: .public)")

                if fileManager.fileExists(atPath: lastKnownGoodFileURL.path) {
                    do {
                        let recoveryData = try Data(contentsOf: lastKnownGoodFileURL)
                        return LoadResult(
                            configuration: try decodeConfiguration(from: recoveryData),
                            source: .lastKnownGood,
                            diagnostic: diagnostic
                        )
                    } catch {
                        AppLogger.shared.error("Failed to load last-known-good configuration from \(self.lastKnownGoodFileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }

                return LoadResult(
                    configuration: .defaultValue,
                    source: .builtInDefault,
                    diagnostic: diagnostic
                )
            }
        }

        let configuration = AppConfiguration.defaultValue
        try save(configuration)
        return LoadResult(
            configuration: configuration,
            source: .persistedConfiguration,
            diagnostic: nil
        )
    }

    func save(_ configuration: AppConfiguration) throws {
        try ensureDirectoryExists()
        let data = try encodedConfigurationData(for: configuration)
        try data.write(to: fileURL, options: .atomic)
        do {
            try data.write(to: lastKnownGoodFileURL, options: .atomic)
        } catch {
            AppLogger.shared.error("Failed to update last-known-good configuration at \(self.lastKnownGoodFileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func decodeConfiguration(from data: Data) throws -> AppConfiguration {
        let configurationFile = try makeDecoder().decode(ConfigurationFile.self, from: data)
        return try ConfigurationSchemaConverter.makeAppConfiguration(from: configurationFile)
    }

    private func encodedConfigurationData(for configuration: AppConfiguration) throws -> Data {
        let configurationFile = try ConfigurationSchemaConverter.makeConfigurationFile(from: configuration)
        return try makeEncoder().encode(configurationFile)
    }

    private func makeDiagnostic(for error: Error, fileURL: URL, data: Data) -> ConfigurationLoadDiagnostic {
        if let decodingError = error as? DecodingError {
            return diagnostic(from: decodingError, fileURL: fileURL, data: data)
        }

        let nsError = error as NSError
        let message = diagnosticMessage(for: error)
        let location = diagnosticLocation(from: nsError, data: data)
        return ConfigurationLoadDiagnostic(
            fileURL: fileURL,
            message: message,
            line: location?.line,
            column: location?.column,
            codingPath: []
        )
    }

    private func diagnostic(from error: DecodingError, fileURL: URL, data: Data) -> ConfigurationLoadDiagnostic {
        switch error {
        case let .dataCorrupted(context):
            let underlyingError = context.underlyingError as NSError?
            let location = diagnosticLocation(from: underlyingError, data: data)
            return ConfigurationLoadDiagnostic(
                fileURL: fileURL,
                message: diagnosticMessage(forDataCorruption: context, underlyingError: underlyingError),
                line: location?.line,
                column: location?.column,
                codingPath: context.codingPath.map(\.stringValue)
            )
        case let .keyNotFound(key, context):
            return ConfigurationLoadDiagnostic(
                fileURL: fileURL,
                message: "Missing required key '\(key.stringValue)'.",
                line: nil,
                column: nil,
                codingPath: (context.codingPath + [key]).map(\.stringValue)
            )
        case let .typeMismatch(_, context):
            return ConfigurationLoadDiagnostic(
                fileURL: fileURL,
                message: context.debugDescription,
                line: nil,
                column: nil,
                codingPath: context.codingPath.map(\.stringValue)
            )
        case let .valueNotFound(_, context):
            return ConfigurationLoadDiagnostic(
                fileURL: fileURL,
                message: context.debugDescription,
                line: nil,
                column: nil,
                codingPath: context.codingPath.map(\.stringValue)
            )
        @unknown default:
            return ConfigurationLoadDiagnostic(
                fileURL: fileURL,
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
