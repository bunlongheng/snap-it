import Foundation

/// Reads and writes `config.json`.
///
/// The file is the only state Snap It keeps, it is pretty printed so it can be
/// edited by hand, and a malformed file never overwrites itself: loading a bad
/// file surfaces an error and leaves the file untouched.
final class ConfigStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/SnapIt/config.json`
    static func defaultURL(
        fileManager: FileManager = .default
    ) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("SnapIt/config.json")
    }

    /// Returns the stored config, or the defaults when no file exists yet.
    func load() throws -> Config {
        guard FileManager.default.fileExists(atPath: url.path) else { return .standard }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SnapItError.configUnreadable(path: url.path, reason: error.localizedDescription)
        }

        do {
            return try JSONDecoder().decode(Config.self, from: data).validated()
        } catch let error as SnapItError {
            throw error
        } catch {
            throw SnapItError.configUnreadable(path: url.path, reason: error.localizedDescription)
        }
    }

    func save(_ config: Config) throws {
        try config.validate()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(config)

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// Writes the defaults if there is nothing on disk, so a first run leaves
    /// the user with a file to edit.
    @discardableResult
    func loadOrCreate() throws -> Config {
        if FileManager.default.fileExists(atPath: url.path) { return try load() }
        let config = Config.standard
        try save(config)
        return config
    }
}
