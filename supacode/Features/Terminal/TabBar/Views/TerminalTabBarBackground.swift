import SwiftUI

struct TerminalTabBarBackground: View {
  @Environment(\.controlActiveState)
  private var activeState

  var body: some View {
    Rectangle()
      .fill(TerminalTabBarColors.barBackground.opacity(chromeBackgroundOpacity))
  }

  private var chromeBackgroundOpacity: Double {
    if activeState == .inactive {
      return 0.95
    }
    return 1
  }
}
