import AppKit
import GhosttyKit
import Testing

@testable import supacode

@MainActor
struct GhosttySurfaceViewTests {
  @Test func measuredSizeOverridesBoundsForSurfaceSizing() {
    let view = GhosttySurfaceView(
      runtime: GhosttyRuntime(skipNativeRuntime: true),
      workingDirectory: nil,
      context: GHOSTTY_SURFACE_CONTEXT_TAB,
      deferSurfaceCreation: true
    )
    view.frame = NSRect(x: 0, y: 0, width: 800, height: 600)

    #expect(view.surfaceSizeInPoints() == NSSize(width: 800, height: 600))

    view.setMeasuredSize(NSSize(width: 1024, height: 768))

    #expect(view.surfaceSizeInPoints() == NSSize(width: 1024, height: 768))
  }
}
