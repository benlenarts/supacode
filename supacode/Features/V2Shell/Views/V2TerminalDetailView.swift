import ComposableArchitecture
import SwiftUI

struct V2TerminalDetailView: View {
  struct FocusedActions {
    let newTerminal: (() -> Void)?
    let closeSurface: (() -> Void)?
    let closeTab: (() -> Void)?
    let startSearch: (() -> Void)?
    let searchSelection: (() -> Void)?
    let navigateSearchNext: (() -> Void)?
    let navigateSearchPrevious: (() -> Void)?
    let endSearch: (() -> Void)?
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
        ContentUnavailableView {
          Label("No workspaces yet", systemImage: "folder")
        } description: {
          Text("Add a folder to start a workspace terminal.")
        } actions: {
          Button("Open Workspace...") {
            store.send(.setWorkspacePickerPresented(true))
          }
          .keyboardShortcut(
            AppShortcuts.openWorkspace.keyEquivalent,
            modifiers: AppShortcuts.openWorkspace.modifiers
          )
        }
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
    .focusedSceneValue(\.startSearchAction, focusedActions.startSearch)
    .focusedSceneValue(\.searchSelectionAction, focusedActions.searchSelection)
    .focusedSceneValue(\.navigateSearchNextAction, focusedActions.navigateSearchNext)
    .focusedSceneValue(\.navigateSearchPreviousAction, focusedActions.navigateSearchPrevious)
    .focusedSceneValue(\.endSearchAction, focusedActions.endSearch)
  }

  private func syncSelectedSession() {
    terminalManager.handleCommand(.setSelectedSessionID(store.selectedSessionID))
  }

  static func makeFocusedActions(
    selectedSession: TerminalSession?,
    send: @escaping @MainActor (TerminalClient.Command) -> Void
  ) -> FocusedActions {
    guard let selectedSession else {
      return FocusedActions(
        newTerminal: nil,
        closeSurface: nil,
        closeTab: nil,
        startSearch: nil,
        searchSelection: nil,
        navigateSearchNext: nil,
        navigateSearchPrevious: nil,
        endSearch: nil
      )
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
      },
      startSearch: {
        send(.startSearch(selectedSession))
      },
      searchSelection: {
        send(.searchSelection(selectedSession))
      },
      navigateSearchNext: {
        send(.navigateSearchNext(selectedSession))
      },
      navigateSearchPrevious: {
        send(.navigateSearchPrevious(selectedSession))
      },
      endSearch: {
        send(.endSearch(selectedSession))
      }
    )
  }
}
