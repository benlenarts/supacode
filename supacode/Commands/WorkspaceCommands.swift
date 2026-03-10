import ComposableArchitecture
import SwiftUI

struct WorkspaceCommands: Commands {
  let store: StoreOf<AppFeature>

  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      Button("Open Workspace...", systemImage: "folder") {
        store.send(.setWorkspacePickerPresented(true))
      }
      .keyboardShortcut(
        AppShortcuts.openWorkspace.keyEquivalent,
        modifiers: AppShortcuts.openWorkspace.modifiers
      )
      .help("Open Workspace (\(AppShortcuts.openWorkspace.display))")
    }
  }
}
