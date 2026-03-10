import Foundation
import GhosttyKit
import Testing

@testable import supacode

@MainActor
struct GhosttySurfaceBridgeTests {
  @Test func setTitleReturnsHandled() {
    let bridge = GhosttySurfaceBridge()
    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_SET_TITLE
    let target = ghostty_target_s()

    let handled = "Title".withCString { titlePtr in
      action.action.set_title = ghostty_action_set_title_s(title: titlePtr)
      return bridge.handleAction(target: target, action: action)
    }

    #expect(handled)
    #expect(bridge.state.title == "Title")
  }

  @Test func desktopNotificationEmitsCallback() {
    let bridge = GhosttySurfaceBridge()
    var received: (String, String)?
    bridge.onDesktopNotification = { title, body in
      received = (title, body)
    }

    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_DESKTOP_NOTIFICATION
    let target = ghostty_target_s()

    "Title".withCString { titlePtr in
      "Body".withCString { bodyPtr in
        action.action.desktop_notification = ghostty_action_desktop_notification_s(
          title: titlePtr,
          body: bodyPtr
        )
        _ = bridge.handleAction(target: target, action: action)
      }
    }

    #expect(received?.0 == "Title")
    #expect(received?.1 == "Body")
  }

  @Test func openURLUsesActionSupport() {
    let originalOpener = GhosttyActionSupport.urlOpener
    defer {
      GhosttyActionSupport.urlOpener = originalOpener
    }

    var receivedURL: URL?
    var receivedKind: ghostty_action_open_url_kind_e?
    GhosttyActionSupport.urlOpener = { url, kind in
      receivedURL = url
      receivedKind = kind
      return true
    }

    let bridge = GhosttySurfaceBridge()
    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_OPEN_URL
    let target = ghostty_target_s()
    let rawURL = "~/tmp/ghostty-config.ghostty"

    let handled = rawURL.withCString { urlPtr in
      action.action.open_url = ghostty_action_open_url_s(
        kind: GHOSTTY_ACTION_OPEN_URL_KIND_TEXT,
        url: urlPtr,
        len: UInt(rawURL.utf8.count)
      )
      return bridge.handleAction(target: target, action: action)
    }

    #expect(handled)
    #expect(receivedKind == GHOSTTY_ACTION_OPEN_URL_KIND_TEXT)
    #expect(
      receivedURL == URL(fileURLWithPath: NSString(string: rawURL).standardizingPath)
    )
  }

  @Test func resetWindowSizeRequiresSurfaceView() {
    let bridge = GhosttySurfaceBridge()
    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_RESET_WINDOW_SIZE

    let handled = bridge.handleAction(target: ghostty_target_s(), action: action)

    #expect(handled == false)
  }
}
