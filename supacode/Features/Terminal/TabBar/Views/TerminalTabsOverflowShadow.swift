import SwiftUI

struct TerminalTabsOverflowShadow: View {
  var width: CGFloat
  var startPoint: UnitPoint
  var endPoint: UnitPoint

  @Environment(\.controlActiveState)
  private var activeState

  var body: some View {
    Rectangle()
      .frame(maxHeight: .infinity)
      .frame(width: width)
      .foregroundStyle(.clear)
      .background(
        LinearGradient(
          gradient: Gradient(colors: gradientColors),
          startPoint: startPoint,
          endPoint: endPoint
        )
      )
      .allowsHitTesting(false)
  }

  private var gradientColors: [Color] {
    [
      TerminalTabBarColors.barBackground.opacity(chromeBackgroundOpacity),
      TerminalTabBarColors.barBackground.opacity(0),
    ]
  }

  private var chromeBackgroundOpacity: Double {
    if activeState == .inactive {
      return 0.95
    }
    return 1
  }
}
