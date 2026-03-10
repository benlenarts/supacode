import AppKit
import ComposableArchitecture
import Foundation
import GhosttyKit
import SwiftUI

private enum GhosttyCLI {
  static let argv: [UnsafeMutablePointer<CChar>?] = {
    var args: [UnsafeMutablePointer<CChar>?] = []
    let executable = CommandLine.arguments.first ?? "supacode"
    args.append(strdup(executable))
    for keybindArgument in AppShortcuts.ghosttyCLIKeybindArguments {
      args.append(strdup(keybindArgument))
    }
    args.append(nil)
    return args
  }()
}

@MainActor
final class SupacodeAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidBecomeActive(_ notification: Notification) {
    let app = NSApplication.shared
    guard !app.windows.contains(where: \.isVisible) else { return }
    _ = showMainWindow(from: app)
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if flag { return true }
    return showMainWindow(from: sender) ? false : true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  private func mainWindow(from sender: NSApplication) -> NSWindow? {
    if let window = sender.windows.first(where: { $0.identifier?.rawValue == "main" }) {
      return window
    }
    return sender.windows.first
  }

  private func showMainWindow(from sender: NSApplication) -> Bool {
    guard let window = mainWindow(from: sender) else { return false }
    if window.isMiniaturized {
      window.deminiaturize(nil)
    }
    sender.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    return true
  }
}

@main
@MainActor
struct SupacodeApp: App {
  private static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

  @NSApplicationDelegateAdaptor(SupacodeAppDelegate.self) private var appDelegate
  @State private var ghostty: GhosttyRuntime?
  @State private var terminalManager: TerminalSessionManager?
  @State private var ghosttyShortcuts: GhosttyShortcutManager?
  @State private var commandKeyObserver: CommandKeyObserver?
  @State private var store: StoreOf<AppFeature>

  @MainActor init() {
    let appStore = Store(initialState: AppFeature.State()) {
      AppFeature()
    }
    _store = State(initialValue: appStore)

    guard !Self.isRunningTests else {
      _ghostty = State(initialValue: nil)
      _terminalManager = State(initialValue: nil)
      _ghosttyShortcuts = State(initialValue: nil)
      _commandKeyObserver = State(initialValue: nil)
      return
    }

    NSWindow.allowsAutomaticWindowTabbing = false
    if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("ghostty") {
      setenv("GHOSTTY_RESOURCES_DIR", resourceURL.path, 1)
    }
    GhosttyCLI.argv.withUnsafeBufferPointer { buffer in
      let argc = UInt(max(0, buffer.count - 1))
      let argv = UnsafeMutablePointer(mutating: buffer.baseAddress)
      if ghostty_init(argc, argv) != GHOSTTY_SUCCESS {
        preconditionFailure("ghostty_init failed")
      }
    }

    let runtime = GhosttyRuntime()
    _ghostty = State(initialValue: runtime)

    let terminalManager = TerminalSessionManager(runtime: runtime)
    _terminalManager = State(initialValue: terminalManager)

    let ghosttyShortcuts = GhosttyShortcutManager(runtime: runtime)
    _ghosttyShortcuts = State(initialValue: ghosttyShortcuts)

    let commandKeyObserver = CommandKeyObserver()
    _commandKeyObserver = State(initialValue: commandKeyObserver)
  }

  var body: some Scene {
    Window("Supacode", id: "main") {
      if
        let ghostty,
        let terminalManager,
        let ghosttyShortcuts,
        let commandKeyObserver
      {
        GhosttyColorSchemeSyncView(ghostty: ghostty) {
          ContentView(store: store, terminalManager: terminalManager)
            .environment(ghosttyShortcuts)
            .environment(commandKeyObserver)
        }
      } else {
        Color.clear
          .frame(width: 1, height: 1)
      }
    }
    .commands {
      if !Self.isRunningTests {
        SidebarCommands()
      }
    }
  }
}
