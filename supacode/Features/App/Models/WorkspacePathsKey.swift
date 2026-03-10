import Foundation
import Sharing

nonisolated struct WorkspacePathsKeyID: Hashable, Sendable {}

nonisolated struct WorkspacePathsKey: SharedKey {
  var id: WorkspacePathsKeyID {
    WorkspacePathsKeyID()
  }

  func load(
    context _: LoadContext<[String]>,
    continuation: LoadContinuation<[String]>
  ) {
    @Shared(.appStorage("workspacePaths")) var storedPaths: [String] = []
    let normalized = WorkspacePathNormalizer.normalize(storedPaths)
    if normalized != storedPaths {
      $storedPaths.withLock {
        $0 = normalized
      }
    }
    continuation.resume(returning: normalized)
  }

  func subscribe(
    context _: LoadContext<[String]>,
    subscriber _: SharedSubscriber<[String]>
  ) -> SharedSubscription {
    SharedSubscription {}
  }

  func save(
    _ value: [String],
    context _: SaveContext,
    continuation: SaveContinuation
  ) {
    @Shared(.appStorage("workspacePaths")) var storedPaths: [String] = []
    let normalized = WorkspacePathNormalizer.normalize(value)
    $storedPaths.withLock {
      $0 = normalized
    }
    continuation.resume()
  }
}

nonisolated extension SharedReaderKey where Self == WorkspacePathsKey.Default {
  static var workspacePaths: Self {
    Self[WorkspacePathsKey(), default: []]
  }
}

nonisolated enum WorkspacePathNormalizer {
  static func normalize(_ urls: [URL], fileManager: FileManager = .default) -> [String] {
    normalize(
      urls.map { $0.standardizedFileURL.path(percentEncoded: false) },
      fileManager: fileManager
    )
  }

  static func normalize(_ paths: [String], fileManager: FileManager = .default) -> [String] {
    var normalized: [String] = []
    var seen: Set<String> = []
    normalized.reserveCapacity(paths.count)

    for path in paths {
      let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }
      let resolvedPath = URL(fileURLWithPath: trimmed, isDirectory: true)
        .standardizedFileURL
        .path(percentEncoded: false)
      guard seen.insert(resolvedPath).inserted else { continue }
      guard directoryExists(atPath: resolvedPath, fileManager: fileManager) else { continue }
      normalized.append(resolvedPath)
    }

    return normalized
  }

  private static func directoryExists(atPath path: String, fileManager: FileManager) -> Bool {
    var isDirectory = ObjCBool(false)
    guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }
    return isDirectory.boolValue
  }
}
