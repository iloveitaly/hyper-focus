import Cocoa
import ScriptingBridge

@objc protocol ChromeTab {
  @objc optional var URL: String { get }
  @objc optional var title: String { get }
}

@objc protocol ChromeWindow {
  @objc optional var activeTab: ChromeTab { get }
  @objc optional var mode: String { get }
}

extension SBObject: ChromeWindow, ChromeTab {}

@objc protocol ChromeProtocol {
  @objc optional func windows() -> [ChromeWindow]
}

extension SBApplication: ChromeProtocol {}

// https://github.com/tingraldi/SwiftScripting/blob/4346eba0f47e806943601f5fb2fe978e2066b310/Frameworks/SafariScripting/SafariScripting/Safari.swift#L37

@objc public protocol SafariDocument {
  @objc optional var name: String { get } // Its name.
  @objc optional var modified: Bool { get } // Has it been modified since the last save?
  @objc optional var file: URL { get } // Its location on disk, if it has one.
  @objc optional var source: String { get } // The HTML source of the web page currently loaded in the document.
  @objc optional var URL: String { get } // The current URL of the document.
  @objc optional var text: String { get } // The text of the web page currently loaded in the document. Modifications to text aren't reflected on the web page.
  @objc optional func setURL(_ URL: String!) // The current URL of the document.
}

@objc public protocol SafariTab {
  @objc optional var source: String { get } // The HTML source of the web page currently loaded in the tab.
  @objc optional var URL: String { get } // The current URL of the tab.
  @objc optional var index: NSNumber { get } // The index of the tab, ordered left to right.
  @objc optional var text: String { get } // The text of the web page currently loaded in the tab. Modifications to text aren't reflected on the web page.
  @objc optional var visible: Bool { get } // Whether the tab is currently visible.
  @objc optional var name: String { get } // The name of the tab.
  @objc optional func setURL(_ URL: String!) // The current URL of the tab.
}

@objc public protocol SafariWindow {
  @objc optional var name: String { get } // The title of the window.
  @objc optional func id() -> Int // The unique identifier of the window.
  @objc optional var index: Int { get } // The index of the window, ordered front to back.
  @objc optional var document: SafariDocument { get } // The document whose contents are displayed in the window.
  @objc optional func tabs() -> SBElementArray
  @objc optional var currentTab: SafariTab { get } // The current tab.
}

extension SBObject: SafariWindow {}

@objc public protocol SafariApplication {
  @objc optional func documents() -> SBElementArray
  @objc optional func windows() -> [SafariWindow]
  @objc optional var name: String { get } // The name of the application.
  @objc optional var frontmost: Bool { get } // Is this the active application?
}

extension SBApplication: SafariApplication {}


enum BrowserTab {
  case chrome(ChromeTab)
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

start()
RunLoop.main.run()

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

      let chromeObject: ChromeProtocol = SBApplication(bundleIdentifier: bundleIdentifier)!

      let frontWindow = chromeObject.windows!()[0]
      let activeTab = frontWindow.activeTab!

      data.url = activeTab.URL
      data.activeTab = BrowserTab.chrome(activeTab)
    } else if frontmost.localizedName == "Safari" {
      debug("Safari browser detected, extracting URL and title")

      let safariObject: SafariApplication = SBApplication(bundleIdentifier: bundleIdentifier)!

      let frontWindow = safariObject.windows!()[0]
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
        if extractHost(data.url ?? "") == "mail.google.com" {
      error("blocked url")
      let redirectUrl: String? = "about:blank"
      // activeTab.setURL!(redirectUrl)
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
