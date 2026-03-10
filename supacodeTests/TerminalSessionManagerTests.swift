import Foundation
import Testing

@testable import supacode

@MainActor
struct TerminalSessionManagerTests {
  @Test func buffersEventsUntilStreamCreated() async {
    let manager = TerminalSessionManager(runtime: GhosttyRuntime(skipNativeRuntime: true))
    let session = makeTerminalSession()
    let state = manager.state(for: session)

    state.onSetupScriptConsumed?()

    let stream = manager.eventStream()
    let event = await nextEvent(stream) { event in
      if case .setupScriptConsumed = event {
        return true
      }
      return false
    }

    #expect(event == .setupScriptConsumed(sessionID: session.id))
  }

  @Test func emitsEventsAfterStreamCreated() async {
    let manager = TerminalSessionManager(runtime: GhosttyRuntime(skipNativeRuntime: true))
    let session = makeTerminalSession()
    let state = manager.state(for: session)

    let stream = manager.eventStream()
    let eventTask = Task {
      await nextEvent(stream) { event in
        if case .setupScriptConsumed = event {
          return true
        }
        return false
      }
    }

    state.onSetupScriptConsumed?()

    let event = await eventTask.value
    #expect(event == .setupScriptConsumed(sessionID: session.id))
  }

  @Test func notificationIndicatorUsesCurrentCountOnStreamStart() async {
    let manager = TerminalSessionManager(runtime: GhosttyRuntime(skipNativeRuntime: true))
    let session = makeTerminalSession()
    let state = manager.state(for: session)

    state.notifications = [
      TerminalNotification(
        surfaceId: UUID(),
        title: "Unread",
        body: "body",
        isRead: false
      ),
    ]
    state.onNotificationIndicatorChanged?()
    state.notifications = [
      TerminalNotification(
        surfaceId: UUID(),
        title: "Read",
        body: "body",
        isRead: true
      ),
    ]

    let stream = manager.eventStream()
    var iterator = stream.makeAsyncIterator()

    let first = await iterator.next()
    state.onSetupScriptConsumed?()
    let second = await iterator.next()

    #expect(first == .notificationIndicatorChanged(count: 0))
    #expect(second == .setupScriptConsumed(sessionID: session.id))
  }

  @Test func taskStatusReflectsAnyRunningTab() {
    let manager = TerminalSessionManager(runtime: GhosttyRuntime(skipNativeRuntime: true))
    let session = makeTerminalSession()
    let state = manager.state(for: session)

    #expect(manager.taskStatus(for: session.id) == .idle)

    let tab1 = TerminalTabID()
    let tab2 = TerminalTabID()
    state.tabIsRunningById[tab1] = false
    state.tabIsRunningById[tab2] = false
    #expect(manager.taskStatus(for: session.id) == .idle)

    state.tabIsRunningById[tab2] = true
    #expect(manager.taskStatus(for: session.id) == .running)

    state.tabIsRunningById[tab1] = true
    #expect(manager.taskStatus(for: session.id) == .running)

    state.tabIsRunningById[tab2] = false
    #expect(manager.taskStatus(for: session.id) == .running)

    state.tabIsRunningById[tab1] = false
    #expect(manager.taskStatus(for: session.id) == .idle)
  }

  @Test func hasUnseenNotificationsReflectsUnreadEntries() {
    let manager = TerminalSessionManager(runtime: GhosttyRuntime(skipNativeRuntime: true))
    let session = makeTerminalSession()
    let state = manager.state(for: session)

    state.notifications = [
      makeNotification(isRead: true),
      makeNotification(isRead: true),
    ]

    #expect(manager.hasUnseenNotifications(for: session.id) == false)

    state.notifications.append(makeNotification(isRead: false))

    #expect(manager.hasUnseenNotifications(for: session.id) == true)
  }

  @Test func markAllNotificationsReadEmitsUpdatedIndicatorCount() async {
    let manager = TerminalSessionManager(runtime: GhosttyRuntime(skipNativeRuntime: true))
    let session = makeTerminalSession()
    let state = manager.state(for: session)

    state.notifications = [
      makeNotification(isRead: false),
      makeNotification(isRead: true),
    ]

    let stream = manager.eventStream()
    var iterator = stream.makeAsyncIterator()

    let first = await iterator.next()
    state.markAllNotificationsRead()
    let second = await iterator.next()

    #expect(first == .notificationIndicatorChanged(count: 1))
    #expect(second == .notificationIndicatorChanged(count: 0))
    #expect(state.notifications.map(\.isRead) == [true, true])
  }

  @Test func markNotificationsReadOnlyAffectsMatchingSurface() {
    let manager = TerminalSessionManager(runtime: GhosttyRuntime(skipNativeRuntime: true))
    let session = makeTerminalSession()
    let state = manager.state(for: session)
    let surfaceA = UUID()
    let surfaceB = UUID()

    state.notifications = [
      makeNotification(surfaceId: surfaceA, isRead: false),
      makeNotification(surfaceId: surfaceB, isRead: false),
      makeNotification(surfaceId: surfaceB, isRead: true),
    ]

    state.markNotificationsRead(forSurfaceID: surfaceB)

    let aNotifications = state.notifications.filter { $0.surfaceId == surfaceA }
    let bNotifications = state.notifications.filter { $0.surfaceId == surfaceB }

    #expect(aNotifications.map(\.isRead) == [false])
    #expect(bNotifications.map(\.isRead) == [true, true])
    #expect(manager.hasUnseenNotifications(for: session.id) == true)

    state.markNotificationsRead(forSurfaceID: surfaceA)

    #expect(manager.hasUnseenNotifications(for: session.id) == false)
  }

  @Test func setNotificationsDisabledMarksAllRead() {
    let manager = TerminalSessionManager(runtime: GhosttyRuntime(skipNativeRuntime: true))
    let session = makeTerminalSession()
    let state = manager.state(for: session)

    state.notifications = [
      makeNotification(isRead: false),
      makeNotification(isRead: false),
    ]

    state.setNotificationsEnabled(false)

    #expect(state.notifications.map(\.isRead) == [true, true])
    #expect(manager.hasUnseenNotifications(for: session.id) == false)
  }

  @Test func dismissAllNotificationsClearsState() {
    let manager = TerminalSessionManager(runtime: GhosttyRuntime(skipNativeRuntime: true))
    let session = makeTerminalSession()
    let state = manager.state(for: session)

    state.notifications = [
      makeNotification(isRead: false),
      makeNotification(isRead: true),
    ]

    state.dismissAllNotifications()

    #expect(state.notifications.isEmpty)
    #expect(manager.hasUnseenNotifications(for: session.id) == false)
  }

  private func makeTerminalSession() -> TerminalSession {
    TerminalSession(
      id: "/tmp/session-1",
      name: "session-1",
      detail: "detail",
      workingDirectory: URL(fileURLWithPath: "/tmp/session-1")
    )
  }

  private func nextEvent(
    _ stream: AsyncStream<TerminalClient.Event>,
    matching predicate: (TerminalClient.Event) -> Bool
  ) async -> TerminalClient.Event? {
    for await event in stream where predicate(event) {
      return event
    }
    return nil
  }

  private func makeNotification(
    surfaceId: UUID = UUID(),
    isRead: Bool
  ) -> TerminalNotification {
    TerminalNotification(
      surfaceId: surfaceId,
      title: "Title",
      body: "Body",
      isRead: isRead
    )
  }
}
