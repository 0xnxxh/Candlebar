import SwiftUI

struct PixelBadge: View {
    var text: String
    var color: Color = PixelColors.cyan

    var body: some View {
        Text(text.uppercased())
            .font(PixelFont.tiny)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(PixelColors.background)
            .overlay(Rectangle().stroke(color, lineWidth: 1))
            .lineLimit(1)
    }
}
