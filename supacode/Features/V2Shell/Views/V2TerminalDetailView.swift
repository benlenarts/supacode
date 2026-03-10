import ComposableArchitecture
import SwiftUI

struct V2TerminalDetailView: View {
  let store: StoreOf<AppFeature>
  let terminalManager: TerminalSessionManager

  var body: some View {
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
  }

  private func syncSelectedSession() {
    terminalManager.handleCommand(.setSelectedSessionID(store.selectedSessionID))
  }
}
