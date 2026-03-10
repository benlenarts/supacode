import Foundation

struct TerminalSession: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let detail: String
  let workingDirectory: URL
  let createdAt: Date?

  nonisolated init(
    id: String,
    name: String,
    detail: String,
    workingDirectory: URL,
    createdAt: Date? = nil
  ) {
    self.id = id
    self.name = name
    self.detail = detail
    self.workingDirectory = workingDirectory
    self.createdAt = createdAt
  }
}
