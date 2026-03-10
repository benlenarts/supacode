import ComposableArchitecture
import Foundation
import IdentifiedCollections
import Sharing

@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    @Shared(.workspacePaths) var workspacePaths: [String] = []
    var isWorkspacePickerPresented = false
    var selectedSessionID: TerminalSession.ID?

    init(
      isWorkspacePickerPresented: Bool = false,
      selectedSessionID: TerminalSession.ID? = nil,
      workspacePaths: Shared<[String]> = Shared(wrappedValue: [], .workspacePaths)
    ) {
      _workspacePaths = workspacePaths
      self.isWorkspacePickerPresented = isWorkspacePickerPresented
      let sessions = TerminalSession.workspaceSessions(from: self.workspacePaths)
      if let selectedSessionID, sessions[id: selectedSessionID] != nil {
        self.selectedSessionID = selectedSessionID
      } else {
        self.selectedSessionID = sessions.first?.id
      }
    }

    var sessions: IdentifiedArrayOf<TerminalSession> {
      TerminalSession.workspaceSessions(from: workspacePaths)
    }

    var selectedSession: TerminalSession? {
      guard let selectedSessionID else { return nil }
      return sessions[id: selectedSessionID]
    }
  }

  enum Action {
    case openWorkspaces([URL])
    case selectSession(TerminalSession.ID)
    case removeWorkspace(TerminalSession.ID)
    case setWorkspacePickerPresented(Bool)
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .openWorkspaces(let urls):
        let previousSessions = state.sessions
        let previousPaths = state.workspacePaths
        let existingPaths = Set(previousPaths)
        let mergedPaths = WorkspacePathNormalizer.normalize(previousPaths + WorkspacePathNormalizer.normalize(urls))
        guard mergedPaths != previousPaths else { return .none }
        let preferredSelection = mergedPaths.first(where: { !existingPaths.contains($0) })
        state.$workspacePaths.withLock {
          $0 = mergedPaths
        }
        state.selectedSessionID = selectedSessionID(
          currentSelection: state.selectedSessionID,
          previousSessions: previousSessions,
          updatedSessions: state.sessions,
          preferredSelection: preferredSelection
        )
        return .none

      case .selectSession(let sessionID):
        guard state.selectedSessionID != sessionID else { return .none }
        guard state.sessions[id: sessionID] != nil else { return .none }
        state.selectedSessionID = sessionID
        return .none

      case .removeWorkspace(let sessionID):
        guard state.sessions[id: sessionID] != nil else { return .none }
        let previousSessions = state.sessions
        state.$workspacePaths.withLock {
          $0.removeAll { $0 == sessionID }
        }
        state.selectedSessionID = selectedSessionID(
          currentSelection: state.selectedSessionID,
          previousSessions: previousSessions,
          updatedSessions: state.sessions
        )
        return .none

      case .setWorkspacePickerPresented(let isPresented):
        state.isWorkspacePickerPresented = isPresented
        return .none
      }
    }
  }

  private func selectedSessionID(
    currentSelection: TerminalSession.ID?,
    previousSessions: IdentifiedArrayOf<TerminalSession>,
    updatedSessions: IdentifiedArrayOf<TerminalSession>,
    preferredSelection: TerminalSession.ID? = nil
  ) -> TerminalSession.ID? {
    if let preferredSelection, updatedSessions[id: preferredSelection] != nil {
      return preferredSelection
    }

    if let currentSelection, updatedSessions[id: currentSelection] != nil {
      return currentSelection
    }

    guard let currentSelection else {
      return updatedSessions.first?.id
    }

    guard let previousIndex = previousSessions.index(id: currentSelection) else {
      return updatedSessions.first?.id
    }

    if previousIndex < updatedSessions.count {
      return updatedSessions[previousIndex].id
    }

    return updatedSessions.last?.id
  }
}
