import ComposableArchitecture
import Foundation
import Testing
@testable import supacode

struct AppFeatureV2Tests {
  @Test func initialStateSelectsTheFirstSession() {
    let sessions = seededSessions()
    let state = AppFeature.State(sessions: sessions)

    #expect(!state.sessions.isEmpty)
    #expect(state.selectedSessionID == sessions.first?.id)
    #expect(state.selectedSession?.id == sessions.first?.id)
  }

  @Test func selectingASessionUpdatesSelection() async throws {
    let sessions = seededSessions()
    let targetSession = try #require(sessions.last)
    let store = TestStore(initialState: AppFeature.State(sessions: sessions)) {
      AppFeature()
    }

    await store.send(.selectSession(targetSession.id)) {
      $0.selectedSessionID = targetSession.id
    }

    #expect(store.state.selectedSession?.id == targetSession.id)
  }

  @Test func seedBuildsSessionsFromExistingDirectories() throws {
    let fileManager = FileManager.default
    let baseDirectory = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let desktopDirectory = baseDirectory.appending(path: "Desktop", directoryHint: .isDirectory)
    let documentsDirectory = baseDirectory.appending(path: "Documents", directoryHint: .isDirectory)

    try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: desktopDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: baseDirectory) }

    let sessions = TerminalSessionSeed.makeSessions(
      candidateDirectories: [desktopDirectory, documentsDirectory],
      fallbackDirectory: baseDirectory,
      fileManager: fileManager
    )

    #expect(sessions.count == 4)
    #expect(sessions.allSatisfy { fileManager.fileExists(atPath: $0.workingDirectory.path(percentEncoded: false)) })
  }

  private func seededSessions() -> IdentifiedArrayOf<TerminalSession> {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
    return TerminalSessionSeed.makeSessions(
      candidateDirectories: [homeDirectory],
      fallbackDirectory: homeDirectory,
      fileManager: .default
    )
  }
}
