import ComposableArchitecture
import SwiftUI

struct V2TerminalDetailView: View {
  struct FocusedActions {
    let newTerminal: (() -> Void)?
    let closeSurface: (() -> Void)?
    let closeTab: (() -> Void)?
  }

  let store: StoreOf<AppFeature>
  let terminalManager: TerminalSessionManager

  var body: some View {
    let focusedActions = Self.makeFocusedActions(selectedSession: store.selectedSession) {
      terminalManager.handleCommand($0)
    }
    Group {
      if let selectedSession = store.selectedSession {
        TerminalSessionView(
          session: selectedSession,
          manager: terminalManager,
          shouldRunSetupScript: false,
          forceAutoFocus: true,
          createTab: {
            terminalManager.handleCommand(.createTab(selectedSession, runSetupScriptIfNew: false))
          }
        )
        .id(selectedSession.id)
      } else {
        ContentUnavailableView("No session selected", systemImage: "terminal")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear(perform: syncSelectedSession)
    .onChange(of: store.selectedSessionID) { _, _ in
      syncSelectedSession()
    }
    .focusedSceneValue(\.newTerminalAction, focusedActions.newTerminal)
    .focusedSceneValue(\.closeSurfaceAction, focusedActions.closeSurface)
    .focusedSceneValue(\.closeTabAction, focusedActions.closeTab)
  }

  private func syncSelectedSession() {
    terminalManager.handleCommand(.setSelectedSessionID(store.selectedSessionID))
  }

  static func makeFocusedActions(
    selectedSession: TerminalSession?,
    send: @escaping @MainActor (TerminalClient.Command) -> Void
  ) -> FocusedActions {
    guard let selectedSession else {
      return FocusedActions(newTerminal: nil, closeSurface: nil, closeTab: nil)
    }
    return FocusedActions(
      newTerminal: {
        send(.createTab(selectedSession, runSetupScriptIfNew: false))
      },
      closeSurface: {
        send(.closeFocusedSurface(selectedSession))
      },
      closeTab: {
        send(.closeFocusedTab(selectedSession))
      }
    )
  }
}
