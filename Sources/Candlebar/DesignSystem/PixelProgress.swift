import SwiftUI

struct PixelProgress: View {
    var active: Bool
    var filledCount: Int = 0
    var tint: Color = PixelColors.accent

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { index in
                Rectangle()
                    .fill(color(for: index))
                    .frame(width: 8, height: 5)
            }
        }
        .accessibilityLabel(active ? "Loading" : "Idle")
    }

    private func color(for index: Int) -> Color {
        if active {
            return index % 3 != 2 ? tint : PixelColors.line.opacity(0.35)
        }
        return index < filledCount ? tint : PixelColors.line.opacity(0.35)
    }
}
