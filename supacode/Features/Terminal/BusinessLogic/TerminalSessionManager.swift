import Observation

private let terminalLogger = SupaLogger("Terminal")

@MainActor
@Observable
final class TerminalSessionManager {
  private let runtime: GhosttyRuntime
  private var states: [TerminalSession.ID: TerminalSessionState] = [:]
  private var notificationsEnabled = true
  private var lastNotificationIndicatorCount: Int?
  private var eventContinuation: AsyncStream<TerminalClient.Event>.Continuation?
  private var pendingEvents: [TerminalClient.Event] = []
  var selectedSessionID: TerminalSession.ID?

  init(runtime: GhosttyRuntime) {
    self.runtime = runtime
  }

  func handleCommand(_ command: TerminalClient.Command) {
    if handleTabCommand(command) {
      return
    }
    if handleBindingActionCommand(command) {
      return
    }
    if handleSearchCommand(command) {
      return
    }
    handleManagementCommand(command)
  }

  private func handleTabCommand(_ command: TerminalClient.Command) -> Bool {
    switch command {
    case .createTab(let session, let runSetupScriptIfNew):
      Task { createTabAsync(in: session, runSetupScriptIfNew: runSetupScriptIfNew) }
    case .createTabWithInput(let session, let input, let runSetupScriptIfNew):
      Task {
        createTabAsync(in: session, runSetupScriptIfNew: runSetupScriptIfNew, initialInput: input)
      }
    case .ensureInitialTab(let session, let runSetupScriptIfNew, let focusing):
      let state = state(for: session) { runSetupScriptIfNew }
      state.ensureInitialTab(focusing: focusing)
    case .runScript(let session, let script):
      _ = state(for: session).runScript(script)
    case .stopRunScript(let session):
      _ = state(for: session).stopRunScript()
    case .closeFocusedTab(let session):
      _ = closeFocusedTab(in: session)
    case .closeFocusedSurface(let session):
      _ = closeFocusedSurface(in: session)
    default:
      return false
    }
    return true
  }

  private func handleSearchCommand(_ command: TerminalClient.Command) -> Bool {
    switch command {
    case .startSearch(let session):
      state(for: session).performBindingActionOnFocusedSurface("start_search")
    case .searchSelection(let session):
      state(for: session).performBindingActionOnFocusedSurface("search_selection")
    case .navigateSearchNext(let session):
      state(for: session).navigateSearchOnFocusedSurface(.next)
    case .navigateSearchPrevious(let session):
      state(for: session).navigateSearchOnFocusedSurface(.previous)
    case .endSearch(let session):
      state(for: session).performBindingActionOnFocusedSurface("end_search")
    default:
      return false
    }
    return true
  }

  private func handleBindingActionCommand(_ command: TerminalClient.Command) -> Bool {
    switch command {
    case .performBindingAction(let session, let action):
      state(for: session).performBindingActionOnFocusedSurface(action)
    default:
      return false
    }
    return true
  }

  private func handleManagementCommand(_ command: TerminalClient.Command) {
    switch command {
    case .prune(let ids):
      prune(keeping: ids)
    case .setNotificationsEnabled(let enabled):
      setNotificationsEnabled(enabled)
    case .setSelectedSessionID(let id):
      guard id != selectedSessionID else { return }
      if let previousID = selectedSessionID, let previousState = states[previousID] {
        previousState.setAllSurfacesOccluded()
      }
      selectedSessionID = id
      terminalLogger.info("Selected session \(id ?? "nil")")
    default:
      return
    }
  }

  func eventStream() -> AsyncStream<TerminalClient.Event> {
    eventContinuation?.finish()
    let (stream, continuation) = AsyncStream.makeStream(of: TerminalClient.Event.self)
    eventContinuation = continuation
    lastNotificationIndicatorCount = nil
    if !pendingEvents.isEmpty {
      let bufferedEvents = pendingEvents
      pendingEvents.removeAll()
      for event in bufferedEvents {
        if case .notificationIndicatorChanged = event {
          continue
        }
        continuation.yield(event)
      }
    }
    emitNotificationIndicatorCountIfNeeded()
    return stream
  }

  func state(
    for session: TerminalSession,
    runSetupScriptIfNew: () -> Bool = { false }
  ) -> TerminalSessionState {
    if let existing = states[session.id] {
      if runSetupScriptIfNew() {
        existing.enableSetupScriptIfNeeded()
      }
      return existing
    }
    let runSetupScript = runSetupScriptIfNew()
    let state = TerminalSessionState(
      runtime: runtime,
      session: session,
      runSetupScript: runSetupScript
    )
    state.setNotificationsEnabled(notificationsEnabled)
    state.isSelected = { [weak self] in
      self?.selectedSessionID == session.id
    }
    state.onNotificationReceived = { [weak self] title, body in
      self?.emit(.notificationReceived(sessionID: session.id, title: title, body: body))
    }
    state.onNotificationIndicatorChanged = { [weak self] in
      self?.emitNotificationIndicatorCountIfNeeded()
    }
    state.onTabCreated = { [weak self] in
      self?.emit(.tabCreated(sessionID: session.id))
    }
    state.onTabClosed = { [weak self] in
      self?.emit(.tabClosed(sessionID: session.id))
    }
    state.onFocusChanged = { [weak self] surfaceID in
      self?.emit(.focusChanged(sessionID: session.id, surfaceID: surfaceID))
    }
    state.onTaskStatusChanged = { [weak self] status in
      self?.emit(.taskStatusChanged(sessionID: session.id, status: status))
    }
    state.onRunScriptStatusChanged = { [weak self] isRunning in
      self?.emit(.runScriptStatusChanged(sessionID: session.id, isRunning: isRunning))
    }
    state.onCommandPaletteToggle = { [weak self] in
      self?.emit(.commandPaletteToggleRequested(sessionID: session.id))
    }
    state.onSetupScriptConsumed = { [weak self] in
      self?.emit(.setupScriptConsumed(sessionID: session.id))
    }
    states[session.id] = state
    terminalLogger.info("Created terminal state for session \(session.id)")
    return state
  }

  private func createTabAsync(
    in session: TerminalSession,
    runSetupScriptIfNew: Bool,
    initialInput: String? = nil
  ) {
    let state = state(for: session) { runSetupScriptIfNew }
    _ = state.createTab(setupScript: nil, initialInput: initialInput)
  }

  @discardableResult
  func closeFocusedTab(in session: TerminalSession) -> Bool {
    let state = state(for: session)
    return state.closeFocusedTab()
  }

  @discardableResult
  func closeFocusedSurface(in session: TerminalSession) -> Bool {
    let state = state(for: session)
    return state.closeFocusedSurface()
  }

  func prune(keeping sessionIDs: Set<TerminalSession.ID>) {
    var removed: [TerminalSessionState] = []
    for (id, state) in states where !sessionIDs.contains(id) {
      removed.append(state)
    }
    for state in removed {
      state.closeAllSurfaces()
    }
    if !removed.isEmpty {
      terminalLogger.info("Pruned \(removed.count) terminal state(s)")
    }
    states = states.filter { sessionIDs.contains($0.key) }
    emitNotificationIndicatorCountIfNeeded()
  }

  func stateIfExists(for sessionID: TerminalSession.ID) -> TerminalSessionState? {
    states[sessionID]
  }

  func taskStatus(for sessionID: TerminalSession.ID) -> TerminalTaskStatus? {
    states[sessionID]?.taskStatus
  }

  func isRunScriptRunning(for sessionID: TerminalSession.ID) -> Bool {
    states[sessionID]?.isRunScriptRunning == true
  }

  func setNotificationsEnabled(_ enabled: Bool) {
    notificationsEnabled = enabled
    for state in states.values {
      state.setNotificationsEnabled(enabled)
    }
    emitNotificationIndicatorCountIfNeeded()
  }

  func hasUnseenNotifications(for sessionID: TerminalSession.ID) -> Bool {
    states[sessionID]?.hasUnseenNotification == true
  }

  func surfaceBackgroundOpacity() -> Double {
    runtime.backgroundOpacity()
  }

  private func emit(_ event: TerminalClient.Event) {
    guard let eventContinuation else {
      pendingEvents.append(event)
      return
    }
    eventContinuation.yield(event)
  }

  private func emitNotificationIndicatorCountIfNeeded() {
    let count = states.values.reduce(0) { count, state in
      count + (state.hasUnseenNotification ? 1 : 0)
    }
    if count != lastNotificationIndicatorCount {
      lastNotificationIndicatorCount = count
      emit(.notificationIndicatorChanged(count: count))
    }
  }
}
