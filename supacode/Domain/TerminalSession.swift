import Foundation
import IdentifiedCollections

struct TerminalSession: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let detail: String
  let workingDirectory: URL
}

extension TerminalSession {
  static func workspaceSessions(from paths: [String]) -> IdentifiedArrayOf<Self> {
    IdentifiedArray(
      uniqueElements: paths.map { path in
        let workingDirectory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        let resolvedPath = workingDirectory.path(percentEncoded: false)
        return TerminalSession(
          id: resolvedPath,
          name: displayName(for: workingDirectory),
          detail: resolvedPath,
          workingDirectory: workingDirectory
        )
      }
    )
  }

  private static func displayName(for workingDirectory: URL) -> String {
    let name = workingDirectory.lastPathComponent
    return name.isEmpty ? workingDirectory.path(percentEncoded: false) : name
  }
}
