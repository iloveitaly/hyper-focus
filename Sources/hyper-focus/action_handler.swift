import Foundation
import Cocoa

// TODO: is enum really the right thing to do here? Unsure :)
//       best way I could find to group together related functions

enum ActionHandler {
  static func handleAction(_ data: SwitchingActivity) {
    log("handling action: \(data)")

    if appAction(data) { return }

    browserAction(data)
  }

  static func extractHost(_ url: String) -> String? {
    let url = URL(string: url)
    return url?.host
  }

  static func appAction(_ data: SwitchingActivity) -> Bool {
    if data.configuration.block_apps.contains(data.app) {
      log("app is in block_apps, hiding application to prevent usage")
      // TODO sometimes this hide method does not work
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

    // add 'www.' to all block_hosts entries
    let blockHosts = data.configuration.block_hosts
    let blockHostsWithWWW = blockHosts.map { "www.\($0)" }

    if blockHosts.contains(host) || blockHostsWithWWW.contains(host) {
      error("blocked host, redirecting browser to block page")
      blockTab(data.activeTab)
      return true
    }

    log("checking urls")

    // the urls in the config are expected to have less params, so they are considered the subset
    if data.configuration.block_urls.count > 0, data.configuration.block_urls.contains(where: { isSubsetOfUrl(supersetUrlString: url, subsetUrlString: $0) }) {
      error("blocked url, redirecting browser to block page")
      blockTab(data.activeTab)
      return true
    }

    return false
  }

  static func isSubsetOfUrl(supersetUrlString: String, subsetUrlString: String) -> Bool {
    let optionalSupersetUrl = URLComponents(string: supersetUrlString)
    let optionalSubsetUrl = URLComponents(string: subsetUrlString)

    guard let supersetUrl = optionalSupersetUrl, let subsetUrl = optionalSubsetUrl else {
      error("invalid url, skipping \(optionalSupersetUrl) \(optionalSubsetUrl)")
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
