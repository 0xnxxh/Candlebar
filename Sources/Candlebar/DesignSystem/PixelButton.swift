import SwiftUI

struct PixelButtonStyle: ButtonStyle {
    var tint: Color = PixelColors.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PixelFont.section)
            .foregroundStyle(configuration.isPressed ? PixelColors.background : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? tint : PixelColors.background)
            .overlay(Rectangle().stroke(tint, lineWidth: 1))
    }
}
