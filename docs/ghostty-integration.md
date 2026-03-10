# Ghostty Integration

## Scope

Supacode embeds Ghostty at the `GhosttyKit` / `libghostty` layer. It does not embed the upstream Ghostty macOS app shell.

That distinction matters:

- Changes under `ThirdParty/ghostty/macos/Sources/Ghostty/*.swift` are mostly reference material for Supacode, not linked runtime code.
- The code that actually runs inside Supacode lives in `supacode/Infrastructure/Ghostty/` plus the terminal session models and views that own those surfaces.
- The artifact Supacode links is `Frameworks/GhosttyKit.xcframework`, bundled with `Resources/ghostty` and `Resources/terminfo`.

## What We Vendor

The upstream source of truth is the `ThirdParty/ghostty` submodule.

Supacode builds and consumes these outputs:

- `Frameworks/GhosttyKit.xcframework`
- `Resources/ghostty`
- `Resources/terminfo`

`make build-ghostty-xcframework` runs Zig inside the submodule, then syncs the framework and runtime resources into the app bundle inputs. `Project.swift` links the XCFramework and folder-references the two resource directories into the `supacode` target.

This means:

- Zig and the Ghostty submodule produce the binary/runtime assets.
- Tuist/Xcode links those assets into Supacode.
- The upstream Ghostty macOS app project is not part of Supacode's build graph.

## Integration Boundary

Supacode and upstream Ghostty solve different problems.

Upstream Ghostty macOS app:

- Owns the app shell with `Ghostty.App`, `AppDelegate`, window controllers, and NotificationCenter-driven actions.
- Models tabs/windows/splits around Ghostty's native app behavior.
- Uses `Ghostty.SurfaceView` and `SurfaceView_AppKit.swift` as the AppKit terminal host.

Supacode:

- Owns the app shell with `SupacodeApp`, `ContentView`, `V2SidebarView`, and `V2TerminalDetailView`.
- Models repos/sessions/tabs/splits in Supacode's own types.
- Hosts `ghostty_surface_t` instances inside `GhosttySurfaceView`, `TerminalSessionState`, and `SplitTree`.

In practice, Supacode reimplements the Ghostty app shell around the same C runtime instead of reusing the upstream Swift app layer.

## Control Flow

```text
SupacodeApp
  -> ghostty_init(...)
  -> GhosttyRuntime
      -> ghostty_app_t
      -> runtime callbacks

V2TerminalDetailView
  -> TerminalSessionView
      -> TerminalSessionState
          -> GhosttySurfaceView
              -> ghostty_surface_t

libghostty action callback
  -> GhosttyRuntime.handleAction(...)
      -> GhosttySurfaceBridge.handleAction(...)
          -> TerminalSessionState closures
              -> Supacode tab/split/session mutations
```

## Boot Sequence

### 1. Global Ghostty initialization

`supacode/App/supacodeApp.swift` performs the process-wide setup:

- Sets `GHOSTTY_RESOURCES_DIR` to the bundled `Resources/ghostty` directory.
- Builds CLI keybind overrides from `AppShortcuts.ghosttyCLIKeybindArguments`.
- Calls `ghostty_init(...)` once before constructing the runtime.

Those CLI keybind overrides are important because Supacode reserves some shortcuts for the host app. Today this mainly unbinds app-owned shortcuts from Ghostty and remaps tab-selection bindings.

### 2. Runtime creation

`supacode/Infrastructure/Ghostty/GhosttyRuntime.swift` is Supacode's replacement for upstream `Ghostty.App`:

- Loads config with:
  - `ghostty_config_load_default_files`
  - `ghostty_config_load_recursive_files`
  - `ghostty_config_load_cli_args`
  - `ghostty_config_finalize`
- Creates a single `ghostty_app_t` with `ghostty_app_new`.
- Registers runtime callbacks for:
  - wakeup/tick
  - action dispatch
  - clipboard read/write/confirm
  - close-surface requests
- Mirrors app focus and keyboard selection changes from AppKit into libghostty.

### 3. SwiftUI color-scheme sync

`supacode/App/GhosttyColorSchemeSyncView.swift` pushes the current SwiftUI `ColorScheme` into `ghostty_app_t` through `GhosttyRuntime.setColorScheme(_:)`.

Supacode also remembers registered surfaces so color scheme updates can be applied to existing `ghostty_surface_t` instances.

### 4. Menu shortcut introspection

`GhosttyShortcutManager` reads live Ghostty config through `GhosttyRuntime`:

- `keyboardShortcut(for:)` queries the trigger for a Ghostty action.
- `commandPaletteEntries()` reads Ghostty's command palette configuration.

This keeps Supacode's menu shortcuts aligned with Ghostty config instead of duplicating bindings in SwiftUI.

## Surface Lifecycle

Each terminal leaf in Supacode is a `GhosttySurfaceView`.

Creation flow:

1. `V2TerminalDetailView` selects a `TerminalSession`.
2. `TerminalSessionView` asks `TerminalSessionManager` for the per-session `TerminalSessionState`.
3. `TerminalSessionState` creates or looks up a tab tree.
4. `TerminalSessionState.createSurface(...)` constructs a `GhosttySurfaceView`.
5. `GhosttySurfaceView.createSurface()` builds `ghostty_surface_config_s` and calls `ghostty_surface_new(...)`.

`TerminalSessionState` also asks libghostty for inherited surface config via `ghostty_surface_inherited_config(...)` so new tabs and splits preserve the relevant Ghostty state:

- working directory
- font size
- command
- environment variables
- wait-after-command

`GhosttySurfaceView` passes these platform-specific values into `ghostty_surface_config_s`:

- `userdata` points at `GhosttySurfaceBridge`
- `platform_tag = GHOSTTY_PLATFORM_MACOS`
- `platform.macos.nsview` points at the AppKit view
- working directory / command / env vars / initial input
- context (`window`, `tab`, or `split`)
- content scale

After surface creation, `GhosttyRuntime.registerSurface(...)` tracks the new surface so runtime-wide updates can fan out across all live terminals.

## AppKit Host Responsibilities

Supacode's `GhosttySurfaceView` owns the AppKit integration responsibilities that upstream Ghostty normally keeps in `SurfaceView.swift` and `SurfaceView_AppKit.swift`.

That includes:

- sizing and backing-scale updates
- display-id changes when the window moves between screens
- focus and occlusion propagation
- keyboard and mouse event forwarding
- drag and drop
- selection reading and Quick Look helpers
- search navigation
- progress state
- accessibility helpers
- secure input scoping

This is the highest drift-risk area in the integration because the upstream Ghostty macOS host view evolves independently and Supacode maintains its own local implementation.

## Action Routing

The action path is:

1. libghostty invokes `action_cb` from `ghostty_runtime_config_s`
2. `GhosttyRuntime.handleAction(...)` receives the raw `ghostty_action_s`
3. app-level actions are handled centrally
4. surface-level actions are delegated to `GhosttySurfaceBridge`
5. `GhosttySurfaceBridge` invokes closures installed by `TerminalSessionState`

### App-level actions handled in `GhosttyRuntime`

Current runtime-owned handling includes:

- config change
- config reload
- open config
- clipboard read / confirm / write
- close-surface callback dispatch

Config changes update the cached config and broadcast `.ghosttyRuntimeConfigDidChange`. Supacode uses that to refresh menu shortcuts and surface appearance.

### Surface-level actions handled in `GhosttySurfaceBridge`

`GhosttySurfaceBridge` translates Ghostty actions into Supacode operations:

- new tab
- close tab
- goto tab
- move tab
- new split
- goto split
- resize split
- equalize splits
- split zoom
- command palette toggle
- title changes
- PWD updates
- progress reports
- desktop notifications
- close requests

`TerminalSessionState` installs closures on the bridge and converts those callbacks into mutations of:

- `TerminalTabManager`
- `SplitTree<GhosttySurfaceView>`
- focused-surface bookkeeping
- notification state
- task-status state

This is a deliberate divergence from upstream Ghostty macOS app behavior.

## Upstream Comparison

Upstream `Ghostty.App` routes many actions through NotificationCenter. For example:

- `ghosttyNewTab`
- `ghosttyNewSplit`
- `ghosttyCloseTab`
- `ghosttyCloseOtherTabs`
- `ghosttyCloseTabsOnTheRight`
- `ghosttyCommandPaletteDidToggle`

Supacode does not reuse that NotificationCenter action bus for core terminal orchestration. It routes directly from libghostty callbacks into closures on `GhosttySurfaceBridge` and `TerminalSessionState`.

This is a better fit for Supacode because:

- Supacode tabs are local to a session, not native Ghostty window tabs.
- Supacode splits live inside its own `SplitTree`.
- Supacode wants per-session state objects rather than app-global window notifications.

## Menu and Shortcut Integration

There are two separate shortcut layers:

- Host-app-owned shortcuts from `AppShortcuts`
- Ghostty-owned shortcuts loaded from Ghostty config

The host app unbinds its reserved shortcuts at Ghostty init time by passing CLI `--keybind=...=unbind` arguments. Then `TerminalCommands` asks `GhosttyShortcutManager` for the Ghostty-defined shortcuts for actions such as:

- `new_tab`
- `close_surface`
- `close_tab`
- `start_search`
- `search:next`
- `search:previous`
- `end_search`
- `search_selection`

This preserves Ghostty as the single source of truth for terminal bindings while still letting Supacode own app-level shortcuts.

## Current Reality of the Terminal Layer

There is a stale abstraction boundary worth calling out.

`TerminalClient` exists as a dependency-shaped client with commands and events, but the current V2 shell does not drive the terminal layer through that client. `V2TerminalDetailView` calls `TerminalSessionManager.handleCommand(...)` directly.

Treat the current source of truth as:

- `TerminalSessionManager`
- `TerminalSessionState`
- `GhosttyRuntime`
- `GhosttySurfaceView`

Treat `TerminalClient` as dormant or transitional until the V2 shell is moved back behind the client boundary.

## Drift Hotspots

When Ghostty changes upstream, these are the files most likely to need attention:

- `supacode/Infrastructure/Ghostty/GhosttyRuntime.swift`
  - compare against `ThirdParty/ghostty/macos/Sources/Ghostty/Ghostty.App.swift`
- `supacode/Infrastructure/Ghostty/GhosttySurfaceView.swift`
  - compare against:
    - `ThirdParty/ghostty/macos/Sources/Ghostty/Surface View/SurfaceView.swift`
    - `ThirdParty/ghostty/macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift`
- `supacode/Features/Terminal/Models/TerminalSessionState.swift`
  - compare against upstream app-level action routing in `Ghostty.App.swift`
- `supacode/App/AppShortcuts.swift`
- `supacode/Commands/TerminalCommands.swift`

If behavior changes upstream and Supacode does not mirror it in those areas, the drift will usually show up as:

- missing actions
- broken focus behavior
- wrong inherited config for new tabs/splits
- shortcut mismatches
- appearance/config reload bugs
- clipboard or notification regressions

## Upgrade Checklist

When updating `ThirdParty/ghostty` or rebuilding `GhosttyKit.xcframework`, check all of the following:

1. Rebuild the vendored binary/runtime assets with `make build-ghostty-xcframework`.
2. Verify `ghostty_runtime_config_s` callback signatures and semantics still match `GhosttyRuntime`.
3. Compare upstream `Ghostty.App.swift` action handling against `GhosttyRuntime` and `GhosttySurfaceBridge`.
4. Compare upstream `SurfaceView.swift` and `SurfaceView_AppKit.swift` against `GhosttySurfaceView`, especially for:
   - surface creation
   - focus
   - sizing
   - screen/backing changes
   - key and mouse handling
   - selection and accessibility
   - search/progress state
5. Verify inherited config behavior for new tabs and splits.
6. Verify menu shortcuts and command palette entries still resolve correctly from config.
7. Run `make build-app` and perform a smoke test:
   - open session
   - create tab
   - split pane
   - switch focus
   - search
   - close surface/tab

## Practical Takeaway

Supacode should be thought of as a custom macOS host for libghostty, not as a thin wrapper around the upstream Ghostty macOS app.

The stable contract is the C/runtime layer and bundled resources. The upstream Swift macOS app is still valuable, but mostly as reference code for behavior that Supacode has chosen to own itself.
