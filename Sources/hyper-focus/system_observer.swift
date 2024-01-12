import Cocoa
import ScriptingBridge

class SystemObserver {
    var observer: AXObserver?
    var oldWindow: AXUIElement?

    let scheduleManager: ScheduleManager

    // list of chrome equivalent browsers
    let CHROME_BROWSERS = [
        "Google Chrome",
        "Google Chrome Canary",
        "Chromium",
        "Brave Browser",
    ]

    init(scheduleManager: ScheduleManager) {
        self.scheduleManager = scheduleManager

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
        debug("focused app changed")

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
                    // TODO: had issue where changes were not notified properly and we always landed in this block
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
