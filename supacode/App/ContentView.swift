import ComposableArchitecture
import SwiftUI

struct ContentView: View {
  let store: StoreOf<AppFeature>
  let terminalManager: TerminalSessionManager
  @State private var leftSidebarVisibility: NavigationSplitViewVisibility = .all

  var body: some View {
    NavigationSplitView(columnVisibility: $leftSidebarVisibility) {
      V2SidebarView(store: store)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    } detail: {
      V2TerminalDetailView(store: store, terminalManager: terminalManager)
    }
    .navigationSplitViewStyle(.automatic)
    .focusedSceneValue(\.toggleLeftSidebarAction, toggleLeftSidebar)
  }

  private func toggleLeftSidebar() {
    withAnimation(.easeOut(duration: 0.2)) {
      leftSidebarVisibility = leftSidebarVisibility == .detailOnly ? .all : .detailOnly
    }
  }
}
