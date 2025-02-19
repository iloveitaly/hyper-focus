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

        // TODO: maybe validate against JSON schema?

        debug("Loading configuration from \(configPath!.absoluteString)")

        let configData = try! Data(contentsOf: configPath!)

        // neat! Apple supports JSON5, which allows for comments
        // https://developer.apple.com/documentation/foundation/jsondecoder/3766916-allowsjson5
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true

        var config = try! decoder.decode(Configuration.self, from: configData)

        // if root `pause_*` config is set, inherit it each schedule
        config.schedule = config.schedule.map { item in
            var newItem = item
            newItem.pause_limit = newItem.pause_limit ?? config.pause_limit
            newItem.pause_options = newItem.pause_options ?? config.pause_options
            return newItem
        }

        return config
    }
}
