import Cocoa
import ScriptingBridge

enum BrowserTab {
  case chrome(GoogleChromeTab)
  case safari(SafariTab)
}

struct SwitchingActivity {
  let app: String
  let title: String
  let configuration: Configuration.ScheduleItem
  var activeTab: BrowserTab?
  var url: String?
}

struct Configuration: Codable {
  struct ScheduleItem: Codable, Equatable {
    var start: Int?
    var end: Int?
    var name: String?
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

@main
public enum focus_app {
  public static func main() {
    start()

    // dispatchMain() is NOT identical, there are slight differences
    RunLoop.main.run()
  }

  static func loadConfigurationFromCommandLine() -> Configuration {
    let configPath = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/focus/config.json")
    let configData = try! Data(contentsOf: configPath)
    let config = try! JSONDecoder().decode(Configuration.self, from: configData)
    return config
  }

  static func start() {
    guard checkAccess() else {
      // TODO: I don't really know what this dispatchqueue business does
      DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        start()
      }
      return
    }

    // create configuration manager
    // TODO: could allow for a ui and storing config outside of the default location
    let configuration = loadConfigurationFromCommandLine()

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
      selector: #selector(self.focusedAppChanged),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )

    self.focusedAppChanged()
  }

  func hasActiveSchedule() -> Bool {
    return scheduleManager.getSchedule() != nil
  }

  func windowTitleChanged(
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

    let frontmost = NSWorkspace.shared.frontmostApplication!
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

func checkAccess() -> Bool {
  let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
  let options = [checkOptPrompt: true]
  let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary?)
  return accessEnabled
}
