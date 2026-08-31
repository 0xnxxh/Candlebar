import SwiftUI

/// Circular gauge drawn in the same square-edged pixel language as the rest of
/// the app: a dim track ring with a colored arc growing clockwise from the top.
struct RingGauge: View {
    var fraction: Double
    var tint: Color
    var label: String
    var diameter: CGFloat = SidebarLayout.ringDiameter
    var lineWidth: CGFloat = 3
    var isHighlighted: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(PixelColors.line.opacity(0.45), lineWidth: lineWidth)

            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(isHighlighted ? PixelColors.accent : PixelColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 3)
        }
        .frame(width: diameter, height: diameter)
    }
}
