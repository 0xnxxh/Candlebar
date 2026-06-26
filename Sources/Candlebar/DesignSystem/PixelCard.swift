import SwiftUI

struct PixelCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(PixelColors.raised)
            .overlay(
                Rectangle()
                    .strokeBorder(PixelColors.line, lineWidth: 1),
            )
    }
}
