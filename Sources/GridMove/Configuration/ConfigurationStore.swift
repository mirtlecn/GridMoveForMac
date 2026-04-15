import Foundation

final class ConfigurationStore {
    private let fileManager: FileManager
    private let directoryURL: URL
    let fileURL: URL

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        let baseURL = baseDirectoryURL
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/GridMove", isDirectory: true)
        directoryURL = baseURL
        fileURL = baseURL.appendingPathComponent("config.plist")
    }

    func load() throws -> AppConfiguration {
        try ensureDirectoryExists()

        if fileManager.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            return try PropertyListDecoder().decode(AppConfiguration.self, from: data)
        }

        let configuration = AppConfiguration.defaultValue
        try save(configuration)
        return configuration
    }

    func save(_ configuration: AppConfiguration) throws {
        try ensureDirectoryExists()
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: .atomic)
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}
