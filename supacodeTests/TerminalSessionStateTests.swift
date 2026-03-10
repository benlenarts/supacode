import Foundation
import GhosttyKit
import Testing

@testable import supacode

@MainActor
struct TerminalSessionStateTests {
  @Test func closeSurfaceSkipsConfirmationWhenProcessIsNotAlive() throws {
    let state = makeState()
    let tabId = try #require(state.createTab())
    let surface = try #require(state.splitTree(for: tabId).root?.leftmostLeaf())
    surface.needsConfirmQuitOverride = true

    let originalHandler = GhosttyActionSupport.closeConfirmationHandler
    defer {
      GhosttyActionSupport.closeConfirmationHandler = originalHandler
    }

    var confirmationCount = 0
    GhosttyActionSupport.closeConfirmationHandler = {
      confirmationCount += 1
      return false
    }

    var closedTabs = 0
    state.onTabClosed = {
      closedTabs += 1
    }

    surface.bridge.closeSurface(processAlive: false)

    #expect(confirmationCount == 0)
    #expect(state.tabManager.tabs.isEmpty)
    #expect(closedTabs == 1)
  }

  @Test func closeSurfaceRespectsConfirmationWhenProcessIsAlive() throws {
    let state = makeState()
    let tabId = try #require(state.createTab())
    let surface = try #require(state.splitTree(for: tabId).root?.leftmostLeaf())
    surface.needsConfirmQuitOverride = true

    let originalHandler = GhosttyActionSupport.closeConfirmationHandler
    defer {
      GhosttyActionSupport.closeConfirmationHandler = originalHandler
    }

    var confirmationCount = 0
    GhosttyActionSupport.closeConfirmationHandler = {
      confirmationCount += 1
      return false
    }

    var closedTabs = 0
    state.onTabClosed = {
      closedTabs += 1
    }

    surface.bridge.closeSurface(processAlive: true)

    #expect(confirmationCount == 1)
    #expect(state.tabManager.tabs.map(\.id) == [tabId])
    #expect(closedTabs == 0)
  }

  @Test func closeSurfaceClosesAfterConfirmationWhenProcessIsAlive() throws {
    let state = makeState()
    let tabId = try #require(state.createTab())
    let surface = try #require(state.splitTree(for: tabId).root?.leftmostLeaf())
    surface.needsConfirmQuitOverride = true

    let originalHandler = GhosttyActionSupport.closeConfirmationHandler
    defer {
      GhosttyActionSupport.closeConfirmationHandler = originalHandler
    }

    var confirmationCount = 0
    GhosttyActionSupport.closeConfirmationHandler = {
      confirmationCount += 1
      return true
    }

    var closedTabs = 0
    state.onTabClosed = {
      closedTabs += 1
    }

    surface.bridge.closeSurface(processAlive: true)

    #expect(confirmationCount == 1)
    #expect(state.tabManager.tabs.isEmpty)
    #expect(closedTabs == 1)
  }

  @Test func closeTabActionSupportsOtherMode() throws {
    let state = makeState()
    let first = try #require(state.createTab())
    _ = try #require(state.splitTree(for: first).root?.leftmostLeaf())
    let middle = try #require(state.createTab())
    let middleSurface = try #require(state.splitTree(for: middle).root?.leftmostLeaf())
    let last = try #require(state.createTab())
    _ = try #require(state.splitTree(for: last).root?.leftmostLeaf())

    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_CLOSE_TAB
    action.action.close_tab_mode = GHOSTTY_ACTION_CLOSE_TAB_MODE_OTHER

    let handled = middleSurface.bridge.handleAction(target: ghostty_target_s(), action: action)

    #expect(handled)
    #expect(state.tabManager.tabs.map(\.id) == [middle])
  }

  @Test func closeTabActionSupportsRightMode() throws {
    let state = makeState()
    let first = try #require(state.createTab())
    let firstSurface = try #require(state.splitTree(for: first).root?.leftmostLeaf())
    let middle = try #require(state.createTab())
    _ = try #require(state.splitTree(for: middle).root?.leftmostLeaf())
    let last = try #require(state.createTab())
    _ = try #require(state.splitTree(for: last).root?.leftmostLeaf())

    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_CLOSE_TAB
    action.action.close_tab_mode = GHOSTTY_ACTION_CLOSE_TAB_MODE_RIGHT

    let handled = firstSurface.bridge.handleAction(target: ghostty_target_s(), action: action)

    #expect(handled)
    #expect(state.tabManager.tabs.map(\.id) == [first])
  }

  @Test func moveTabActionReordersTabs() throws {
    let state = makeState()
    let first = try #require(state.createTab())
    _ = try #require(state.splitTree(for: first).root?.leftmostLeaf())
    let middle = try #require(state.createTab())
    let middleSurface = try #require(state.splitTree(for: middle).root?.leftmostLeaf())
    let last = try #require(state.createTab())
    _ = try #require(state.splitTree(for: last).root?.leftmostLeaf())

    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_MOVE_TAB
    action.action.move_tab = ghostty_action_move_tab_s(amount: -1)

    let handled = middleSurface.bridge.handleAction(target: ghostty_target_s(), action: action)

    #expect(handled)
    #expect(state.tabManager.tabs.map(\.id) == [middle, first, last])
  }

  private func makeState() -> TerminalSessionState {
    TerminalSessionState(
      runtime: GhosttyRuntime(skipNativeRuntime: true),
      session: TerminalSession(
        id: "/tmp/session-1",
        name: "session-1",
        detail: "detail",
        workingDirectory: URL(fileURLWithPath: "/tmp/session-1")
      )
    )
  }
}
