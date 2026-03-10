import GhosttyKit
import Observation

@MainActor
@Observable
final class GhosttySurfaceState {
  var title: String?
  var pwd: String?
  var progressState: ghostty_action_progress_report_state_e?
  var progressValue: Int?
  var searchNeedle: String?
  var searchTotal: Int?
  var searchSelected: Int?
  var searchFocusCount = 0
  var initialSizeWidth: UInt32?
  var initialSizeHeight: UInt32?
  var keySequenceActive: Bool?
  var keyTableDepth: Int = 0
}
