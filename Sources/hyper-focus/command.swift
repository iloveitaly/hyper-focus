import ArgumentParser

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
      if(version) {
        // TODO get latest git tag at swift compile time, doesn't seem like this is easy
        print("0.1.3")
        return
      }

      focus_app.main(configuration)
    }
}