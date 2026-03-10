## Build Commands

```bash
make # run make for a list of possible commands
```

Run a single test class or method:
```bash
xcodebuild test -workspace supacode.xcworkspace -scheme supacode -destination "platform=macOS" \
  -only-testing:supacodeTests/TerminalTabManagerTests \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -skipMacroValidation
```

Requires [mise](https://mise.jdx.dev/) for zig, tuist, swiftlint, and xcsift tooling.

## Architecture

Supacode is a macOS orchestrator for running multiple coding agents in parallel, using GhosttyKit as the underlying terminal.

### Core Data Flow

```
AppFeature (root TCA store)
├─ RepositoriesFeature (repos + worktrees)
├─ CommandPaletteFeature
├─ SettingsFeature (appearance, updates, repo settings)
└─ UpdatesFeature (Sparkle auto-updates)

TerminalSessionManager (global @Observable, manages all sessions)
└─ TerminalSessionState (per session, @Observable)
    └─ TerminalTabManager (tab/split management)
        └─ GhosttySurfaceState[] (one per terminal surface)

GhosttyRuntime (shared singleton)
└─ ghostty_app_t (single C instance)
    └─ ghostty_surface_t[] (independent terminal sessions)
```

### TCA ↔ Terminal Communication

The terminal layer (`TerminalSessionManager`) is `@Observable` but outside TCA. Communication uses `TerminalClient`:

```
Reducer → terminalClient.send(Command) → TerminalSessionManager
                                                    ↓
Reducer ← .terminalEvent(Event) ← AsyncStream<Event>
```

- **Commands**: `createTab`, `closeFocusedTab`, `runScript`, `setSelectedSessionID`, etc.
- **Events**: `tabCreated`, `tabClosed`, `focusChanged`, `taskStatusChanged`, `setupScriptConsumed`
- Wired in `supacodeApp.swift`, subscribed in `AppFeature.task`

### Client Pattern

All dependency clients follow the same convention — pure Sendable function structs with DependencyKey:

```swift
struct FooClient: Sendable {
  var doSomething: @Sendable (Input) -> Output
}

extension FooClient: DependencyKey {
  static let liveValue = FooClient(/* real impl */)
  static let testValue = FooClient(/* no-op stubs */)
}

extension DependencyValues {
  var fooClient: FooClient { get { self[FooClient.self] } set { self[FooClient.self] = newValue } }
}
```

Clients live in `supacode/Clients/` — one directory per client (Terminal, Analytics, Shell, etc.).

### Key Dependencies

- **TCA (swift-composable-architecture)**: App state, reducers, side effects
- **GhosttyKit**: Terminal emulator (built from Zig source in ThirdParty/ghostty)
- **Sparkle**: Auto-update framework
- **swift-dependencies**: Dependency injection for TCA clients
- **PostHog**: Analytics
- **Sentry**: Error tracking

## Ghostty Keybindings Handling

- Ghostty keybindings are handled via runtime action callbacks in `GhosttySurfaceBridge`, not by app menu shortcuts.
- App-level tab actions should be triggered by Ghostty actions (`GHOSTTY_ACTION_NEW_TAB` / `GHOSTTY_ACTION_CLOSE_TAB`) to honor user custom bindings.
- `GhosttySurfaceView.performKeyEquivalent` routes bound keys to Ghostty first; only unbound keys fall through to the app.

## Code Guidelines

- Target macOS 26.0+, Swift 6.2+
- Project uses `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` — all types are `@MainActor` by default
- Before doing a big feature or when planning, consult with pfw (pointfree) skills on TCA, Observable best practices first.
- Use `@ObservableState` for TCA feature state; use `@Observable` for non-TCA shared stores; never `ObservableObject`
- Always mark `@Observable` classes with `@MainActor`
- Modern SwiftUI only: `foregroundStyle()`, `NavigationStack`, `Button` over `onTapGesture()`
- When a new logic changes in the Reducer, always add tests
- Prefer Swift-native APIs over Foundation where they exist (e.g., `replacing()` not `replacingOccurrences()`)
- Avoid `GeometryReader` when `containerRelativeFrame()` or `visualEffect()` would work
- Do not use NSNotification to communicate between reducers.
- Prefer `@Shared` directly in reducers for app storage and shared settings; do not introduce new dependency clients solely to wrap `@Shared`.
- Use `SupaLogger` for all logging. Never use `print()` or `os.Logger` directly. `SupaLogger` prints in DEBUG and uses `os.Logger` in release.

### Testing Conventions

- Use **Swift Testing** framework (`import Testing`), not XCTest
- Test types are `@MainActor struct`, not classes
- Use `#expect()` for assertions, `#require()` for unwrapping — never `XCTAssert*`
- Use TCA `TestStore` for reducer tests
- Never use `Task.sleep`; use `TestClock` (or an injected clock) and drive time with `advance`
- Helper factories (e.g., `makeTerminalSession()`) go in the same test file

### Formatting & Linting

- 2-space indentation, 120 character line length (enforced by `.swift-format.json`)
- Trailing commas are mandatory (enforced by `.swiftlint.yml`)
- SwiftLint runs in strict mode; never disable lint rules without permission
- Custom SwiftLint rule: `store_state_mutation_in_views` — do not mutate `store.*` directly in view files; send actions instead

## UX Standards

- Buttons must have tooltips explaining the action and associated hotkey
- Use Dynamic Type, avoid hardcoded font sizes
- Components should be layout-agnostic (parents control layout, children control appearance)
- Never use custom colors, always use system provided ones.
- We use `.monospaced()` modifier on fonts when appropriate

## Rules

- After a task, ensure the app builds: `make build-app`
- Automatically commit your changes and your changes only. Do not use `git add .`
- Before you go on your task, check the current git branch name, if it's something generic like an animal name, name it accordingly. Do not do this for main branch
- After implementing an execplan, always submit a PR if you're not in the main branch

## Submodules

- `ThirdParty/ghostty` (`https://github.com/ghostty-org/ghostty`): Source dependency used to build `Frameworks/GhosttyKit.xcframework` and terminal resources.
- `Resources/git-wt` (`https://github.com/khoi/git-wt.git`): Bundled `wt` CLI used by Supacode Git worktree flows at runtime.
