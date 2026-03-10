import ComposableArchitecture
import SwiftUI

struct V2SidebarView: View {
  let store: StoreOf<AppFeature>

  var body: some View {
    List {
      ForEach(store.sessions) { session in
        Button {
          store.send(.selectSession(session.id))
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(session.name)
              .font(.body.monospaced())
            Text(session.detail)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 4)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open \(session.name)")
        .contextMenu {
          Button("Remove Workspace", systemImage: "trash") {
            store.send(.removeWorkspace(session.id))
          }
        }
        .listRowBackground(rowBackground(for: session.id))
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("Workspaces")
    .safeAreaInset(edge: .bottom) {
      V2SidebarFooterView(store: store)
    }
  }

  @ViewBuilder
  private func rowBackground(for sessionID: TerminalSession.ID) -> some View {
    if store.selectedSessionID == sessionID {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.accentColor.opacity(0.14))
        .padding(.vertical, 2)
    } else {
      Color.clear
    }
  }
}

private struct V2SidebarFooterView: View {
  let store: StoreOf<AppFeature>

  var body: some View {
    HStack {
      Button {
        store.send(.setWorkspacePickerPresented(true))
      } label: {
        Label("Add Workspace", systemImage: "folder.badge.plus")
          .font(.callout)
      }
      .help("Add Workspace (\(AppShortcuts.openWorkspace.display))")
      Spacer()
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .top) {
      Divider()
    }
  }
}
