import ComposableArchitecture
import Foundation
import Sharing
import Testing

@testable import supacode

@MainActor
struct AppFeatureV2Tests {
  @Test func initialStateWithoutWorkspacesHasNoSelection() {
    let state = AppFeature.State(workspacePaths: makeWorkspacePathsShared([]))

    #expect(state.sessions.isEmpty)
    #expect(state.selectedSessionID == nil)
    #expect(state.selectedSession == nil)
  }

  @Test func initialStateSelectsTheFirstWorkspace() throws {
    let (rootDirectory, workspacePaths) = try makeWorkspacePaths()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }
    let state = AppFeature.State(workspacePaths: makeWorkspacePathsShared(workspacePaths))

    let firstSession = try #require(state.sessions.first)
    #expect(state.selectedSessionID == firstSession.id)
    #expect(state.selectedSession?.id == firstSession.id)
  }

  @Test func selectingASessionUpdatesSelection() async throws {
    let (rootDirectory, workspacePaths) = try makeWorkspacePaths()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }
    let state = AppFeature.State(workspacePaths: makeWorkspacePathsShared(workspacePaths))
    let targetSession = try #require(state.sessions.last)
    let store = TestStore(initialState: state) {
      AppFeature()
    }

    await store.send(.selectSession(targetSession.id)) {
      $0.selectedSessionID = targetSession.id
    }

    #expect(store.state.selectedSession?.id == targetSession.id)
  }

  @Test func openingWorkspacesMergesDirectoriesAndSelectsTheFirstNewWorkspace() async throws {
    let fileManager = FileManager.default
    let baseDirectory = try makeWorkspaceRoot(named: UUID().uuidString)
    defer { try? fileManager.removeItem(at: baseDirectory) }

    let existingDirectory = baseDirectory.appending(path: "existing", directoryHint: .isDirectory)
    let newDirectory = baseDirectory.appending(path: "new", directoryHint: .isDirectory)
    let extraDirectory = baseDirectory.appending(path: "extra", directoryHint: .isDirectory)
    try fileManager.createDirectory(at: existingDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: extraDirectory, withIntermediateDirectories: true)

    let existingPath = existingDirectory.standardizedFileURL.path(percentEncoded: false)
    let newPath = newDirectory.standardizedFileURL.path(percentEncoded: false)
    let extraPath = extraDirectory.standardizedFileURL.path(percentEncoded: false)

    let store = TestStore(
      initialState: AppFeature.State(
        selectedSessionID: existingPath,
        workspacePaths: makeWorkspacePathsShared([existingPath])
      )
    ) {
      AppFeature()
    }

    await store.send(
      AppFeature.Action.openWorkspaces([
        existingDirectory,
        newDirectory,
        extraDirectory,
      ])
    ) {
      $0.$workspacePaths.withLock {
        $0 = [existingPath, newPath, extraPath]
      }
      $0.selectedSessionID = newPath
    }
  }

  @Test func removingSelectedWorkspaceFallsBackToNextWorkspace() async throws {
    let (rootDirectory, workspacePaths) = try makeWorkspacePaths()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }
    let store = TestStore(
      initialState: AppFeature.State(
        selectedSessionID: workspacePaths[1],
        workspacePaths: makeWorkspacePathsShared(workspacePaths)
      )
    ) {
      AppFeature()
    }

    await store.send(.removeWorkspace(workspacePaths[1])) {
      $0.$workspacePaths.withLock {
        $0 = [workspacePaths[0], workspacePaths[2]]
      }
      $0.selectedSessionID = workspacePaths[2]
    }
  }

  @Test func removingLastWorkspaceClearsSelection() async throws {
    let (rootDirectory, workspacePaths) = try makeWorkspacePaths()
    defer { try? FileManager.default.removeItem(at: rootDirectory) }
    let onlyPath = try #require(workspacePaths.first)
    let store = TestStore(
      initialState: AppFeature.State(workspacePaths: makeWorkspacePathsShared([onlyPath]))
    ) {
      AppFeature()
    }

    await store.send(.removeWorkspace(onlyPath)) {
      $0.$workspacePaths.withLock {
        $0 = []
      }
      $0.selectedSessionID = nil
    }
  }

  private func makeWorkspacePaths() throws -> (URL, [String]) {
    let rootDirectory = try makeWorkspaceRoot(named: UUID().uuidString)
    let fileManager = FileManager.default
    let workspaceDirectories = [
      rootDirectory.appending(path: "workspace-a", directoryHint: .isDirectory),
      rootDirectory.appending(path: "workspace-b", directoryHint: .isDirectory),
      rootDirectory.appending(path: "workspace-c", directoryHint: .isDirectory),
    ]
    for directory in workspaceDirectories {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    return (
      rootDirectory,
      workspaceDirectories.map { $0.standardizedFileURL.path(percentEncoded: false) }
    )
  }

  private func makeWorkspacePathsShared(_ paths: [String]) -> Shared<[String]> {
    Shared(wrappedValue: paths, .inMemory(UUID().uuidString))
  }

  private func makeWorkspaceRoot(named name: String) throws -> URL {
    let fileManager = FileManager.default
    let baseDirectory = fileManager.temporaryDirectory.appending(path: name, directoryHint: .isDirectory)
    try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    return baseDirectory
  }
}
