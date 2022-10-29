@main
public struct focus_app {
    public static func main() {
        start()
        RunLoop.main.run()
    }
}

import Cocoa
import ScriptingBridge

// https://github.com/tingraldi/SwiftScripting/blob/4346eba0f47e806943601f5fb2fe978e2066b310/Frameworks/SafariScripting/SafariScripting/Safari.swift#L37

enum BrowserTab {
  case chrome(GoogleChromeTab)
  case safari(SafariTab)
}

struct NetworkMessage {
  let app: String
  let title: String
  let configuration: Configuration.ScheduleItem
  var activeTab: BrowserTab?
  var url: String?
}

// there's no builtin logging library on macos which has levels & hits stdout, so we build our own simple one
// there a complex open source one, but it makes it harder to compile this simple one-file swift application
let dateFormatter = DateFormatter()

func logTimestamp() -> String {
  let now = Date()
  dateFormatter.timeZone = TimeZone.current
  dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
  return dateFormatter.string(from: now)
}

// generate log prefix based on level
func logPrefix(_ level: String) -> String {
  return "\(logTimestamp()) [aw-watcher-window-macos] [\(level)]"
}

let logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"]?.uppercased() ?? "DEBUG"

func debug(_ msg: String) {
  if logLevel == "DEBUG" {
    print("\(logPrefix("DEBUG")) \(msg)")
  }
}

func log(_ msg: String) {
  print("\(logPrefix("INFO")) \(msg)")
}

func error(_ msg: String) {
  print("\(logPrefix("ERROR")) \(msg)")
}

let main = MainThing()

struct Configuration: Codable {
  struct ScheduleItem: Codable {
    var start: Int
    var end: Int
    var block_hosts: [String]
    var block_urls: [String]
    var block_apps: [String]
  }

  var initial_wake: String
  var wake: String
  var schedule: [ScheduleItem]
}

func loadConfigurationFromCommandLine() -> Configuration {
  let configPath = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/focus/config.json")
  let configData = try! Data(contentsOf: configPath)
  let config = try! JSONDecoder().decode(Configuration.self, from: configData)
  return config
}

func start() {
  guard checkAccess() else {
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
      start()
    }
    return
  }

  // TODO: could allow for a ui and storing config outside of the default location
  let configuration = loadConfigurationFromCommandLine()
  main.configuration = configuration
  main.currentSchedule = configuration.schedule[0]

  // https://developer.apple.com/documentation/appkit/nsworkspace/1535049-didactivateapplicationnotificati
  // listen for changes in focused application
  NSWorkspace.shared.notificationCenter.addObserver(
    main,
    selector: #selector(main.focusedAppChanged),
    name: NSWorkspace.didActivateApplicationNotification,
    object: nil
  )

  // TODO: for sleep watcher replacement
  // NSWorkspace.shared.notificationCenter.addObserver(
  //   main,
  //   selector: #selector(main.focusedAppChanged),
  //   name: NSWorkspace.didWakeNotification,
  //   object: nil
  // )

  main.focusedAppChanged()
}

class MainThing {
  var observer: AXObserver?
  var oldWindow: AXUIElement?
  var configuration: Configuration?
  var currentSchedule: Configuration.ScheduleItem?

  func windowTitleChanged(
    _: AXObserver,
    axElement: AXUIElement,
    notification _: CFString
  ) {
    let frontmost = NSWorkspace.shared.frontmostApplication!
    let bundleIdentifier = frontmost.bundleIdentifier!

    // calculate now before executing any scripting since that can take some time
    let nowTime = Date.now

    var windowTitle: AnyObject?
    AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &windowTitle)

    var data = NetworkMessage(
      app: frontmost.localizedName!,
      title: windowTitle as? String ?? "",
      configuration: currentSchedule!
    )

    // list of chrome equivalent browsers
    let chromeBrowsers = [
      "Google Chrome",
      "Google Chrome Canary",
      "Chromium",
      "Brave Browser",
    ]

    if chromeBrowsers.contains(frontmost.localizedName!) {
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

        let application = Unmanaged<MainThing>.fromOpaque(userData).takeUnretainedValue()
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

enum ActionHandler {
  static func handleAction(_ data: NetworkMessage) {
    log("handling action: \(data)")

    if appAction(data) { return}

    browserAction(data)
  }

  static func extractHost(_ url: String) -> String? {
    let url = URL(string: url)
    return url?.host
  }

  static func appAction(_ data: NetworkMessage) -> Bool {
    if data.configuration.block_apps.contains(data.app) {
      log("app is in block_apps, hiding application to prevent usage")
      NSWorkspace.shared.frontmostApplication!.hide()
      return true
    }

    return false
  }

  static func browserAction(_ data: NetworkMessage) -> Bool {
    guard let url = data.url else {
      log("url is empty, not doing anything")
      return false
    }

    guard let host = extractHost(url) else {
      error("no host in url")
      return false
    }

    if data.configuration.block_hosts.contains(host) {
      error("blocked url")

      // TODO allow redirect to be configured
      let redirectUrl: String? = "about:blank"

      // TODO I don't know how to more elegantly unwrap the enum here...
      switch data.activeTab {
        case let .chrome(tab):
          tab.setURL!(redirectUrl)
        case let .safari(tab):
          tab.setURL!(redirectUrl)
        // TODO firefox?
        case .none:
          break
      }
    }

    return true
  }
}

func checkAccess() -> Bool {
  let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
  let options = [checkOptPrompt: true]
  let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary?)
  return accessEnabled
}
