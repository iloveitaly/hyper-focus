import Cocoa
import ScriptingBridge

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
        var end: Int?
        var name: String?
        var start_script: String?
        var block_hosts: [String]
        var block_urls: [String]
        var block_apps: [String]
    }

    var initial_wake: String?
    var wake: String?
    var schedule: [ScheduleItem]
}

var systemObserver: SystemObserver?
var sleepWatcher: SleepWatcher?
var apiServer: ApiServer?

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

public enum focus_app {
    public static func main(_ userConfigPath: String?) {
        let configuration = loadConfigurationFromCommandLine(userConfigPath)

        start(configuration)

        // dispatchMain() is NOT identical, there are slight differences
        RunLoop.main.run()
    }

    static func start(_ configuration: Configuration) {
        guard checkAccessibilityAccess() else {
            log("accessibility access not granted, retrying in 60 seconds")

            openAccessibilityPreferences()

            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                start(configuration)
            }

            return
        }

        let scheduleManager = ScheduleManager(
            configuration: configuration
        )

        systemObserver = SystemObserver(
            scheduleManager: scheduleManager,
            configuration: configuration
        )

        sleepWatcher = SleepWatcher(
            scheduleManager: scheduleManager,
            configuration: configuration
        )

        apiServer = ApiServer(scheduleManager: scheduleManager)
    }

    static func loadConfigurationFromCommandLine(_ userConfigPath: String?) -> Configuration {
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

class SystemObserver {
    var observer: AXObserver?
    var oldWindow: AXUIElement?

    let configuration: Configuration
    let scheduleManager: ScheduleManager

    // list of chrome equivalent browsers
    let CHROME_BROWSERS = [
        "Google Chrome",
        "Google Chrome Canary",
        "Chromium",
        "Brave Browser",
    ]

    init(scheduleManager: ScheduleManager, configuration: Configuration) {
        self.scheduleManager = scheduleManager
        self.configuration = configuration

        // https://developer.apple.com/documentation/appkit/nsworkspace/1535049-didactivateapplicationnotificati
        // listen for changes in focused application
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(focusedAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        focusedAppChanged()
    }

    func hasActiveSchedule() -> Bool {
        return scheduleManager.getSchedule() != nil
    }

    func windowTitleChanged(
        // TODO: we don't use any of these variables, so we can just name them as such
        _: AXObserver,
        axElement: AXUIElement,
        notification _: CFString
    ) {
        guard hasActiveSchedule() else {
            debug("no active schedule, not processing events")
            return
        }

        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            debug("no frontmost application")
            return
        }

        guard let bundleIdentifier = frontmost.bundleIdentifier else {
            debug("no bundle identifier")
            return
        }

        var windowTitle: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &windowTitle)

        var data = SwitchingActivity(
            app: frontmost.localizedName!,
            title: windowTitle as? String ?? "",
            configuration: scheduleManager.getSchedule()!
        )

        if CHROME_BROWSERS.contains(frontmost.localizedName!) {
            debug("Chrome browser detected, extracting URL and title")

            let chromeObject: GoogleChromeApplication = SBApplication(bundleIdentifier: bundleIdentifier)!

            let frontWindow: GoogleChromeWindow = chromeObject.windows!()[0] as! GoogleChromeWindow
            let activeTab: GoogleChromeTab = frontWindow.activeTab!

            data.url = activeTab.URL
            data.activeTab = BrowserTab.chrome(activeTab)
        } else if frontmost.localizedName == "Safari" {
            debug("Safari browser detected, extracting URL and title")

            let safariObject: SafariApplication = SBApplication(bundleIdentifier: bundleIdentifier)!

            let frontWindow = safariObject.windows!()[0] as! SafariWindow
            let activeTab = frontWindow.currentTab!

            data.url = activeTab.URL
            data.activeTab = BrowserTab.safari(activeTab)
        }

        debug("window title changed: \(data)")

        ActionHandler.handleAction(data)
    }

    @objc func focusedWindowChanged(_ observer: AXObserver, window: AXUIElement) {
        debug("Focused window changed")

        // list of all notification constants:
        // https://developer.apple.com/documentation/applicationservices/kaxmainwindowchangednotification

        if oldWindow != nil {
            AXObserverRemoveNotification(
                observer, oldWindow!, kAXFocusedWindowChangedNotification as CFString
            )
        }

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        AXObserverAddNotification(observer, window, kAXTitleChangedNotification as CFString, selfPtr)

        windowTitleChanged(
            observer, axElement: window, notification: kAXTitleChangedNotification as CFString
        )

        oldWindow = window
    }

    @objc func focusedAppChanged() {
        debug("Focused app changed")

        if observer != nil {
            CFRunLoopRemoveSource(
                RunLoop.current.getCFRunLoop(),
                AXObserverGetRunLoopSource(observer!),
                CFRunLoopMode.defaultMode
            )
        }

        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            debug("no bundle identifier")
            return
        }

        let pid = frontmost.processIdentifier
        let focusedApp = AXUIElementCreateApplication(pid)

        AXObserverCreate(
            pid,
            {
                (
                    _ axObserver: AXObserver,
                    axElement: AXUIElement,
                    notification: CFString,
                    userData: UnsafeMutableRawPointer?
                ) in
                guard let userData = userData else {
                    log("Missing userData")
                    return
                }

                let application = Unmanaged<SystemObserver>.fromOpaque(userData).takeUnretainedValue()
                if notification == kAXFocusedWindowChangedNotification as CFString {
                    application.focusedWindowChanged(axObserver, window: axElement)
                } else {
                    log("window title changed on it's own")
                    application.windowTitleChanged(
                        axObserver,
                        axElement: axElement,
                        notification: notification
                    )
                }
            }, &observer
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        AXObserverAddNotification(
            observer!,
            focusedApp,
            kAXFocusedWindowChangedNotification as CFString,
            selfPtr
        )

        CFRunLoopAddSource(
            RunLoop.current.getCFRunLoop(),
            AXObserverGetRunLoopSource(observer!),
            CFRunLoopMode.defaultMode
        )

        var focusedWindow: AnyObject?
        AXUIElementCopyAttributeValue(
            focusedApp,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        if focusedWindow != nil {
            focusedWindowChanged(observer!, window: focusedWindow as! AXUIElement)
        }
    }
}

// TODO: maybe check full system access as well?
func checkAccessibilityAccess() -> Bool {
    let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let options = [checkOptPrompt: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary?)
    return accessEnabled
}
