import Foundation
import Testing

@testable import supacode

@MainActor
struct V2TerminalDetailViewTests {
  @Test func makeFocusedActionsReturnsNilActionsWithoutSelection() {
    let actions = V2TerminalDetailView.makeFocusedActions(selectedSession: nil) { _ in }

    #expect(actions.newTerminal == nil)
    #expect(actions.closeSurface == nil)
    #expect(actions.closeTab == nil)
  }

  @Test func makeFocusedActionsRoutesTerminalCommandsToSelectedSession() throws {
    let session = TerminalSession(
      id: "session-1",
      name: "Session 1",
      detail: "detail",
      workingDirectory: URL(fileURLWithPath: "/tmp/session-1")
    )
    var commands: [TerminalClient.Command] = []
    let actions = V2TerminalDetailView.makeFocusedActions(selectedSession: session) {
      commands.append($0)
    }

    let newTerminal = try #require(actions.newTerminal)
    let closeSurface = try #require(actions.closeSurface)
    let closeTab = try #require(actions.closeTab)

    newTerminal()
    closeSurface()
    closeTab()

    #expect(
      commands == [
        .createTab(session, runSetupScriptIfNew: false),
        .closeFocusedSurface(session),
        .closeFocusedTab(session),
      ]
    )
  }
}
