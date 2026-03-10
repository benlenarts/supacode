import SwiftUI

struct TerminalCommands: Commands {
  let ghosttyShortcuts: GhosttyShortcutManager
  @FocusedValue(\.newTerminalAction) private var newTerminalAction
  @FocusedValue(\.closeSurfaceAction) private var closeSurfaceAction
  @FocusedValue(\.closeTabAction) private var closeTabAction

  var body: some Commands {
    CommandGroup(after: .newItem) {
      Button("New Terminal") {
        newTerminalAction?()
      }
      .modifier(KeyboardShortcutModifier(shortcut: ghosttyShortcuts.keyboardShortcut(for: "new_tab")))
      .help(helpText("New Terminal", action: "new_tab"))
      .disabled(newTerminalAction == nil)

      Button("Close") {
        closeSurfaceAction?()
      }
      .modifier(
        KeyboardShortcutModifier(shortcut: ghosttyShortcuts.keyboardShortcut(for: "close_surface"))
      )
      .help(helpText("Close", action: "close_surface"))
      .disabled(closeSurfaceAction == nil)

      Button("Close Tab") {
        closeTabAction?()
      }
      .modifier(
        KeyboardShortcutModifier(shortcut: ghosttyShortcuts.keyboardShortcut(for: "close_tab"))
      )
      .help(helpText("Close Tab", action: "close_tab"))
      .disabled(closeTabAction == nil)
    }
  }

  private func helpText(_ title: String, action: String) -> String {
    guard let shortcut = ghosttyShortcuts.display(for: action) else { return title }
    return "\(title) (\(shortcut))"
  }
}

private struct NewTerminalActionKey: FocusedValueKey {
  typealias Value = () -> Void
}

extension FocusedValues {
  var newTerminalAction: (() -> Void)? {
    get { self[NewTerminalActionKey.self] }
    set { self[NewTerminalActionKey.self] = newValue }
  }
}

private struct CloseSurfaceActionKey: FocusedValueKey {
  typealias Value = () -> Void
}

extension FocusedValues {
  var closeSurfaceAction: (() -> Void)? {
    get { self[CloseSurfaceActionKey.self] }
    set { self[CloseSurfaceActionKey.self] = newValue }
  }
}

private struct CloseTabActionKey: FocusedValueKey {
  typealias Value = () -> Void
}

extension FocusedValues {
  var closeTabAction: (() -> Void)? {
    get { self[CloseTabActionKey.self] }
    set { self[CloseTabActionKey.self] = newValue }
  }
}

private struct KeyboardShortcutModifier: ViewModifier {
  let shortcut: KeyboardShortcut?

  func body(content: Content) -> some View {
    if let shortcut {
      content.keyboardShortcut(shortcut)
    } else {
      content
    }
  }
}
