import ArgumentParser

// cli entrypoint
@main
struct HyperFocus: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A daemon process which helps you focus on your work."
    )

    @Flag(help: "Print out the version of the application.")
    var version = false

    @Option(name: .shortAndLong, help: "Path to the configuration file")
    var configuration: String? = nil

    mutating func run() throws {
        if version {
            // we cannot get the latest tag version at compile time
            // https://stackoverflow.com/questions/27804227/using-compiler-variables-in-swift
            print("v0.5.1")
            return
        }

        ConfigurationLoader.userConfigurationPath = configuration

        focus_app.main()
    }
}
