import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Text(labelText)
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .lineLimit(1)
        .fixedSize()
    }

    private var labelText: String {
        MenuBarLabelFormatter.text(
            item: store.defaultItem,
            ticker: store.defaultTicker,
            compact: store.preferences.compactMenuBar,
            decimalPlaces: store.preferences.priceDecimalPlaces,
        )
    }
}
