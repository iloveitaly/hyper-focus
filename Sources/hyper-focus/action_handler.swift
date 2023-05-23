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

    static func appAction(_ data: SwitchingActivity) -> Bool {
        if match(data.app, data.configuration.block_apps) {
            if match(data.app, data.configuration.allow_apps) {
                log("app is in allow_apps, releasing")
                return false
            }
            log("app is in block_apps, hiding application to prevent usage")
            // TODO: sometimes this hide method does not work
            NSWorkspace.shared.frontmostApplication!.hide()
            return true
        }

        return false
    }

    static func browserAction(_ data: SwitchingActivity) -> Bool {
        guard let url = data.url else {
            log("url is empty, not doing anything")
            return false
        }

        guard let host = extractHost(url) else {
            error("no host, not a valid url, skipping ")
            return false
        }

        // note: allow always has precedence over block, and url has precedence over host
        // possible "conflicting" configurations:
        // {host}               {url}               {action}
        // block                none | block        block
        // none | allow         block               block
        // block                allow               allow
        // => release_condition = allow_url || allow_host && !block_url || !block_host && !block_url
        // thus if url matches allow_url we can automatically release, and if it doesn't but it matches block_url we can block
        // if it matches neither, we can continue to the host check
        
        debug("checking urls for any blocked matches")
        let blockUrls = data.configuration.block_urls
        let allowUrls = data.configuration.allow_urls
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
        let blockHosts = data.configuration.block_hosts
        let allowHosts = data.configuration.allow_hosts
        if match(host, blockHosts) && !match(host, allowHosts) {
            error("blocked host, redirecting browser to block page")
            blockTab(data.activeTab)
            return true
        }

        return false
    }
    
    static func match(_ str: String, _ regexpArray: [String]) -> Bool {
        if regexpArray.count == 0 {
            return false
        }
        if let matchedPattern = regexpArray.first(where: { pattern in
            let regex = try! NSRegularExpression(pattern: pattern)
            return regex.firstMatch(in: str, range: NSRange(location: 0, length: str.utf16.count)) != nil
        }) {
            debug("String \(str) matched pattern: \(matchedPattern)")
            return true
        } else {
            debug("String \(str) did not match any pattern")
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
            subsetQueryItems.forEach { subsetQueryItem in
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
        // TODO: allow redirect to be configured
        let redirectUrl: String? = "about:blank"

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
