import SwiftUI

struct GhosttyTerminalView: NSViewRepresentable {
  let surfaceView: GhosttySurfaceView
  let size: CGSize

  func makeNSView(context: Context) -> GhosttySurfaceScrollView {
    let view = GhosttySurfaceScrollView(surfaceView: surfaceView)
    view.setMeasuredSize(size)
    return view
  }

  func updateNSView(_ view: GhosttySurfaceScrollView, context: Context) {
    view.setMeasuredSize(size)
  }
}
