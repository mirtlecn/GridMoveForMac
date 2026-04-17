import Foundation

final class ConfigurationStore {
    struct LoadResult {
        let configuration: AppConfiguration
        let didFallBackToDefault: Bool
    }

    private let fileManager: FileManager
    let directoryURL: URL
    let fileURL: URL

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
    }

    func load() throws -> AppConfiguration {
        try loadWithStatus().configuration
    }

    func loadWithStatus() throws -> LoadResult {
        try ensureDirectoryExists()

        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let configurationFile = try makeDecoder().decode(ConfigurationFile.self, from: data)
                return LoadResult(
                    configuration: try ConfigurationSchemaConverter.makeAppConfiguration(from: configurationFile),
                    didFallBackToDefault: false
                )
            } catch {
                AppLogger.shared.error("Failed to decode configuration from \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                return LoadResult(configuration: .defaultValue, didFallBackToDefault: true)
            }
        }

        let configuration = AppConfiguration.defaultValue
        try save(configuration)
        return LoadResult(configuration: configuration, didFallBackToDefault: false)
    }

    func save(_ configuration: AppConfiguration) throws {
        try ensureDirectoryExists()
        let configurationFile = try ConfigurationSchemaConverter.makeConfigurationFile(from: configuration)
        let data = try makeEncoder().encode(configurationFile)
        try data.write(to: fileURL, options: .atomic)
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
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
