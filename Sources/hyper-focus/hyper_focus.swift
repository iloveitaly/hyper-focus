import Cocoa

enum BrowserTab {
    case chrome(GoogleChromeTab)
    case safari(SafariTab)
}

// https://stackoverflow.com/questions/24068506/how-can-i-change-the-textual-representation-displayed-for-a-type-in-swift
struct SwitchingActivity: CustomStringConvertible {
    let app: String
    let title: String
    let configuration: Configuration.ScheduleItem

    var activeTab: BrowserTab?
    var url: String?

    var description: String {
        return "SwitchingActivity: \(app) - \(title)"
    }
}

struct Configuration: Codable {
    struct ScheduleItem: Codable, Equatable {
        var start: Int?
        var start_minute: Int?
        var end: Int?
        var end_minute: Int?
        var name: String?
        var description: String?
        var schedule_only: Bool?
        var start_script: String?
        var block_hosts: [String]
        var block_urls: [String]
        var block_apps: [String]
        var allow_hosts: [String]
        var allow_urls: [String]
        var allow_apps: [String]
    }

    var initial_wake: String?
    var wake: String?
    var schedule: [ScheduleItem]
}

var systemObserver: SystemObserver?
var sleepWatcher: SleepWatcher?
var apiServer: ApiServer?

public enum focus_app {
    public static func main() {
        start()

        // dispatchMain() is NOT identical, there are slight differences
        RunLoop.main.run()
    }

    static func start() {
        guard checkAccessibilityAccess() else {
            log("accessibility access not granted, retrying in 60 seconds")

            openAccessibilityPreferences()

            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                start()
            }

            return
        }

        let scheduleManager = ScheduleManager()
        systemObserver = SystemObserver(scheduleManager: scheduleManager)
        sleepWatcher = SleepWatcher(scheduleManager: scheduleManager)
        apiServer = ApiServer(scheduleManager: scheduleManager)
    }
}

// https://cs.github.com/OpenEmu/OpenEmu/blob/6d25e3da75558bf976f9efee3688fdf8f6c51d8f/OpenEmu/AppDelegate.swift#L450
func openAccessibilityPreferences() {
    DispatchQueue.main.async {
        // can't use `NSApp.activate(ignoringOtherApps: true)` in CLI app

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Accessibility Permissions Required", comment: "")
        alert.informativeText = "You know the drill. Grant accessibility permissions, and full disk permissions if you have scripts that require access to your file system. \n\nHyper focus will automatically retry in 1 minute."
        alert.runModal()

        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)

        // TODO: if accessability is granted, then open full disk access
        // NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FullDisk")!)
    }
}

// TODO: maybe check full system access as well?
func checkAccessibilityAccess() -> Bool {
    let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let options = [checkOptPrompt: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary?)
    return accessEnabled
}
