import Sparkle
import SwiftUI

struct CheckForUpdatesView: View {
    private let updater: SPUUpdater
    private let language: AppLanguage

    init(updater: SPUUpdater, language: AppLanguage) {
        self.updater = updater
        self.language = language
    }

    var body: some View {
        Button(LocalizedCopy.text(.checkForUpdates, language: language), action: updater.checkForUpdates)
            .buttonStyle(PixelButtonStyle(tint: PixelColors.cyan))
    }
}
