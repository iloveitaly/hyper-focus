import Foundation

// there's no builtin logging library on macos which has levels & hits stdout, so we build our own simple one
// there a complex open source one, but it makes it harder to compile this simple one-file swift application
let dateFormatter = DateFormatter()
let programName = "focus-app"

let defaultLogLevel = "INFO"
let logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"]?.uppercased() ?? defaultLogLevel

func logTimestamp() -> String {
    let now = Date()
    dateFormatter.timeZone = TimeZone.current
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return dateFormatter.string(from: now)
}

// generate log prefix based on level
func logPrefix(_ level: String) -> String {
    return "\(logTimestamp()) [\(programName)] [\(level)]"
}

public func debug(_ msg: String) {
    if logLevel == "DEBUG" {
        print("\(logPrefix("DEBUG")) \(msg)")
        fflush(stdout)
    }
}

public func log(_ msg: String) {
    if logLevel == "DEBUG" || logLevel == "INFO" {
        print("\(logPrefix("INFO")) \(msg)")
        fflush(stdout)
    }
}

public func error(_ msg: String) {
    print("\(logPrefix("ERROR")) \(msg)")
    fflush(stdout)
}

// `error` is a reserved word inside a catch block
public func errorLog(_ msg: String) {
    error(msg)
}
