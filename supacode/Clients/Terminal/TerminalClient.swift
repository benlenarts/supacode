import ComposableArchitecture
import Foundation

struct TerminalClient {
  var send: @MainActor @Sendable (Command) -> Void
  var events: @MainActor @Sendable () -> AsyncStream<Event>

  enum Command: Equatable {
    case createTab(TerminalSession, runSetupScriptIfNew: Bool)
    case createTabWithInput(TerminalSession, input: String, runSetupScriptIfNew: Bool)
    case ensureInitialTab(TerminalSession, runSetupScriptIfNew: Bool, focusing: Bool)
    case runScript(TerminalSession, script: String)
    case stopRunScript(TerminalSession)
    case closeFocusedTab(TerminalSession)
    case closeFocusedSurface(TerminalSession)
    case performBindingAction(TerminalSession, action: String)
    case startSearch(TerminalSession)
    case searchSelection(TerminalSession)
    case navigateSearchNext(TerminalSession)
    case navigateSearchPrevious(TerminalSession)
    case endSearch(TerminalSession)
    case prune(Set<TerminalSession.ID>)
    case setNotificationsEnabled(Bool)
    case setSelectedSessionID(TerminalSession.ID?)
  }

  enum Event: Equatable {
    case notificationReceived(sessionID: TerminalSession.ID, title: String, body: String)
    case notificationIndicatorChanged(count: Int)
    case tabCreated(sessionID: TerminalSession.ID)
    case tabClosed(sessionID: TerminalSession.ID)
    case focusChanged(sessionID: TerminalSession.ID, surfaceID: UUID)
    case taskStatusChanged(sessionID: TerminalSession.ID, status: TerminalTaskStatus)
    case runScriptStatusChanged(sessionID: TerminalSession.ID, isRunning: Bool)
    case commandPaletteToggleRequested(sessionID: TerminalSession.ID)
    case setupScriptConsumed(sessionID: TerminalSession.ID)
  }
}

extension TerminalClient: DependencyKey {
  static let liveValue = TerminalClient(
    send: { _ in fatalError("TerminalClient.send not configured") },
    events: { fatalError("TerminalClient.events not configured") }
  )

  static let testValue = TerminalClient(
    send: { _ in },
    events: { AsyncStream { $0.finish() } }
  )
}

extension DependencyValues {
  var terminalClient: TerminalClient {
    get { self[TerminalClient.self] }
    set { self[TerminalClient.self] = newValue }
  }
}
