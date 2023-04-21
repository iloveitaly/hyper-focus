import Foundation

enum ConfigurationLoader {
    // easier to set this globally than to pass it around everywhere
    static var userConfigurationPath: String?

    static func loadConfiguration() -> Configuration {
        return loadConfigurationFromPath(userConfigurationPath)
    }

    private static func loadConfigurationFromPath(_ userConfigPath: String?) -> Configuration {
        var configPath: URL?

        // is userConfigPath a valid file URL?
        if userConfigPath != nil && FileManager.default.fileExists(atPath: userConfigPath!) {
            configPath = URL(fileURLWithPath: userConfigPath!)
        } else {
            configPath = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/focus/config.json")
        }

        debug("Loading configuration from \(configPath!.absoluteString)")

        let configData = try! Data(contentsOf: configPath!)
        let config = try! JSONDecoder().decode(Configuration.self, from: configData)

        return config
    }
}
