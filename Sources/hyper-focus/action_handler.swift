import Cocoa
import Foundation

// TODO: is enum really the right thing to do here? Unsure :)
//       best way I could find to group together related functions

// once a "action" (window change, etc) is detected and normalized, it's passed to the ActionHandler to determine
// exactly how to handle it.
enum ActionHandler {
    static func handleAction(_ data: SwitchingActivity) {
        log("handling action: \(data)")

        if appAction(data) { return }
        if browserAction(data) { return }
    }

    static func extractHost(_ url: String) -> String? {
        let url = URL(string: url)
        return url?.host
    }

    static func hideApp() {
        // TODO: sometimes this hide method does not work
        NSWorkspace.shared.frontmostApplication!.hide()
    }

    static func appAction(_ data: SwitchingActivity) -> Bool {
        let allowApps = data.configuration.allow_apps
        let hasAllowApps = allowApps != nil

        // block list is only used if there is no allow list
        if hasAllowApps {
            if match(data.app, allowApps!) {
                log("app is in allow_apps, releasing")
                return false
            } else {
                log("app is not in allow_apps, blocking")
                debug("allow_apps: \(allowApps!)")
                hideApp()
                return true
            }
        }

        if match(data.app, data.configuration.block_apps ?? []) {
            log("app is in block_apps, hiding application to prevent usage")
            hideApp()
            return true
        }

        return false
    }

    // boolean represents if something was blocked
    static func browserAction(_ data: SwitchingActivity) -> Bool {
        guard let url = data.url else {
            warn("url is empty, not doing anything")
            return false
        }

        guard let host = extractHost(url) else {
            error("no host, not a valid url, skipping ")
            return false
        }

        // NOTE: `allow_*` always has precedence over `block_*`, and url has precedence over host
        //
        // possible "conflicting" configurations:
        //      {host}               {url}               {action}
        //      block                none | block        block
        //      none | allow         block               block
        //      block                allow               allow
        //
        // => release_condition = allow_url || allow_host && !block_url || !block_host && !block_url
        //
        // thus if url matches allow_url we can automatically release, and if it doesn't but it matches block_url we can block
        // if it matches neither, we can continue to the host check

        let allowModeEnabled = data.configuration.allow_hosts != nil || data.configuration.allow_urls != nil
        debug("allow_mode_enabled: \(allowModeEnabled)")

        debug("checking urls for any blocked matches")

        let blockUrls = data.configuration.block_urls ?? []
        let allowUrls = data.configuration.allow_urls ?? []

        // note: the url takes precedence over the host, and the allow takes precedence over the block,
        // so if url matches allow_url we can automatically release
        // the urls in the config are expected to have less params, so they are considered the subset (no regex here)
        if allowUrls.count > 0 && allowUrls.contains(where: { isSubsetOfUrl(supersetUrlString: url, subsetUrlString: $0) }) {
            error("url is in allow_urls, releasing")
            return false
        } else if blockUrls.count > 0 && blockUrls.contains(where: { isSubsetOfUrl(supersetUrlString: url, subsetUrlString: $0) }) {
            error("blocked url, redirecting browser to block page")
            blockTab(data.activeTab)
            return true
        }

        debug("checking hosts for any blocked matches")

        let blockHosts = data.configuration.block_hosts ?? []
        let allowHosts = data.configuration.allow_hosts ?? []

        // TODO: add 'www.' to all host entries which are not regex, this is not something users want to do manually!
        let blockHostsWithWWW = blockHosts.map { host in
            if isRegexString(host) {
                return [host]
            } else {
                return ["www.\(host)", host]
            }
        }.flatMap { $0 }

        let allowHostsWithWWW = allowHosts.map { host in
            if isRegexString(host) {
                return [host]
            } else {
                return ["www.\(host)", host]
            }
        }.flatMap { $0 }

        if match(host, allowHostsWithWWW) {
            error("host is in allow_hosts, releasing")
            return false
        }

        if match(host, blockHostsWithWWW) {
            error("blocked host, redirecting browser to block page")
            blockTab(data.activeTab)
            return true
        }

        if allowModeEnabled {
            error("allow mode enabled, blocking by default")
            blockTab(data.activeTab)
            return true
        }

        return false
    }

    // the syntax we've chosen is a string starting and ending with `/` to indicate a regex expression
    static func isRegexString(_ str: String) -> Bool {
        return str.first == "/" && str.last == "/"
    }

    static func match(_ str: String, _ matchList: [String]) -> Bool {
        if matchList.count == 0 {
            return false
        }

        if let matchedPattern = matchList.first(where: { pattern in
            var regexPattern: String

            if !isRegexString(pattern) {
                return str.contains(pattern)
            } else {
                // take out the leading & trailing /
                regexPattern = String(pattern.dropFirst().dropLast())
            }

            do {
                let regex = try Regex(regexPattern)
                return try regex.firstMatch(in: str) != nil
            } catch {
                errorLog("invalid regex pattern: \(pattern)")
                return false
            }
        }) {
            debug("[match] '\(str)' matched pattern: \(matchedPattern)")
            return true
        } else {
            debug("[match] '\(str)' did not match any pattern \(matchList)")
            return false
        }
    }

    static func isSubsetOfUrl(supersetUrlString: String, subsetUrlString: String) -> Bool {
        // TODO: there could be a case where this is no query string, but anchor references; what should we do there?
        //      anchors can be significant, but only sometimes

        // if the urls are equal, we can consider them a subset
        if supersetUrlString == subsetUrlString {
            return true
        }

        let optionalSupersetUrl = URLComponents(string: supersetUrlString)
        let optionalSubsetUrl = URLComponents(string: subsetUrlString)

        guard let supersetUrl = optionalSupersetUrl, let subsetUrl = optionalSubsetUrl else {
            error("invalid url (\(supersetUrlString)), skipping \(String(describing: optionalSupersetUrl)) \(String(describing: optionalSubsetUrl))")
            return false
        }

        // TODO: too big, should be a separate method!
        var queryIsSubset = true
        if let supersetQueryItems = supersetUrl.queryItems, let subsetQueryItems = subsetUrl.queryItems {
            for subsetQueryItem in subsetQueryItems {
                if !supersetQueryItems.contains(subsetQueryItem) {
                    queryIsSubset = false
                }
            }
        } else {
            queryIsSubset = false
        }

        return queryIsSubset &&
            supersetUrl.host == subsetUrl.host &&
            supersetUrl.path == subsetUrl.path
    }

    static func blockTab(_ activeTab: BrowserTab?) {
        let redirectUrl = scheduleManager!.configuration.blocked_redirect_url ?? "about:blank"

        // TODO: I don't know how to more elegantly unwrap the enum here...
        switch activeTab {
        case let .chrome(tab):
            tab.setURL!(redirectUrl)
        case let .safari(tab):
            tab.setURL!(redirectUrl)
        // TODO: firefox?
        case .none:
            break
        }
    }
}
