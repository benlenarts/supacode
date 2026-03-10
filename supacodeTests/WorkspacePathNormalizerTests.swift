import Foundation
import Testing

@testable import supacode

struct WorkspacePathNormalizerTests {
  @Test func normalizeTrimsDeduplicatesAndDropsMissingDirectories() throws {
    let fileManager = FileManager.default
    let baseDirectory = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let workspaceDirectory = baseDirectory.appending(path: "workspace", directoryHint: .isDirectory)
    try fileManager.createDirectory(at: workspaceDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: baseDirectory) }

    let normalized = WorkspacePathNormalizer.normalize([
      "  \(workspaceDirectory.path(percentEncoded: false))  ",
      workspaceDirectory.appending(path: ".", directoryHint: .isDirectory).path(percentEncoded: false),
      baseDirectory.appending(path: "missing", directoryHint: .isDirectory).path(percentEncoded: false),
      "",
    ])

    #expect(normalized == [workspaceDirectory.standardizedFileURL.path(percentEncoded: false)])
  }

  @Test func normalizeURLsKeepsInsertionOrder() throws {
    let fileManager = FileManager.default
    let baseDirectory = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let firstDirectory = baseDirectory.appending(path: "first", directoryHint: .isDirectory)
    let secondDirectory = baseDirectory.appending(path: "second", directoryHint: .isDirectory)
    try fileManager.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: secondDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: baseDirectory) }

    let normalized = WorkspacePathNormalizer.normalize([
      secondDirectory,
      firstDirectory,
      secondDirectory,
    ])

    #expect(
      normalized
        == [
          secondDirectory.standardizedFileURL.path(percentEncoded: false),
          firstDirectory.standardizedFileURL.path(percentEncoded: false),
        ]
    )
  }
}
