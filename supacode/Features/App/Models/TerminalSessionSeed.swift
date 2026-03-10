import Foundation
import IdentifiedCollections

enum TerminalSessionSeed {
  static func makeSessions(fileManager: FileManager = .default) -> IdentifiedArrayOf<TerminalSession> {
    let homeDirectory = fileManager.homeDirectoryForCurrentUser.standardizedFileURL
    let candidateDirectories = [
      homeDirectory.appending(path: "Desktop", directoryHint: .isDirectory),
      homeDirectory.appending(path: "Documents", directoryHint: .isDirectory),
      homeDirectory.appending(path: "Downloads", directoryHint: .isDirectory),
      homeDirectory,
    ]
    return makeSessions(
      candidateDirectories: candidateDirectories,
      fallbackDirectory: homeDirectory,
      fileManager: fileManager
    )
  }

  static func makeSessions(
    candidateDirectories: [URL],
    fallbackDirectory: URL,
    fileManager: FileManager = .default
  ) -> IdentifiedArrayOf<TerminalSession> {
    let resolvedFallbackDirectory = fallbackDirectory.standardizedFileURL
    let directories = existingDirectories(
      from: candidateDirectories,
      fallbackDirectory: resolvedFallbackDirectory,
      fileManager: fileManager
    )
    let workingDirectories = resolvedWorkingDirectories(
      from: directories,
      fallbackDirectory: resolvedFallbackDirectory,
      count: 4
    )
    return IdentifiedArray(uniqueElements: [
      makeSession(
        id: "focus",
        name: "Focus",
        detail: "Primary terminal lane",
        workingDirectory: workingDirectories[0]
      ),
      makeSession(
        id: "scratch",
        name: "Scratch",
        detail: "Quick experiments",
        workingDirectory: workingDirectories[1]
      ),
      makeSession(
        id: "notes",
        name: "Notes",
        detail: "Long-running context",
        workingDirectory: workingDirectories[2]
      ),
      makeSession(
        id: "ops",
        name: "Ops",
        detail: "Utility commands",
        workingDirectory: workingDirectories[3]
      ),
    ])
  }

  private static func makeSession(
    id: TerminalSession.ID,
    name: String,
    detail: String,
    workingDirectory: URL
  ) -> TerminalSession {
    TerminalSession(
      id: id,
      name: name,
      detail: detail,
      workingDirectory: workingDirectory.standardizedFileURL
    )
  }

  private static func existingDirectories(
    from candidateDirectories: [URL],
    fallbackDirectory: URL,
    fileManager: FileManager
  ) -> [URL] {
    var directories: [URL] = []
    var seenPaths: Set<String> = []

    for directory in candidateDirectories + [fallbackDirectory] {
      let standardizedDirectory = directory.standardizedFileURL
      let path = standardizedDirectory.path(percentEncoded: false)
      guard seenPaths.insert(path).inserted else { continue }
      guard directoryExists(standardizedDirectory, fileManager: fileManager) else { continue }
      directories.append(standardizedDirectory)
    }

    if directories.isEmpty {
      directories.append(fallbackDirectory.standardizedFileURL)
    }

    return directories
  }

  private static func resolvedWorkingDirectories(
    from directories: [URL],
    fallbackDirectory: URL,
    count: Int
  ) -> [URL] {
    var resolved = Array(directories.prefix(count))
    while resolved.count < count {
      resolved.append(fallbackDirectory.standardizedFileURL)
    }
    return resolved
  }

  private static func directoryExists(_ directory: URL, fileManager: FileManager) -> Bool {
    var isDirectory = ObjCBool(false)
    let path = directory.path(percentEncoded: false)
    let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
  }
}
