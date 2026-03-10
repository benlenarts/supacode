import ComposableArchitecture
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @Bindable var store: StoreOf<AppFeature>
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
    .fileImporter(
      isPresented: $store.isWorkspacePickerPresented.sending(\.setWorkspacePickerPresented),
      allowedContentTypes: [.folder],
      allowsMultipleSelection: true
    ) { result in
      guard case .success(let urls) = result else { return }
      store.send(.openWorkspaces(urls))
    }
    .focusedSceneValue(\.toggleLeftSidebarAction, toggleLeftSidebar)
    .onAppear(perform: syncWorkspaceSessions)
    .onChange(of: store.sessions.map(\.id)) { _, _ in
      syncWorkspaceSessions()
    }
  }

  private func toggleLeftSidebar() {
    withAnimation(.easeOut(duration: 0.2)) {
      leftSidebarVisibility = leftSidebarVisibility == .detailOnly ? .all : .detailOnly
    }
  }

  private func syncWorkspaceSessions() {
    terminalManager.handleCommand(.prune(Set(store.sessions.map(\.id))))
  }
}
