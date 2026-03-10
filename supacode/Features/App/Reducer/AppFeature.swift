import ComposableArchitecture
import IdentifiedCollections

@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    var sessions: IdentifiedArrayOf<TerminalSession>
    var selectedSessionID: TerminalSession.ID?

    init(sessions: IdentifiedArrayOf<TerminalSession> = TerminalSessionSeed.makeSessions()) {
      self.sessions = sessions
      selectedSessionID = sessions.first?.id
    }

    var selectedSession: TerminalSession? {
      guard let selectedSessionID else { return nil }
      return sessions[id: selectedSessionID]
    }
  }

  enum Action {
    case selectSession(TerminalSession.ID)
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .selectSession(let sessionID):
        guard state.selectedSessionID != sessionID else { return .none }
        guard state.sessions[id: sessionID] != nil else { return .none }
        state.selectedSessionID = sessionID
        return .none
      }
    }
  }
}
