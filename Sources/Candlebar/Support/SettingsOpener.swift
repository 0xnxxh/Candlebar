enum SettingsOpener {
    @MainActor
    static func open(store: AppStore) {
        SettingsWindowPresenter.shared.open(store: store)
    }
}
