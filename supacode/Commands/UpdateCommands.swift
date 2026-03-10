import Sparkle
import SwiftUI

struct UpdateCommands: Commands {
  let updaterController: SPUStandardUpdaterController

  var body: some Commands {
    CommandGroup(after: .appInfo) {
      Button("Check for Updates...") {
        updaterController.checkForUpdates(nil)
      }
      .help("Check for available app updates")
    }
  }
}
