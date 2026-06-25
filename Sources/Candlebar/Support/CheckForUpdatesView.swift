import Sparkle
import SwiftUI

struct CheckForUpdatesView: View {
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        Button("Check for Updates...", action: updater.checkForUpdates)
    }
}
