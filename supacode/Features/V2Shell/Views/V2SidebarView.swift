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
        .listRowBackground(rowBackground(for: session.id))
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("Sessions")
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
