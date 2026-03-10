import AppKit
import Foundation
import GhosttyKit
import UniformTypeIdentifiers

@MainActor
enum GhosttyActionSupport {
  enum ClipboardRequest: Equatable {
    case paste
    case osc52Read
    case osc52Write

    init?(request: ghostty_clipboard_request_e) {
      switch request {
      case GHOSTTY_CLIPBOARD_REQUEST_PASTE:
        self = .paste
      case GHOSTTY_CLIPBOARD_REQUEST_OSC_52_READ:
        self = .osc52Read
      case GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE:
        self = .osc52Write
      default:
        return nil
      }
    }

    var title: String {
      switch self {
      case .paste:
        return "Paste into terminal?"
      case .osc52Read:
        return "Allow clipboard read?"
      case .osc52Write:
        return "Allow clipboard write?"
      }
    }

    var message: String {
      switch self {
      case .paste:
        return "The text below may execute commands when pasted into the terminal."
      case .osc52Read:
        return "A program running in the terminal wants to read the clipboard."
      case .osc52Write:
        return "A program running in the terminal wants to write to the clipboard."
      }
    }

    var confirmButtonTitle: String {
      switch self {
      case .paste:
        return "Paste"
      case .osc52Read, .osc52Write:
        return "Allow"
      }
    }

    var alertStyle: NSAlert.Style {
      switch self {
      case .paste:
        return .warning
      case .osc52Read, .osc52Write:
        return .informational
      }
    }
  }

  private static let logger = SupaLogger("GhosttyAction")
  private static let previewLimit = 1_500

  static var clipboardConfirmationHandler: (ClipboardRequest, String) -> Bool = {
    request,
    value in
    presentConfirmation(
      title: request.title,
      message: request.message,
      confirmButtonTitle: request.confirmButtonTitle,
      style: request.alertStyle,
      value: value
    )
  }

  static var urlOpener: (URL, ghostty_action_open_url_kind_e) -> Bool = { url, kind in
    openResolvedURL(url, kind: kind)
  }

  static var closeConfirmationHandler: () -> Bool = {
    presentConfirmation(
      title: "Close Terminal?",
      message: "The terminal still has a running process. If you close the terminal the process will be killed.",
      confirmButtonTitle: "Close",
      style: .warning,
      value: ""
    )
  }

  static func confirmClipboard(_ value: String, request: ghostty_clipboard_request_e) -> Bool {
    guard let request = ClipboardRequest(request: request) else {
      logger.warning("unknown clipboard request raw=\(request.rawValue)")
      return false
    }
    return clipboardConfirmationHandler(request, value)
  }

  static func openURL(_ value: String, kind: ghostty_action_open_url_kind_e) -> Bool {
    guard let url = resolveURL(value) else { return false }
    return urlOpener(url, kind)
  }

  static func openConfig() -> Bool {
    let value = ghostty_config_open_path()
    let path: String
    if let ptr = value.ptr {
      let data = Data(bytes: ptr, count: Int(value.len))
      path = String(data: data, encoding: .utf8) ?? ""
    } else {
      path = ""
    }
    ghostty_string_free(value)
    guard !path.isEmpty else { return false }
    return openURL(path, kind: GHOSTTY_ACTION_OPEN_URL_KIND_TEXT)
  }

  static func confirmSurfaceClose() -> Bool {
    closeConfirmationHandler()
  }

  private static func resolveURL(_ value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let candidate = URL(string: trimmed), candidate.scheme != nil {
      return candidate
    }
    let expandedPath = NSString(string: trimmed).standardizingPath
    return URL(filePath: expandedPath)
  }

  private static func openResolvedURL(_ url: URL, kind: ghostty_action_open_url_kind_e) -> Bool {
    if kind == GHOSTTY_ACTION_OPEN_URL_KIND_TEXT, let editor = defaultTextEditor(for: url) {
      NSWorkspace.shared.open(
        [url],
        withApplicationAt: editor,
        configuration: NSWorkspace.OpenConfiguration()
      )
      return true
    }
    return NSWorkspace.shared.open(url)
  }

  private static func defaultTextEditor(for url: URL) -> URL? {
    if !url.pathExtension.isEmpty,
      let contentType = UTType(filenameExtension: url.pathExtension),
      let app = defaultApplicationURL(for: contentType)
    {
      return app
    }
    return defaultApplicationURL(for: .plainText)
  }

  private static func defaultApplicationURL(for contentType: UTType) -> URL? {
    LSCopyDefaultApplicationURLForContentType(
      contentType.identifier as CFString,
      .all,
      nil
    )?.takeRetainedValue() as? URL
  }

  private static func presentConfirmation(
    title: String,
    message: String,
    confirmButtonTitle: String,
    style: NSAlert.Style,
    value: String
  ) -> Bool {
    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = title
    let preview = previewText(value)
    alert.informativeText = preview.isEmpty ? message : "\(message)\n\n\(preview)"
    alert.addButton(withTitle: confirmButtonTitle)
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn
  }

  private static func previewText(_ value: String) -> String {
    if value.count <= previewLimit {
      return value
    }
    return "\(value.prefix(previewLimit))\n..."
  }
}
